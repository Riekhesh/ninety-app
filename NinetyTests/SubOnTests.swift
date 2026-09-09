import Foundation
import Testing
@testable import Ninety

/// P1-F — the Sub On screen, the team sheet, and the routes that write.
@Suite("Sub On")
@MainActor
struct SubOnTests {
    /// A calendar that is not the machine's, so a test can state a time of day
    /// and mean it. London is used because it is the one the app is being built
    /// in and because it has a summer offset, which is where the date-boundary
    /// bug would live.
    static var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }

    static func moment(_ iso: String, in calendar: Calendar) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? Date()
    }

    // MARK: - First Half / Second Half

    @Test("the halves change over at midday")
    func halvesChangeAtMidday() {
        let calendar = Self.london
        #expect(MealPeriod.of(Self.moment("2026-09-08T08:30:00Z", in: calendar), calendar: calendar) == .firstHalf)
        #expect(MealPeriod.of(Self.moment("2026-09-08T11:59:00Z", in: calendar), calendar: calendar) == .firstHalf)
        #expect(MealPeriod.of(Self.moment("2026-09-08T12:00:00Z", in: calendar), calendar: calendar) == .secondHalf)
        #expect(MealPeriod.of(Self.moment("2026-09-08T19:45:00Z", in: calendar), calendar: calendar) == .secondHalf)
    }

    /// The acceptance criterion: *"First Half / Second Half meal periods assign
    /// correctly across a date boundary."*
    ///
    /// A late dinner is the Second Half of the day it was eaten, and a 00:10
    /// snack is the First Half of the next one — never the Second Half of the
    /// day before, which is what an hour read off a fixed UTC offset would say
    /// in British Summer Time.
    @Test("a log either side of midnight lands in the right half of the right day")
    func acrossTheDateBoundary() {
        let calendar = Self.london

        // 23:30 on 8 September, British Summer Time — 22:30 UTC.
        let lateDinner = Self.moment("2026-09-08T22:30:00Z", in: calendar)
        // 00:10 on 9 September BST — 23:10 UTC on the 8th. UTC says "still the
        // 8th, late evening"; the user's calendar says "the 9th, first thing",
        // and the user's calendar is what the log is counted against.
        let midnightSnack = Self.moment("2026-09-08T23:10:00Z", in: calendar)

        #expect(MealPeriod.of(lateDinner, calendar: calendar) == .secondHalf)
        #expect(MealPeriod.of(midnightSnack, calendar: calendar) == .firstHalf)

        // And the halves agree with the days the repository counts them against.
        #expect(!calendar.isDate(lateDinner, inSameDayAs: midnightSnack))
    }

    @Test("the changeover hour is read from the calendar, not from UTC")
    func periodUsesTheGivenCalendar() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        // 23:00 UTC is 08:00 the next morning in Tokyo. The same instant is a
        // different half in each place, which is the whole point of passing one.
        let instant = ISO8601DateFormatter().date(from: "2026-09-08T23:00:00Z") ?? Date()
        #expect(MealPeriod.of(instant, calendar: Self.london) == .secondHalf)
        #expect(MealPeriod.of(instant, calendar: tokyo) == .firstHalf)
    }

    // MARK: - The Squad and the Bench

    /// `SampleLog` is the shared fixture type in `SubOnPreviews.swift`, so the
    /// previews and the tests are built from the same shape. A preview standing
    /// on different numbers from the tests is a preview of something nobody
    /// checked.
    static func logs(_ samples: [SampleLog], from now: Date) -> [FoodLog] {
        samples.logs(for: UUID(), endingAt: now)
    }

    @Test("a food logged twice is in the Squad; a food logged once is not")
    func squadNeedsTwoAppearances() {
        let now = Date()
        let habits = TeamSheet.habits(
            from: Self.logs(
                [
                    SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 1),
                    SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 25),
                    SampleLog(name: "Sourdough toast", grams: 90, kcal: 280, hoursAgo: 3),
                ],
                from: now
            )
        )

        let squad = TeamSheet.squad(from: habits, limit: 5)
        #expect(squad.map(\.name) == ["Flat white"])
        #expect(squad.first?.appearances == 2)

        // The one-off is recent rather than frequent, so it is on the Bench.
        let bench = TeamSheet.bench(from: habits, excluding: squad, limit: 5)
        #expect(bench.map(\.name) == ["Sourdough toast"])
    }

    @Test("nothing appears on both lists")
    func squadAndBenchDoNotOverlap() {
        let now = Date()
        let habits = TeamSheet.habits(
            from: Self.logs(
                [
                    SampleLog(name: "Porridge", grams: 250, kcal: 320, hoursAgo: 1),
                    SampleLog(name: "Porridge", grams: 250, kcal: 320, hoursAgo: 25),
                    SampleLog(name: "Porridge", grams: 250, kcal: 320, hoursAgo: 49),
                    SampleLog(name: "Banana", grams: 118, kcal: 105, hoursAgo: 2),
                ],
                from: now
            )
        )
        let squad = TeamSheet.squad(from: habits, limit: 5)
        let bench = TeamSheet.bench(from: habits, excluding: squad, limit: 5)
        #expect(Set(squad.map(\.id)).isDisjoint(with: Set(bench.map(\.id))))
    }

    @Test("a habit carries the portion it was last logged at")
    func habitCarriesTheLatestPortion() {
        let now = Date()
        // Oldest first, so this also proves the grouping does not depend on the
        // repository's sort order.
        let habits = TeamSheet.habits(
            from: Self.logs(
                [
                    SampleLog(name: "Porridge", grams: 200, kcal: 250, hoursAgo: 48),
                    SampleLog(name: "Porridge", grams: 300, kcal: 400, hoursAgo: 1),
                ],
                from: now
            )
        )
        #expect(habits.first?.grams == 300)
        #expect(habits.first?.kcal == 400)
    }

    @Test("two foods on the same count break the tie on recency")
    func squadTiesBreakOnRecency() {
        let now = Date()
        let habits = TeamSheet.habits(
            from: Self.logs(
                [
                    SampleLog(name: "Older", grams: 100, kcal: 100, hoursAgo: 100),
                    SampleLog(name: "Older", grams: 100, kcal: 100, hoursAgo: 120),
                    SampleLog(name: "Newer", grams: 100, kcal: 100, hoursAgo: 1),
                    SampleLog(name: "Newer", grams: 100, kcal: 100, hoursAgo: 30),
                ],
                from: now
            )
        )
        #expect(TeamSheet.squad(from: habits, limit: 5).map(\.name) == ["Newer", "Older"])
    }

    /// A quick add has no `Food` row at all. Grouping on the food id would drop
    /// it from the team sheet entirely, which is why the key is the name.
    @Test("a quick add with no food row still reaches the team sheet")
    func quickAddReachesTheTeamSheet() {
        let now = Date()
        let habits = TeamSheet.habits(
            from: Self.logs(
                [
                    SampleLog(name: "Pub lunch", grams: 1, kcal: 850, hoursAgo: 2),
                    SampleLog(name: "Pub lunch", grams: 1, kcal: 850, hoursAgo: 26),
                ],
                from: now
            )
        )
        #expect(habits.count == 1)
        #expect(habits.first?.foodID == nil)
        #expect(TeamSheet.squad(from: habits, limit: 5).count == 1)
    }

    // MARK: - Logging

    static func model(logs: [FoodLog] = [], now: Date = Date()) -> (SubOnModel, MockFoodRepository) {
        let user = UUID()
        let foods = MockFoodRepository(logs: logs, userID: user, now: now)
        let profile = Profile(
            id: user,
            dob: Calendar.current.date(byAdding: .year, value: -32, to: now),
            heightCm: 178,
            sex: .male,
            activityLevel: .moderate,
            goalType: .lose,
            goalWeightKg: 76,
            targetRateKgPerWeek: 0.5
        )
        let model = SubOnModel(
            foods: foods,
            profiles: MockProfileRepository(profile: profile),
            weights: MockWeightRepository(
                logs: [WeightLog(userID: user, measuredAt: now, kg: 84, source: .manual)]
            ),
            now: { now }
        )
        return (model, foods)
    }

    @Test("bringing a food on repeats its last portion, with no network involved")
    func tapToBringOn() throws {
        let now = Date()
        let (model, foods) = Self.model(
            logs: Self.logs(
                [
                    SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 2),
                    SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 26),
                ],
                from: now
            ),
            now: now
        )

        let habit = try #require(model.squad.first)
        model.log(habit)

        #expect(foods.loggedCount == 1)
        let written = try #require(foods.storedLogs.last)
        #expect(written.nameSnapshot == "Flat white")
        #expect(written.grams == 220)
        #expect(written.kcal == 120)
        #expect(written.entryMethod == .manual)
    }

    @Test("undo takes the last log straight back out")
    func undoRemovesTheLog() {
        let now = Date()
        let (model, foods) = Self.model(now: now)
        model.log(
            FoodLogDraft(grams: 100, kcal: 250, name: "Porridge", entryMethod: .manual, loggedAt: now)
        )
        #expect(foods.storedLogs.count == 1)

        model.undoLast()
        #expect(foods.storedLogs.isEmpty)
        #expect(model.lastLogged == nil)
    }

    @Test("a write that fails is shown, not swallowed")
    func failedWriteSurfaces() {
        let now = Date()
        let (model, foods) = Self.model(now: now)
        foods.logError = RepositoryError.noProfile

        let written = model.log(
            FoodLogDraft(grams: 100, kcal: 250, name: "Porridge", entryMethod: .manual, loggedAt: now)
        )
        #expect(written == nil)
        #expect(model.writeFailed)
    }

    /// The four routes each owe `entry_method` a different value, and it is an
    /// acceptance criterion on three of the four tickets.
    @Test("every entry method the four routes write round-trips")
    func everyEntryMethodIsWritable() {
        let now = Date()
        let (model, foods) = Self.model(now: now)

        for method in EntryMethod.allCases {
            model.log(
                FoodLogDraft(
                    grams: 100,
                    kcal: 100,
                    name: "Test \(method.rawValue)",
                    entryMethod: method,
                    loggedAt: now
                )
            )
        }

        #expect(Set(foods.storedLogs.map(\.entryMethod)) == Set(EntryMethod.allCases))
    }

    // MARK: - Room left

    @Test("room left is the band's centre minus what is already logged")
    func roomLeftCountsDown() throws {
        let now = Date()
        let (model, _) = Self.model(now: now)

        let band = try #require(model.band)
        #expect(model.roomLeftKcal == band.centre)

        model.log(FoodLogDraft(grams: 100, kcal: 500, name: "Lunch", entryMethod: .manual, loggedAt: now))
        #expect(model.roomLeftKcal == band.centre - 500)
    }

    /// §10 S5's structural half. Going past the band is a fact, not an error,
    /// and the room-left figure keeps counting rather than clamping at zero and
    /// pretending the day is closed.
    @Test("going past the band is neutral and the figure goes negative")
    func aboveTheBandIsNotAnError() throws {
        let now = Date()
        let (model, _) = Self.model(now: now)
        let band = try #require(model.band)

        model.log(
            FoodLogDraft(
                grams: 100,
                kcal: Double(band.upper + 400),
                name: "A big day",
                entryMethod: .manual,
                loggedAt: now
            )
        )

        #expect(model.bandState == .above)
        #expect(model.bandState?.tone == .neutral)
        #expect((model.roomLeftKcal ?? 0) < 0)
    }

    @Test("no band means a sentence, never a zero")
    func noBandIsNil() {
        let now = Date()
        let user = UUID()
        // A profile that has not finished Pre-Season: no height, no weight.
        let model = SubOnModel(
            foods: MockFoodRepository(userID: user, now: now),
            profiles: MockProfileRepository(profile: Profile(id: user)),
            weights: MockWeightRepository(),
            now: { now }
        )
        #expect(model.band == nil)
        #expect(model.roomLeftKcal == nil)
        #expect(model.bandState == nil)
    }

    // MARK: - Parsing what the user typed

    @Test("a decimal comma is a decimal point")
    func commaDecimalsParse() {
        #expect(ManualEntryView.number("78,4") == 78.4)
        #expect(ManualEntryView.number("78.4") == 78.4)
        #expect(ManualEntryView.number(" 250 ") == 250)
        #expect(ManualEntryView.number("") == nil)
        #expect(ManualEntryView.number("0") == nil)
        #expect(ManualEntryView.number("-5") == nil)
        #expect(ManualEntryView.number("porridge") == nil)
    }
}
