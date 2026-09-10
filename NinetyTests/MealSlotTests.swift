import Foundation
import Testing
@testable import Ninety

/// ADR 0022 — the stored meal slot, and the rule that keeps null meaning
/// "derived".
///
/// The derivation itself is tested in `SubOnTests`, alongside the date-boundary
/// criterion it inherited from First Half / Second Half. What is here is the
/// half that is new: a column whose absence is a statement, and a repository
/// that has to keep it that way.
@Suite("Meal slots")
@MainActor
struct MealSlotTests {
    static var london: Calendar { SubOnTests.london }

    static func at(_ hour: Int, _ minute: Int = 0, day: Int, in calendar: Calendar) -> Date {
        SubOnTests.at(hour, minute, day: day, in: calendar)
    }


    /// Null means derived, and the repository is what keeps it meaning that.
    ///
    /// The rule is easy to state and easy to lose: store the slot **only** where
    /// it disagrees with the derivation. Correcting a portion without touching
    /// the picker must not quietly fill the column, because a filled column is
    /// the user's word and would then survive a change to the boundaries that
    /// they never asked for.
    @Test("correcting a log stores a meal slot only when it differs from the derived one")
    func slotIsStoredOnlyWhenItOverrides() throws {
        let calendar = Self.london
        // 08:30 on the 8th derives as breakfast.
        let morning = Self.at(8, 30, day: 8, in: calendar)
        let user = UUID()
        let log = FoodLog(
            userID: user,
            loggedAt: morning,
            grams: 200,
            entryMethod: .manual,
            kcal: 260,
            nameSnapshot: "Porridge with milk"
        )
        let foods = MockFoodRepository(logs: [log], userID: user, now: morning)

        // Re-picking what was already showing writes nothing.
        try foods.update(log, grams: 220, kcal: 286, mealSlot: .breakfast, at: morning, calendar: calendar)
        #expect(log.storedMealSlot == nil)
        #expect(log.mealSlot(calendar: calendar) == .breakfast)

        // Moving it does, and the move is what a later read sees.
        try foods.update(log, grams: 220, kcal: 286, mealSlot: .dinner, at: morning, calendar: calendar)
        #expect(log.storedMealSlot == .dinner)
        #expect(log.mealSlot(calendar: calendar) == .dinner)

        // And it can be handed back to the derivation, which is the only way a
        // user undoes a correction they did not mean.
        try foods.update(log, grams: 220, kcal: 286, mealSlot: .breakfast, at: morning, calendar: calendar)
        #expect(log.storedMealSlot == nil)
    }

    /// §2.3 covers the slot too, and it costs nothing to prove: the lock is on
    /// the log, and the slot is part of the log. `food_logs_update_before_lock`
    /// says the same thing server-side.
    @Test("a locked log refuses a meal-slot correction like any other edit")
    func lockedLogRefusesASlotChange() {
        let calendar = Self.london
        let threeDaysAgo = Self.at(9, day: 5, in: calendar)
        let now = Self.at(9, day: 8, in: calendar)
        let user = UUID()
        let log = FoodLog(
            userID: user,
            loggedAt: threeDaysAgo,
            grams: 200,
            entryMethod: .manual,
            kcal: 260,
            nameSnapshot: "Porridge with milk"
        )
        let foods = MockFoodRepository(logs: [log], userID: user, now: now)

        #expect(throws: RepositoryError.self) {
            try foods.update(log, grams: 200, kcal: 260, mealSlot: .dinner, at: now, calendar: calendar)
        }
        #expect(log.storedMealSlot == nil)
    }
}
