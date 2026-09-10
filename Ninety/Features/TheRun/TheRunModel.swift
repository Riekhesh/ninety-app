import Foundation
import Observation

/// How much of the line to draw.
///
/// `design/spec/02-components.md` §6 sets the three: 7d / 4w / 3m. The artboard
/// draws eight weeks, which is inside the third — the selector is what makes one
/// chart cover both rather than picking a window and calling it the design.
enum TrendRange: String, CaseIterable, Identifiable, Sendable {
    case week
    case fourWeeks
    case twelveWeeks

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: 7
        case .fourWeeks: 28
        case .twelveWeeks: 84
        }
    }

    /// Written out rather than abbreviated. The spec's `7d / 4w / 3m` is how a
    /// designer labels a control; "12 weeks" is what a screen reader can say,
    /// and the chips have room for it at every size the app supports.
    var title: String {
        switch self {
        case .week: "7 days"
        case .fourWeeks: "4 weeks"
        case .twelveWeeks: "12 weeks"
        }
    }
}

/// The Run, as state.
///
/// ADR 0004's shape: an `@Observable` between the view and the repositories. It
/// owns the four things the screen needs and the two routes weight arrives by —
/// the keyboard and Apple Health — which converge on the same table the same way
/// Sub On's four routes converge on one write path.
///
/// **Every write here is local and returns immediately** (ADR 0005). The one
/// `async` method on the type is the Apple Health read, and it is async because
/// HealthKit is, not because the network is: nothing on this screen waits on a
/// server, and the trend renders identically with the radio off.
@MainActor
@Observable
final class TheRunModel {
    /// How far back the screen reads. Two years, so the twelve-week window and
    /// the four-week baseline both have room and a returning user's history is
    /// not silently truncated at the top of the chart.
    static let historyDays = 730

    // MARK: - What the screen shows

    private(set) var trend = WeightTrend(readings: [], calendar: .current)
    private(set) var readings: [WeightLog] = []
    private(set) var pace: Pace?
    private(set) var profile: Profile?

    /// Off by default, and that is §1.5 rather than a preference: the raw series
    /// is the thing the brief calls actively harmful to show as the headline.
    /// It is available because hiding a user's own measurements would be the
    /// opposite mistake.
    var showsRawReadings = false

    var range: TrendRange = .fourWeeks

    /// A write that did not land. Shown rather than swallowed.
    private(set) var writeFailed = false

    /// What the last Apple Health read produced. Nil until one has run —
    /// distinct from zero, which is a read that found nothing new.
    private(set) var lastImportCount: Int?

    private(set) var isReadingHealth = false

    // MARK: - Dependencies

    private let weights: any WeightRepositoryProtocol
    private let profiles: any ProfileRepositoryProtocol
    private let health: (any BodyMassSourcing)?
    private let calendar: Calendar
    private let now: () -> Date

    init(
        weights: any WeightRepositoryProtocol,
        profiles: any ProfileRepositoryProtocol,
        health: (any BodyMassSourcing)? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.weights = weights
        self.profiles = profiles
        self.health = health
        self.calendar = calendar
        self.now = now
    }

    // Deliberately **no `refresh()` in `init`.** `SubOnModel` does refresh on
    // init and can afford to: it is built inside a `.sheet` closure, which runs
    // when the sheet is presented. This one is built inside a `Tab` closure,
    // which SwiftUI re-evaluates on every render of the shell — so a fetch here
    // would be two store reads per render, thrown away every time, because
    // `@State` keeps the first instance and discards the rest. The view calls
    // `refresh()` from `onAppear`, which is when the data is actually wanted.

    // MARK: - Derived

    var readiness: TrendReadiness { TrendReadiness.of(trend) }

    /// The headline number: the latest point on the **smoothed** series, never
    /// the last thing the scale said.
    var latestTrendKg: Double? { trend.latest?.trendKg }

    /// The four-week change, or nil when the series does not reach back that
    /// far. Nil is rendered as a sentence, never as `0.0 kg` — a number the app
    /// did not compute is not shown (`DESIGN.md` § Numbers).
    var changeOverFourWeeks: Double? {
        trend.change(overDays: WeightTrend.baselineDays, calendar: calendar)
    }

    /// The day the first reading landed. The artboard's "SINCE 6 JUL".
    var startedOn: Date? { trend.earliest?.day }

    var standing: PaceStanding? {
        pace?.standing(for: trend, calendar: calendar)
    }

    /// What the chart draws: the smoothed series inside the selected window.
    var visiblePoints: [TrendPoint] {
        trend.points(inLast: range.days, calendar: calendar)
    }

    /// The pace line over the same window, or empty when there is no pace.
    var visiblePace: [TrendPoint] {
        guard let pace else { return [] }
        return pace.line(over: visiblePoints, calendar: calendar)
    }

    /// Whether Apple Health is worth offering at all. False on a device without
    /// it, where the screen says so rather than showing a button that cannot work.
    var offersHealth: Bool { health?.isAvailable ?? false }

    // MARK: - Reading

    func refresh() {
        let from = calendar.date(byAdding: .day, value: -Self.historyDays, to: now()) ?? .distantPast
        readings = weights.readings(since: from)
        trend = WeightTrend(readings: readings.map(\.weighIn), calendar: calendar)
        profile = profiles.current()
        pace = profile.flatMap { Pace.of(profile: $0, trend: trend) }
    }

