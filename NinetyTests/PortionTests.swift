import Foundation
import Testing
@testable import Ninety

/// The portion arithmetic, and the day's log that makes a wrong one fixable.
///
/// **Both of these exist because of the same defect.** The portion screen filled
/// in `100 g` and the catalogue's `kcal_per_100g`, and then logged whatever was
/// in the calories field — so changing the portion to 200 g wrote 200 g of food
/// at 100 g of energy. Silently, with nothing on screen suggesting anything was
/// wrong, into the twenty-one days the whole ranking engine is designed against.
///
/// The first half of the fix is that the portion now drives the numbers. The
/// second is that a log written wrong can be found and corrected at all, which
/// it could not be: four routes wrote rows and nothing read them back.
@Suite("Portions and the day's log")
@MainActor
struct PortionTests {
    // MARK: - Scaling

    static let yogurt = PortionBasis(
        kcalPer100g: 133,
        proteinPer100g: 5.7,
        carbsPer100g: 4.5,
        fatPer100g: 10.2
    )

    /// The bug, as a test. Two hundred grams is twice the energy of one hundred.
    @Test("doubling the portion doubles the energy")
    func doublingThePortionDoublesTheEnergy() {
        #expect(Self.yogurt.scaled(toGrams: 100).kcal == 133)
        #expect(Self.yogurt.scaled(toGrams: 200).kcal == 266)
        #expect(Self.yogurt.scaled(toGrams: 50).kcal == 67)
    }

    @Test("macros scale with the portion too")
    func macrosScale() {
        let portion = Self.yogurt.scaled(toGrams: 200)
        #expect(portion.proteinG == 11.4)
        #expect(portion.carbsG == 9)
        #expect(portion.fatG == 20.4)
    }

    /// §1.2's rule about false precision holds on a derived figure as much as on
    /// a typed one — but a macro rounded to a whole gram is the opposite
    /// mistake, because 0.4 g is a real difference at the scale macros are read.
    @Test("calories round to whole numbers and macros keep one decimal")
    func roundingIsPerField() {
        let portion = Self.yogurt.scaled(toGrams: 37)
        #expect(portion.kcal == portion.kcal.rounded())
        #expect(portion.proteinG == 2.1)
    }

    @Test("a food with no macros scales its energy and invents nothing")
    func absentMacrosStayAbsent() {
        let portion = PortionBasis(kcalPer100g: 400).scaled(toGrams: 250)
        #expect(portion.kcal == 1_000)
        #expect(portion.proteinG == nil)
        #expect(portion.carbsG == nil)
        #expect(portion.fatG == nil)
    }

    /// A food with no energy figure is a name, not a basis. Scaling from zero
    /// would derive nought calories for every portion and look like it worked.
    @Test("a food with no energy figure is not a basis")
    func zeroEnergyIsNotABasis() {
        #expect(PortionBasis(FoodDraft(source: .custom, name: "Unknown", kcalPer100g: 0)) == nil)
        #expect(PortionBasis(FoodDraft(source: .off, name: "Yogurt", kcalPer100g: 133)) != nil)
    }

    @Test("a negative portion is treated as none, not as negative energy")
    func negativePortionsAreClamped() {
        #expect(Self.yogurt.scaled(toGrams: -50).kcal == 0)
    }

    // MARK: - The day's log

    static func harness(now: Date = Date()) -> (SubOnModel, MockFoodRepository) {
        let user = UUID()
        let foods = MockFoodRepository(userID: user, now: now)
        return (
            SubOnModel(
                foods: foods,
                profiles: MockProfileRepository(profile: Profile(id: user)),
                weights: MockWeightRepository(),
                now: { now }
            ),
            foods
        )
    }

    @discardableResult
    static func log(_ model: SubOnModel, _ name: String, kcal: Double, at moment: Date) -> FoodLog? {
        model.log(
            FoodLogDraft(grams: 100, kcal: kcal, name: name, entryMethod: .manual, loggedAt: moment)
        )
    }

    @Test("what was logged today is readable back, newest first")
    func todayIsReadableNewestFirst() {
        let now = Date()
        let (model, _) = Self.harness(now: now)

        Self.log(model, "Porridge", kcal: 320, at: now.addingTimeInterval(-3 * 3_600))
        Self.log(model, "Flat white", kcal: 120, at: now.addingTimeInterval(-1 * 3_600))

        #expect(model.today.map(\.nameSnapshot) == ["Flat white", "Porridge"])
    }

