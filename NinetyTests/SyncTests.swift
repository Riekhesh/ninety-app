import Foundation
import SwiftData
import Testing
@testable import Ninety

/// The drain, over a real store.
///
/// `ModelContainer(isStoredInMemoryOnly:)` for the same reason `DataLayerTests`
/// uses one: the local store is half of what is under test here, and mocking it
/// would test nothing. The network is the half that is mocked, because the
/// question P1-I asks — what happens when the server says no, or says nothing at
/// all — cannot be asked of a live project on purpose.
@MainActor
@Suite("Sync · draining the outbox")
struct SyncTests {
    /// The network, as a notebook.
    @MainActor
    private final class Recorder: SyncWriting {
        var upserts: [SyncRow] = []
        var deletes: [(table: SyncTable, id: UUID)] = []
        /// Set to make every write fail the same way.
        var failure: SyncFailure?

        func upsert(_ row: SyncRow) async throws {
            if let failure { throw failure }
            upserts.append(row)
        }

        func delete(from table: SyncTable, id: UUID) async throws {
            if let failure { throw failure }
            deletes.append((table, id))
        }
    }

    @MainActor
    private struct Fixture {
        let context: ModelContext
        let userID: UUID
        let food: SwiftDataFoodRepository
        let weight: SwiftDataWeightRepository
        let client: Recorder
        let service: SyncService

        var queued: [OutboxEntry] {
            (try? context.fetch(FetchDescriptor<OutboxEntry>())) ?? []
        }
    }

    private static let noon = Date(timeIntervalSince1970: 1_800_000_000)

    private func fixture(now: @escaping () -> Date = { SyncTests.noon }) throws -> Fixture {
        let container = try ModelContainer.ninety(inMemory: true)
        let context = ModelContext(container)
        let userID = UUID()
        let client = Recorder()
        return Fixture(
            context: context,
            userID: userID,
            food: SwiftDataFoodRepository(context: context, userID: userID),
            weight: SwiftDataWeightRepository(context: context, userID: userID),
            client: client,
            service: SyncService(
                store: SyncStore(context: context, userID: userID),
                client: client,
                now: now
            )
        )
    }

    private func meal(
        _ name: String,
        grams: Double = 250,
        kcal: Double = 450,
        at moment: Date = SyncTests.noon
    ) -> FoodLogDraft {
        FoodLogDraft(grams: grams, kcal: kcal, name: name, entryMethod: .manual, loggedAt: moment)
    }

    // MARK: - The ordinary day

    @Test("a logged meal reaches the server, and the queue empties behind it")
    func aMealGoesUp() async throws {
        let world = try fixture()
        try world.food.log(meal("Chicken salad bowl"))

        await world.service.drain()

        #expect(world.client.upserts.count == 1)
        #expect(world.client.upserts.first?.table == .foodLogs)
        #expect(world.client.upserts.first?.columns["name_snapshot"] == .text("Chicken salad bowl"))
        #expect(world.queued.isEmpty)
        #expect(world.service.status == .upToDate(lastSentAt: Self.noon))
    }

    @Test("a second drain has nothing to say")
    func drainingTwiceSendsOnce() async throws {
        let world = try fixture()
        try world.food.log(meal("Flat white", grams: 200, kcal: 120))

        await world.service.drain()
        await world.service.drain()

        #expect(world.client.upserts.count == 1)
    }

    @Test("a custom food goes up before the log that references it")
    func foreignKeysAreRespectedEndToEnd() async throws {
        let world = try fixture()
        let chilli = try world.food.saveFood(
            FoodDraft(source: .custom, name: "Dad's chilli", kcalPer100g: 140)
        )
        try world.food.log(
            FoodLogDraft(
                food: chilli,
                grams: 300,
                kcal: 420,
                name: "Dad's chilli",
                entryMethod: .manual,
                loggedAt: Self.noon
            )
        )

        await world.service.drain()

        #expect(world.client.upserts.map(\.table) == [.foods, .foodLogs])
    }

