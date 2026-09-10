import Foundation
import SwiftData
import Testing
@testable import Ninety

/// The local store and the repositories over it.
///
/// These use a real `ModelContainer` with `isStoredInMemoryOnly` — the store is
/// the thing under test, so mocking it would test nothing. The ViewModel-facing
/// guarantees are checked against the mocks instead, in `MockRepositoryTests`.
@MainActor
@Suite("Data layer")
struct DataLayerTests {
    private func store() throws -> (ModelContext, UUID) {
        let container = try ModelContainer.ninety(inMemory: true)
        return (ModelContext(container), UUID())
    }

    @Test("the schema opens, and holds every model the app has")
    func schemaOpens() throws {
        let container = try ModelContainer.ninety(inMemory: true)
        #expect(NinetySchemaV1.models.count == 8)
        #expect(container.schema.entities.count == NinetySchemaV1.models.count)
    }

    @Test("a logged meal is readable immediately, without waiting on anything")
    func writesAreLocalFirst() throws {
        let (context, user) = try store()
        let food = SwiftDataFoodRepository(context: context, userID: user)
        let noon = Date(timeIntervalSince1970: 1_800_000_000)

        try food.log(
            FoodLogDraft(
                grams: 250,
                kcal: 450,
                name: "Chicken salad bowl",
                entryMethod: .manual,
                loggedAt: noon
            )
        )

        let logs = food.logs(on: noon, calendar: .current)
        #expect(logs.count == 1)
        #expect(logs.first?.nameSnapshot == "Chicken salad bowl")
        #expect(logs.first?.kcal == 450)
    }

    @Test("every write leaves something in the outbox for the sync service")
    func writesEnqueueForSync() throws {
        let (context, user) = try store()
        let food = SwiftDataFoodRepository(context: context, userID: user)
        let weight = SwiftDataWeightRepository(context: context, userID: user)

        let draft = FoodLogDraft(grams: 100, kcal: 120, name: "Flat white", entryMethod: .manual, loggedAt: .now)
        try food.log(draft)
        try weight.record(kg: 78.4, at: .now, source: .manual)

        let queued = try context.fetch(FetchDescriptor<OutboxEntry>())
        #expect(queued.count == 2)
        #expect(Set(queued.map(\.tableName)) == ["food_logs", "weight_logs"])
        #expect(queued.allSatisfy { $0.operation == .insert })
    }

    @Test("a log locks 48 hours after it was logged, not after it was written")
    func editLockUsesLoggedAt() throws {
        let (context, user) = try store()
        let food = SwiftDataFoodRepository(context: context, userID: user)
        let loggedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let entry = try food.log(
            FoodLogDraft(
                grams: 100,
                kcal: 200,
                name: "Greek yogurt & berries",
                entryMethod: .manual,
                loggedAt: loggedAt
            )
        )

        #expect(entry.isEditable(at: loggedAt.addingTimeInterval(47 * 3_600)))
        #expect(!entry.isEditable(at: loggedAt.addingTimeInterval(49 * 3_600)))

        try food.update(
            entry,
            grams: 150,
            kcal: 300,
            // The slot the derivation already gives it, so this stays a portion
            // correction and nothing else — ADR 0022 stores a slot only where
            // it disagrees, and the assertion below is about `grams`.
            mealSlot: entry.mealSlot(calendar: .current),
            at: loggedAt.addingTimeInterval(3_600),
            calendar: .current
        )
        #expect(entry.grams == 150)

        #expect(throws: RepositoryError.self) {
            try food.update(
                entry,
                grams: 999,
                kcal: 999,
                mealSlot: entry.mealSlot(calendar: .current),
                at: loggedAt.addingTimeInterval(49 * 3_600),
                calendar: .current
            )
        }
    }

    @Test("a locked log cannot be deleted either")
    func lockAlsoCoversDeletion() throws {
        let (context, user) = try store()
        let food = SwiftDataFoodRepository(context: context, userID: user)
        let loggedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let draft = FoodLogDraft(grams: 10, kcal: 10, name: "x", entryMethod: .manual, loggedAt: loggedAt)
        let entry = try food.log(draft)

        #expect(throws: RepositoryError.self) {
            try food.delete(entry, at: loggedAt.addingTimeInterval(72 * 3_600))
        }
    }

    @Test("one row per day: re-reading HealthKit does not double-count")
    func healthSamplesUpsertByDay() throws {
        let (context, user) = try store()
        let health = SwiftDataHealthRepository(context: context, userID: user)
        let day = Calendar.current.startOfDay(for: .now)

        try health.upsert(day: day, steps: 4_000, activeEnergy: 200, exerciseMinutes: 10, workoutCount: 0)
        try health.upsert(day: day, steps: 8_200, activeEnergy: 430, exerciseMinutes: 25, workoutCount: 1)

        let stored = health.samples(from: day, to: day)
        #expect(stored.count == 1)
        #expect(stored.first?.steps == 8_200)
    }

    @Test("the HealthKit anchor survives being written and read back")
    func anchorPersists() throws {
        let (context, user) = try store()
        let health = SwiftDataHealthRepository(context: context, userID: user)

        #expect(health.anchor() == nil, "a first run must have no anchor — that is when full history is correct")
        try health.saveAnchor(Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(health.anchor() == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test("one user's rows are invisible to another on the same device")
    func localRowsAreScopedToTheirUser() throws {
        let container = try ModelContainer.ninety(inMemory: true)
        let context = ModelContext(container)
        let alice = SwiftDataFoodRepository(context: context, userID: UUID())
        let bob = SwiftDataFoodRepository(context: context, userID: UUID())
        let noon = Date(timeIntervalSince1970: 1_800_000_000)

        let lunch = FoodLogDraft(
            grams: 100,
            kcal: 500,
            name: "Alice's lunch",
            entryMethod: .manual,
            loggedAt: noon
        )
        try alice.log(lunch)

        #expect(alice.logs(on: noon, calendar: .current).count == 1)
        #expect(bob.logs(on: noon, calendar: .current).isEmpty)
    }
}
