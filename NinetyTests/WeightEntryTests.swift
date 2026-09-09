import Foundation
import Testing
@testable import Ninety

/// Weight entry: the two routes, the duplicate rule, and the screen's states.
///
/// This is the half of P1-G that day 0 was waiting on. Onboarding wrote one
/// `WeightLog` and nothing could write a second, so *"real food, real weight"*
/// had one half. The tests here are the acceptance criteria of the ticket
/// **Weight entry: manual plus HealthKit** — both sources land in `weight_logs`
/// with `source` set correctly, no duplicate when the same reading arrives both
/// ways, and it works offline.
@MainActor
@Suite("Weight entry")
struct WeightEntryTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static func moment(_ day: Int, hour: Int = 8, minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private struct Fixture {
        let model: TheRunModel
        let weights: MockWeightRepository
        let health: MockBodyMassSource
    }

    private static func fixture(
        readings: [(Int, Double)] = [],
        fromHealth: [BodyMassReading] = [],
        goal: GoalType = .lose
    ) -> Fixture {
        let user = UUID()
        let weights = MockWeightRepository(
            logs: readings.map { WeightLog(userID: user, measuredAt: moment($0.0), kg: $0.1) },
            userID: user
        )
        let health = MockBodyMassSource(readings: fromHealth)
        let model = TheRunModel(
            weights: weights,
            profiles: MockProfileRepository(
                profile: Profile(id: user, heightCm: 178, goalType: goal, goalWeightKg: 70, targetRateKgPerWeek: 0.5)
            ),
            health: health,
            calendar: utc,
            now: { moment(30) }
        )
        model.refresh()
        return Fixture(model: model, weights: weights, health: health)
    }

    // MARK: - The manual route

    @Test("a typed weight lands as a manual reading")
    func recordsAManualReading() {
        let fixture = Self.fixture()
        #expect(fixture.model.readiness == .noReadings)

        #expect(fixture.model.record(kg: 78.4, at: Self.moment(1)))

        #expect(fixture.weights.storedLogs.count == 1)
        #expect(fixture.weights.storedLogs.first?.source == .manual)
        #expect(fixture.weights.storedLogs.first?.kg == 78.4)
        #expect(fixture.model.readiness == .oneReading, "and the screen re-reads without being told to")
    }

    /// The moment is a parameter, not `Date()`. Weighing at seven and recording
    /// at eleven has to land on the morning's day or the series buckets it wrong.
    @Test("the reading is stamped with when it was measured, not when it was typed")
    func honoursTheMeasuredMoment() {
        let fixture = Self.fixture()
        fixture.model.record(kg: 78.4, at: Self.moment(3, hour: 7))
        #expect(fixture.weights.storedLogs.first?.measuredAt == Self.moment(3, hour: 7))
    }

    /// The column is `check (kg > 0 and kg < 500)`. Refusing here means the user
    /// finds out on the screen that typed it rather than at sync time.
    @Test("only what the column can store is accepted, and the bound is the column's")
    func refusesWhatCannotBeStored() {
        #expect(TheRunModel.isStorable(78.4))
        #expect(TheRunModel.isStorable(0.5), "the app has no basis to have opinions inside the bound")
        #expect(TheRunModel.isStorable(499.99))
        #expect(!TheRunModel.isStorable(0))
        #expect(!TheRunModel.isStorable(-1))
        #expect(!TheRunModel.isStorable(500))
        #expect(!TheRunModel.isStorable(784), "the decimal-point typo, one order out")

        let fixture = Self.fixture()
        #expect(!fixture.model.record(kg: 784, at: Self.moment(1)))
        #expect(fixture.weights.storedLogs.isEmpty)
    }

    /// A write that did not land is shown, never swallowed. A tracker that says
    /// it saved and did not is how a day of the twenty-one disappears silently.
    @Test("a failed write is surfaced rather than swallowed")
    func surfacesAFailedWrite() {
        let fixture = Self.fixture()
        fixture.weights.failure = RepositoryError.noProfile

        #expect(!fixture.model.record(kg: 78.4, at: Self.moment(1)))
        #expect(fixture.model.writeFailed)
    }

    /// No 48-hour lock, unlike `food_logs`. §2.3's window stops a scored week
    /// being rewritten; a mistyped weight is a measurement that never happened
    /// and drags every trend value after it for as long as it is stored.
    @Test("a reading can be removed at any age, unlike a food log")
    func removesAReading() throws {
        let fixture = Self.fixture(readings: [(1, 80), (2, 7.84), (3, 80)])
        #expect(fixture.model.trend.readingDays == 3)

        let typo = try #require(fixture.weights.storedLogs.first { $0.kg == 7.84 })
        #expect(fixture.model.delete(typo))

        #expect(fixture.model.trend.readingDays == 2)
        #expect(fixture.model.readings.allSatisfy { $0.kg == 80 })
    }

    // MARK: - The Apple Health route

    @Test("a reading from Apple Health lands with its source set")
    func importsFromHealth() async {
        let fixture = Self.fixture(
            fromHealth: [BodyMassReading(measuredAt: Self.moment(2), kg: 79.1)]
        )

        await fixture.model.readFromHealth()

        #expect(fixture.weights.storedLogs.count == 1)
        #expect(fixture.weights.storedLogs.first?.source == .healthkit)
        #expect(fixture.model.lastImportCount == 1)
    }

    /// The acceptance criterion, in the form it actually arrives: the user typed
    /// this morning's weight, and the scale wrote the same reading to Apple
    /// Health ninety seconds earlier under a different timestamp.
    @Test("the same weigh-in arriving both ways produces one row, not two")
    func doesNotDuplicateAcrossSources() async {
        let fixture = Self.fixture(readings: [(2, 79.1)])
        fixture.health.stored = [BodyMassReading(measuredAt: Self.moment(2, minute: 32), kg: 79.15)]

        await fixture.model.readFromHealth()

        #expect(fixture.weights.storedLogs.count == 1, "one weigh-in, one row")
        #expect(fixture.model.lastImportCount == 0)
    }

    /// Two genuine weigh-ins on one day are two measurements. The rule is not
    /// "one reading per day" — the trend takes their mean rather than throwing
    /// one away.
    @Test("a genuinely different reading on the same day is kept")
    func keepsASecondRealReading() async {
        let fixture = Self.fixture(readings: [(2, 79.1)])
        fixture.health.stored = [BodyMassReading(measuredAt: Self.moment(2, hour: 21), kg: 80.4)]

        await fixture.model.readFromHealth()

        #expect(fixture.weights.storedLogs.count == 2)
    }

    @Test("syncing twice does not double the store")
    func isIdempotentAcrossSyncs() async {
        let fixture = Self.fixture(
            fromHealth: [
                BodyMassReading(measuredAt: Self.moment(2), kg: 79.1),
                BodyMassReading(measuredAt: Self.moment(3), kg: 79.0),
            ]
        )

        await fixture.model.readFromHealth()
        await fixture.model.readFromHealth()

        #expect(fixture.weights.storedLogs.count == 2)
        #expect(fixture.model.lastImportCount == 0, "the second pass found nothing new")
    }

    /// iOS never reports a refusal: a denied read returns a result identical to
    /// "no data". The model finishes with a count either way and claims nothing
    /// about which happened.
    @Test("a refused read is indistinguishable from an empty one, and says so")
    func cannotTellRefusalFromEmptiness() async {
        let refused = Self.fixture()
        refused.health.authorized = false
        await refused.model.readFromHealth()

        let empty = Self.fixture()
        await empty.model.readFromHealth()

        #expect(refused.model.lastImportCount == 0)
        #expect(empty.model.lastImportCount == 0)
        #expect(!refused.model.writeFailed, "an empty read is not an error")
    }

    @Test("a device with no health store is offered nothing rather than a dead button")
    func hidesHealthWhereItDoesNotExist() async {
        let fixture = Self.fixture()
        fixture.health.isAvailable = false
        #expect(!fixture.model.offersHealth)

        await fixture.model.readFromHealth()
        #expect(fixture.health.reads == 0)
        #expect(fixture.model.lastImportCount == nil, "nothing ran, so there is nothing to report")
    }

    // MARK: - The duplicate rule on its own

    @Test("Ninety's own samples are never read back in")
    func skipsItsOwnSamples() {
        let unseen = WeightReconciliation.unseen(
            [
                BodyMassReading(measuredAt: Self.moment(2), kg: 79.1, isFromThisApp: true),
                BodyMassReading(measuredAt: Self.moment(3), kg: 79.0, isFromThisApp: false),
            ],
            against: [],
            calendar: Self.utc
        )
        #expect(unseen.count == 1)
        #expect(unseen.first?.kg == 79.0)
    }

    @Test("a duplicate inside one batch collapses too")
    func collapsesWithinABatch() {
        let unseen = WeightReconciliation.unseen(
            [
                BodyMassReading(measuredAt: Self.moment(2, minute: 0), kg: 79.1),
                BodyMassReading(measuredAt: Self.moment(2, minute: 5), kg: 79.14),
            ],
            against: [],
            calendar: Self.utc
        )
        #expect(unseen.count == 1, "neither is in the store when the other is judged")
    }

    /// The tolerance is a hundred grams, and the test names both sides of it so
    /// a change to the constant fails here rather than quietly widening.
    @Test("the tolerance is a tenth of a kilogram, and it has two sides")
    func toleranceHasBothSides() {
        #expect(WeightReconciliation.sameWeighInToleranceKg == 0.1)

        let existing = [WeighIn(measuredAt: Self.moment(2), kg: 79.1)]
        let inside = WeightReconciliation.unseen(
            [BodyMassReading(measuredAt: Self.moment(2, hour: 9), kg: 79.19)],
            against: existing,
            calendar: Self.utc
        )
        let outside = WeightReconciliation.unseen(
            [BodyMassReading(measuredAt: Self.moment(2, hour: 9), kg: 79.4)],
            against: existing,
            calendar: Self.utc
        )
        #expect(inside.isEmpty)
        #expect(outside.count == 1)
    }

    @Test("the same weight on a different day is a different reading")
    func doesNotCollapseAcrossDays() {
        let unseen = WeightReconciliation.unseen(
            [BodyMassReading(measuredAt: Self.moment(3), kg: 79.1)],
            against: [WeighIn(measuredAt: Self.moment(2), kg: 79.1)],
            calendar: Self.utc
        )
        #expect(unseen.count == 1, "weighing the same two days running is two facts, not one")
    }

    // MARK: - Offline

    /// ADR 0005, and the reason it is a Phase 1 requirement rather than polish:
    /// gyms and restaurant basements have no signal, and that is where people
    /// weigh themselves and log food. Nothing on the manual route is `async` and
    /// nothing on it touches the network.
    @Test("the manual route needs no network, no catalogue and no health store")
    func worksWithNothingAtAll() {
        let user = UUID()
        let weights = MockWeightRepository(userID: user)
        let model = TheRunModel(
            weights: weights,
            profiles: MockProfileRepository(profile: Profile(id: user)),
            health: nil,
            calendar: Self.utc,
            now: { Self.moment(30) }
        )
        model.refresh()

        #expect(!model.offersHealth)
        #expect(model.record(kg: 78.4, at: Self.moment(1)))
        #expect(weights.storedLogs.count == 1)
    }

    // MARK: - What the screen shows

    @Test("the headline is the smoothed value, never the last thing the scale said")
    func headlineIsTheTrend() {
        let fixture = Self.fixture(readings: [(1, 80), (2, 84)])
        #expect(fixture.model.latestTrendKg == 81, "80 + 0.25 × (84 − 80)")
        #expect(fixture.model.readings.last?.kg == 84, "the raw reading is still there to look at")
    }

    /// `DESIGN.md` § Numbers: a number the app did not compute is not shown at
    /// all. Eleven days of data has no four-week figure.
    @Test("a four-week figure is nil rather than zero when the span is shorter")
    func refusesAFigureItCannotCompute() {
        let short = Self.fixture(readings: [(1, 80), (11, 79)])
        #expect(short.model.changeOverFourWeeks == nil)
    }

    @Test("the raw series is off every time the screen appears")
    func rawSeriesIsOffByDefault() {
        #expect(!Self.fixture(readings: [(1, 80)]).model.showsRawReadings)
    }

    @Test("the range selector windows the line without changing it")
    func rangeWindowsTheSeries() {
        let fixture = Self.fixture(readings: (1...29).map { ($0, 80.0) })

        fixture.model.range = .week
        let week = fixture.model.visiblePoints

        fixture.model.range = .twelveWeeks
        let all = fixture.model.visiblePoints

        #expect(week.count == 8)
        #expect(all.count == 29)
        #expect(week.last?.trendKg == all.last?.trendKg, "the same series, seen through a smaller window")
    }

    @Test("the pace line is drawn over exactly the visible days")
    func paceMatchesTheVisibleWindow() {
        let fixture = Self.fixture(readings: (1...29).map { ($0, 80.0) })
        fixture.model.range = .week
        #expect(fixture.model.visiblePace.count == fixture.model.visiblePoints.count)
        #expect(fixture.model.visiblePace.map(\.day) == fixture.model.visiblePoints.map(\.day))
    }
}