    @Test("a meal corrected before it ever went up is one write, with the correction in it")
    func correctionsBeforeSyncCollapse() async throws {
        let world = try fixture()
        let log = try world.food.log(meal("Porridge with milk", grams: 200, kcal: 260))
        try world.food.update(
            log,
            to: FoodLogCorrection(grams: 300, kcal: 390, mealSlot: log.mealSlot(calendar: .current)),
            at: Self.noon.addingTimeInterval(600),
            calendar: .current
        )

        await world.service.drain()

        #expect(world.client.upserts.count == 1)
        #expect(world.client.upserts.first?.columns["grams"] == .number(300))
        #expect(world.client.upserts.first?.columns["kcal"] == .number(390))
        #expect(world.queued.isEmpty)
    }

    @Test("a meal logged and taken back before either went up is a delete and nothing else")
    func loggedAndRemovedOffline() async throws {
        let world = try fixture()
        let log = try world.food.log(meal("A tap I did not mean"))
        let id = log.id
        try world.food.delete(log, at: Self.noon.addingTimeInterval(60))

        await world.service.drain()

        // Removing a row the server never received is a no-op there, which is
        // the right answer rather than a lucky one.
        #expect(world.client.upserts.isEmpty)
        #expect(world.client.deletes.map { $0.id } == [id])
        #expect(world.queued.isEmpty)
    }

    @Test("weight and food both drain, and a weigh-in carries its natural key")
    func weightSyncsToo() async throws {
        let world = try fixture()
        try world.weight.record(kg: 78.4, at: Self.noon, source: .manual)

        await world.service.drain()

        let row = try #require(world.client.upserts.first)
        #expect(row.table == .weightLogs)
        #expect(row.columns["kg"] == .number(78.4))
        #expect(row.table.conflictTarget == "user_id,measured_at,source")
    }

    // MARK: - The day with the radio off

    @Test("with no connection the queue is kept whole and nothing is charged an attempt")
    func offlineCostsTheQueueNothing() async throws {
        let world = try fixture()
        try world.food.log(meal("Breakfast"))
        try world.food.log(meal("Lunch", at: Self.noon.addingTimeInterval(3_600)))
        world.client.failure = .offline

        await world.service.drain()

        #expect(world.client.upserts.isEmpty)
        #expect(world.queued.count == 2)
        // The property the 21-day clock turns into a requirement: a week logged
        // on a plane must not land already parked.
        #expect(world.queued.allSatisfy { $0.attempts == 0 })
        #expect(world.service.status == .waiting(changes: 2))
    }

    @Test("the drain stops at the first connection failure rather than working down the queue")
    func oneFailureEndsThePass() async throws {
        let world = try fixture()
        for hour in 0..<5 {
            try world.food.log(meal("Meal \(hour)", at: Self.noon.addingTimeInterval(Double(hour) * 3_600)))
        }
        world.client.failure = .unavailable

        await world.service.drain()

        #expect(world.queued.count == 5)
        #expect(world.queued.allSatisfy { $0.attempts == 0 })
    }

    @Test("a day logged with the radio off arrives whole when it comes back")
    func theQueueDrainsOnReconnect() async throws {
        let world = try fixture()
        world.client.failure = .offline
        try world.food.log(meal("Breakfast"))
        try world.food.log(meal("Lunch", at: Self.noon.addingTimeInterval(3_600)))
        try world.weight.record(kg: 78.1, at: Self.noon, source: .manual)
        await world.service.drain()
        #expect(world.client.upserts.isEmpty)

        world.client.failure = nil
        await world.service.drain()

        #expect(world.client.upserts.count == 3)
        #expect(world.queued.isEmpty)
        #expect(world.service.status == .upToDate(lastSentAt: Self.noon))
    }

    @Test("a failed drain never touches what was logged")
    func theDrainCannotCostADay() async throws {
        let world = try fixture()
        try world.food.log(meal("The day itself"))
        world.client.failure = .refused(status: 409)

        await world.service.drain()

        // The rule `SyncStore` is written around: the only thing this layer may
        // delete is a queue entry. A sync service that can remove a logged day
        // is one bad response away from costing three weeks.
        #expect(world.food.logs(on: Self.noon, calendar: .current).count == 1)
    }

    // MARK: - When the server says no

    @Test("a refusal is charged to the row, and the fifth one parks it")
    func fiveRefusalsPark() async throws {
        let world = try fixture()
        try world.food.log(meal("Something the server will not take"))
        world.client.failure = .refused(status: 409)

        await world.service.drain()
        #expect(world.queued.first?.attempts == 1)
        #expect(world.service.status == .waiting(changes: 1))

        for _ in 1..<OutboxDrain.maxAttempts { await world.service.drain() }

        #expect(world.queued.count == 1)
        #expect(world.queued.first?.attempts == OutboxDrain.maxAttempts)
        // Kept and counted, never retried silently until the end of time.
        #expect(world.service.status == .stuck(changes: 1))
        #expect(world.service.stuckCount == 1)
    }