    /// The answer to a Squad row tapped twenty times by accident. Not a
    /// confirmation on the tap — that would cost the one-tap speed the screen is
    /// built on — but a list where the mistake is visible and removable.
    @Test("a log tapped by accident can be taken straight back out")
    func anAccidentalLogIsRemovable() throws {
        let now = Date()
        let (model, foods) = Self.harness(now: now)

        Self.log(model, "Flat white", kcal: 120, at: now)
        Self.log(model, "Flat white", kcal: 120, at: now)
        Self.log(model, "Flat white", kcal: 120, at: now)
        #expect(model.today.count == 3)

        let extra = try #require(model.today.first)
        #expect(model.delete(extra))

        #expect(model.today.count == 2)
        #expect(foods.storedLogs.count == 2)
        // And the running total follows, which is the number the band is read
        // against.
        #expect(model.loggedTodayKcal == 240)
    }

    @Test("a portion corrected after the fact moves the day's total with it")
    func correctingAPortionMovesTheTotal() throws {
        let now = Date()
        let (model, _) = Self.harness(now: now)

        Self.log(model, "Greek yogurt", kcal: 133, at: now)
        let log = try #require(model.today.first)

        #expect(model.update(log, grams: 200, kcal: 266, mealSlot: model.slot(of: log)))
        #expect(model.today.first?.kcal == 266)
        #expect(model.loggedTodayKcal == 266)
    }

    /// §2.3, and the rule holds through the new surface rather than only in the
    /// repository underneath it.
    @Test("a log past the 48-hour window can be neither corrected nor removed")
    func theEditWindowHoldsThroughTheNewSurface() throws {
        let now = Date()
        let (model, foods) = Self.harness(now: now)

        let old = FoodLog(
            userID: UUID(),
            loggedAt: now.addingTimeInterval(-72 * 3_600),
            grams: 100,
            entryMethod: .manual,
            kcal: 300,
            nameSnapshot: "Three days ago"
        )
        foods.storedLogs.append(old)

        #expect(!model.isEditable(old))
        #expect(!model.update(old, grams: 200, kcal: 600, mealSlot: model.slot(of: old)))
        #expect(!model.delete(old))
        #expect(model.writeFailed)
        #expect(foods.storedLogs.contains { $0.id == old.id })
    }

    /// The day, grouped as breakfast / lunch / dinner (ADR 0022).
    ///
    /// Still derived from `logged_at` for every row here, because none of the
    /// three routes that wrote them asked which meal it was — which is the half
    /// of the decision that keeps logging at the same number of taps it was
    /// before the column existed.
    @Test("the day's log splits into the three meals")
    func theDaySplitsIntoMeals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 9
        components.hour = 20
        let evening = calendar.date(from: components) ?? Date()

        let user = UUID()
        let model = SubOnModel(
            foods: MockFoodRepository(userID: user, now: evening),
            profiles: MockProfileRepository(profile: Profile(id: user)),
            weights: MockWeightRepository(),
            calendar: calendar,
            now: { evening }
        )

        components.hour = 8
        Self.log(model, "Porridge", kcal: 320, at: calendar.date(from: components) ?? evening)
        components.hour = 13
        Self.log(model, "Chicken salad", kcal: 545, at: calendar.date(from: components) ?? evening)
        components.hour = 19
        Self.log(model, "Salmon and rice", kcal: 640, at: calendar.date(from: components) ?? evening)

        #expect(model.today(in: .breakfast).map(\.nameSnapshot) == ["Porridge"])
        #expect(model.today(in: .lunch).map(\.nameSnapshot) == ["Chicken salad"])
        #expect(model.today(in: .dinner).map(\.nameSnapshot) == ["Salmon and rice"])
    }

    @Test("undoing the last log clears the strip rather than leaving it pointing at nothing")
    func deletingTheLastLogClearsTheUndoStrip() throws {
        let now = Date()
        let (model, _) = Self.harness(now: now)

        Self.log(model, "Flat white", kcal: 120, at: now)
        let logged = try #require(model.lastLogged)

        model.delete(logged)
        #expect(model.lastLogged == nil)
    }
}
