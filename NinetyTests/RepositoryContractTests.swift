import Foundation
import Testing
@testable import Ninety

/// The two rules every repository holds to, checked against the mocks.
///
/// Both come from measurements rather than taste, and both are easy to break by
/// accident in a later epic — which is why they are asserted here rather than
/// only described in the protocol's doc comment.
@MainActor
@Suite("Repository contract")
struct RepositoryContractTests {
    /// Phase 0 established there is no permission-denied branch to write: a
    /// denied HealthKit read returns a result identical to "no data" and iOS
    /// will never distinguish them. A repository that throws on absence forces
    /// every call site to invent a difference that does not exist.
    @Test("a read with nothing to return gives an empty result, not an error")
    func emptyReadsDoNotThrow() {
        let repos = Repositories.mock()

        #expect(repos.profile.current() == nil)
        #expect(repos.food.logs(on: .now, calendar: .current).isEmpty)
        #expect(repos.food.foods(matching: "hummus", limit: 20).isEmpty)
        #expect(repos.weight.recent(limit: 7).isEmpty)
        #expect(repos.health.samples(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(repos.health.anchor() == nil)
    }

    @Test("an empty search is not a search")
    func blankQueryReturnsNothing() {
        let food = MockFoodRepository(catalogue: [
            Food(source: .custom, name: "Porridge with milk", kcalPer100g: 90),
        ])
        #expect(food.foods(matching: "   ", limit: 20).isEmpty)
        #expect(food.foods(matching: "porridge", limit: 20).count == 1)
    }

    @Test("the mocks honour the 48-hour lock, so a ViewModel test can rely on it")
    func mocksEnforceTheEditLock() throws {
        let food = MockFoodRepository()
        let loggedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = try food.log(
            FoodLogDraft(
                grams: 100,
                kcal: 100,
                name: "Flat white",
                entryMethod: .manual,
                loggedAt: loggedAt
            )
        )

        #expect(throws: RepositoryError.self) {
            try food.update(
                entry,
                grams: 200,
                kcal: 200,
                mealSlot: entry.mealSlot(calendar: .current),
                at: loggedAt.addingTimeInterval(72 * 3_600),
                calendar: .current
            )
        }
    }

    @Test("§10 S6: the opt-out is readable without a profile existing")
    func optOutDefaultsSafely() {
        #expect(MockProfileRepository().isCompetitiveOptOutEnabled() == false)

        let optedOut = Profile(id: UUID(), competitiveOptOut: true)
        #expect(MockProfileRepository(profile: optedOut).isCompetitiveOptOutEnabled())
    }

    @Test("§10 S1: an unspecified sex takes the higher floor, because erring high is safe")
    func calorieFloorErrsHigh() {
        #expect(Sex.female.calorieFloor == 1_200)
        #expect(Sex.male.calorieFloor == 1_500)
        #expect(Sex.unspecified.calorieFloor == Sex.male.calorieFloor)
    }

    @Test("§10 S4: the age gate is computed on the day, not by subtracting years")
    func ageGateUsesTheActualDate() {
        var calendar = Calendar(identifier: .gregorian)
        // Fixed, because a gate that reads ambient state cannot be tested.
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let born = calendar.date(from: DateComponents(year: 2008, month: 9, day: 3))
        let profile = Profile(id: UUID(), dob: born)

        let dayBefore18th = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2))
        let on18th = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))

        #expect(dayBefore18th.map { !profile.isAdult(on: $0, calendar: calendar) } == true)
        #expect(on18th.map { profile.isAdult(on: $0, calendar: calendar) } == true)
    }
}