    @Test("a parked row can be asked again, and goes when the server relents")
    func retryUnparks() async throws {
        let world = try fixture()
        try world.food.log(meal("Something the server would not take"))
        world.client.failure = .refused(status: 409)
        for _ in 0..<OutboxDrain.maxAttempts { await world.service.drain() }
        #expect(world.service.stuckCount == 1)

        world.client.failure = nil
        world.service.retryStuck()
        await world.service.drain()

        #expect(world.client.upserts.count == 1)
        #expect(world.queued.isEmpty)
        #expect(world.service.stuckCount == 0)
    }

    // MARK: - Nothing left to say

    @Test("a correction that missed the 48-hour window is dropped, not retried")
    func lateEditsAreDropped() async throws {
        var clock = Self.noon
        let world = try fixture(now: { clock })

        let log = try world.food.log(meal("Logged, then corrected, then offline for two days"))
        await world.service.drain()
        #expect(world.client.upserts.count == 1)

        // Inside the window, so the app allows it and queues it.
        try world.food.update(
            log,
            to: FoodLogCorrection(grams: 300, kcal: 500, mealSlot: log.mealSlot(calendar: .current)),
            at: Self.noon.addingTimeInterval(3_600),
            calendar: .current
        )
        #expect(world.queued.count == 1)

        // Out the other side of it by the time there is a signal.
        clock = Self.noon.addingTimeInterval(49 * 3_600)
        await world.service.drain()

        // §2.3 wins, and it is right to: the rule is what bounds the window in
        // which a last-write-wins conflict is possible at all (ADR 0005).
        // Dropped deliberately, rather than by five refusals and a parked row
        // that looks like a bug.
        #expect(world.client.upserts.count == 1)
        #expect(world.queued.isEmpty)
    }

    @Test("an insert is never dropped for lateness, however long the radio was off")
    func lateInsertsStillLand() async throws {
        var clock = Self.noon
        let world = try fixture(now: { clock })
        try world.food.log(meal("A week underground"))

        clock = Self.noon.addingTimeInterval(8 * 24 * 3_600)
        await world.service.drain()

        // `food_logs_insert` has no lock clause and must not: a week logged
        // with the radio off has to arrive whole however late it is.
        #expect(world.client.upserts.count == 1)
        #expect(world.queued.isEmpty)
    }

    // MARK: - What the panel reads

    @Test("the count is rows waiting, not notes in the queue")
    func statusCountsRows() async throws {
        let world = try fixture()
        let log = try world.food.log(meal("Corrected twice"))
        try world.food.update(
            log,
            to: FoodLogCorrection(grams: 260, kcal: 470, mealSlot: log.mealSlot(calendar: .current)),
            at: Self.noon.addingTimeInterval(60),
            calendar: .current
        )
        try world.food.update(
            log,
            to: FoodLogCorrection(grams: 270, kcal: 480, mealSlot: log.mealSlot(calendar: .current)),
            at: Self.noon.addingTimeInterval(120),
            calendar: .current
        )
        try world.food.log(meal("Left alone", at: Self.noon.addingTimeInterval(3_600)))

        world.service.refreshStatus()

        #expect(world.queued.count == 4)
        #expect(world.service.status == .waiting(changes: 2))
    }

    @Test("a build with no project in it says so rather than counting forever")
    func noProject() async throws {
        let container = try ModelContainer.ninety(inMemory: true)
        let context = ModelContext(container)
        let userID = UUID()
        let food = SwiftDataFoodRepository(context: context, userID: userID)
        let service = SyncService(
            store: SyncStore(context: context, userID: userID),
            client: nil
        )

        try food.log(meal("Logged on a clone with no Local.xcconfig"))
        await service.drain()

        #expect(service.status == .noProject)
        // The write is still on the phone and still readable, which is the whole
        // of ADR 0005 whether or not there is anywhere to send it.
        #expect(food.logs(on: Self.noon, calendar: .current).count == 1)
    }
}