    // MARK: - Writing

    /// Records a weigh-in. Returns whether it landed.
    ///
    /// The moment is a parameter because a weigh-in is a thing that happened at
    /// a time, not a thing that happens when you get round to typing it — the
    /// same reasoning the tracker records for backdating a food log. Stamping it
    /// with `Date()` would put this morning's reading on tonight's day, which
    /// moves it into the wrong bucket of a series that runs on calendar days.
    @discardableResult
    func record(kg: Double, at measuredAt: Date) -> Bool {
        guard Self.isStorable(kg) else { return false }
        do {
            try weights.record(kg: kg, at: measuredAt, source: .manual)
            writeFailed = false
            refresh()
            return true
        } catch {
            Log.data.error("Weight did not persist: \(error.localizedDescription, privacy: .public)")
            writeFailed = true
            return false
        }
    }

    /// Removes a reading.
    ///
    /// There is no 48-hour lock on this, and the asymmetry with `food_logs` is
    /// deliberate. §2.3's window exists because an editable food log is a way to
    /// rewrite a scored week; a weight is a measurement of a body, a mistyped
    /// one poisons every trend value after it for as long as it is stored, and
    /// the EWMA has no way to shrug it off. The honest fix for `7.84` is to
    /// remove it.
    @discardableResult
    func delete(_ log: WeightLog) -> Bool {
        do {
            try weights.delete(log)
            writeFailed = false
            refresh()
            return true
        } catch {
            Log.data.error("Weight removal did not persist: \(error.localizedDescription, privacy: .public)")
            writeFailed = true
            return false
        }
    }

    /// The last thing recorded, for the entry screen's typo guard.
    var mostRecent: WeightLog? { readings.last }

    // MARK: - Apple Health

    /// Asks for access, reads what is there, and writes what is new.
    ///
    /// **It cannot report a refusal**, and does not try to. Phase 0 measured
    /// that a denied read returns a result identical to "no data", so this
    /// finishes with a count either way and the copy covers both without
    /// claiming either.
    func readFromHealth() async {
        guard let health, health.isAvailable else { return }
        isReadingHealth = true
        defer { isReadingHealth = false }

        guard await health.requestAuthorization() else {
            // The request itself failed — no sheet, no device support. Not a
            // refusal, and not something to report as one.
            lastImportCount = 0
            return
        }

        let readings = await health.readings(since: syncWindowStart())
        do {
            let written = try weights.importReadings(readings, calendar: calendar)
            lastImportCount = written.count
            writeFailed = false
            refresh()
        } catch {
            Log.data.error("Health readings did not persist: \(error.localizedDescription, privacy: .public)")
            writeFailed = true
        }
    }

    /// Where a read starts.
    ///
    /// The day before the newest reading already held, so a sample written on a
    /// day the store has partly seen is still offered — and a year back when the
    /// store is empty, which is the first sync and the only one that has any
    /// history to fetch. `WeightReconciliation` drops whatever comes back twice,
    /// so the overlap costs nothing and closing it exactly would be the way to
    /// lose a reading at a boundary.
    private func syncWindowStart() -> Date {
        guard let newest = readings.last?.measuredAt else {
            return calendar.date(byAdding: .day, value: -365, to: now()) ?? .distantPast
        }
        return calendar.date(byAdding: .day, value: -1, to: newest) ?? newest
    }

    // MARK: - What can be stored

    /// `weight_logs.kg` is `numeric(5, 2) check (kg > 0 and kg < 500)`.
    ///
    /// Checked here so a value the column will refuse is refused on the screen
    /// that typed it, rather than at sync time on a row the user has long
    /// forgotten. **The bound is the column's, not an opinion about bodies** —
    /// the app has no basis to decide which weights are real, and §2.3's rule
    /// about outliers is explicit that over-aggressive rejection costs more
    /// honest users than it catches dishonest ones.
    static func isStorable(_ kg: Double) -> Bool { kg > 0 && kg < 500 }
}

#if DEBUG
extension TheRunModel {
    /// Eight weeks of a plausible run, for the previews. The artboard's numbers.
    static func preview(
        readingDays: Int = 56,
        goalType: GoalType = .lose,
        health: (any BodyMassSourcing)? = MockBodyMassSource()
    ) -> TheRunModel {
        let user = UUID()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var logs: [WeightLog] = []

        for offset in stride(from: readingDays - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weeks = Double(readingDays - 1 - offset) / 7
            // A trend of −0.3 kg a week, with the water on top of it that the
            // 7-day average exists to take back off.
            let noise = [0.0, 0.4, -0.3, 0.2, -0.5, 0.1, 0.3][offset % 7]
            logs.append(
                WeightLog(userID: user, measuredAt: day, kg: 80.6 - 0.3 * weeks + noise, source: .manual)
            )
        }

        let model = TheRunModel(
            weights: MockWeightRepository(logs: logs, userID: user),
            profiles: MockProfileRepository(
                profile: Profile(
                    id: user,
                    heightCm: 178,
                    sex: .male,
                    activityLevel: .moderate,
                    goalType: goalType,
                    goalWeightKg: 74,
                    targetRateKgPerWeek: 0.25
                )
            ),
            health: health,
            calendar: calendar
        )
        // Explicit, because `init` no longer does it and a preview has no
        // `onAppear` when it is a component rather than a screen.
        model.refresh()
        return model
    }
}
#endif
