import Foundation
import SwiftData
import Testing
@testable import Ninety

/// The parts of P1-I that are rules rather than round trips.
///
/// Everything here is pure. `OutboxDrain` decides what a queue means and in
/// what order, `SyncPayload` decides what a row looks like on the wire, and
/// neither needs a store or a socket to be wrong — which is the same argument
/// `WeightTrend` is built on and the reason both were written as values.
@MainActor
@Suite("Sync · the plan and the payload")
struct SyncPlanTests {
    private static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private static func write(
        _ table: SyncTable,
        _ operation: OutboxOperation,
        entity: UUID,
        after seconds: TimeInterval = 0,
        attempts: Int = 0
    ) -> PendingWrite {
        PendingWrite(
            entryID: UUID(),
            table: table,
            entityID: entity,
            operation: operation,
            createdAt: t0.addingTimeInterval(seconds),
            attempts: attempts
        )
    }

    // MARK: - What a sequence means

    @Test("a row created and then corrected offline is still an insert")
    func editingAnUnsentRowStaysAnInsert() {
        // The one that matters. If this collapsed to an update, the drain would
        // patch a row the server has never seen — and a PATCH matching nothing
        // succeeds quietly, so the meal would be missing from the server while
        // the phone showed it perfectly.
        #expect(OutboxDrain.coalesce([.insert, .update]) == .insert)
        #expect(OutboxDrain.coalesce([.insert, .update, .update]) == .insert)
    }

    @Test("a trailing delete beats everything queued before it")
    func deleteWins() {
        #expect(OutboxDrain.coalesce([.insert, .delete]) == .delete)
        #expect(OutboxDrain.coalesce([.update, .delete]) == .delete)
        #expect(OutboxDrain.coalesce([.insert, .update, .delete]) == .delete)
    }

    @Test("corrections to a row already on the server stay an update")
    func updatesStayUpdates() {
        #expect(OutboxDrain.coalesce([.update]) == .update)
        #expect(OutboxDrain.coalesce([.update, .update]) == .update)
    }

    @Test("three corrections to one meal are one write, carrying all three entries")
    func oneRowIsOneUnit() {
        let meal = UUID()
        let plan = OutboxDrain.plan([
            Self.write(.foodLogs, .insert, entity: meal),
            Self.write(.foodLogs, .update, entity: meal, after: 60),
            Self.write(.foodLogs, .update, entity: meal, after: 120),
        ])

        #expect(plan.work.count == 1)
        #expect(plan.work.first?.operation == .insert)
        // Discarded together, so a partial success cannot leave one of three
        // behind to be replayed on its own.
        #expect(plan.work.first?.entryIDs.count == 3)
        #expect(plan.work.first?.queuedAt == Self.t0)
    }

    // MARK: - Order

    @Test("a custom food goes up before the log that references it")
    func upsertsFollowTheForeignKeys() {
        // Queued in the order the user did them, which is the wrong order to
        // send them in: `food_logs.food_id` references `foods`, and
        // `photo_estimates.log_id` references `food_logs`.
        let plan = OutboxDrain.plan([
            Self.write(.photoEstimates, .insert, entity: UUID(), after: 3),
            Self.write(.foodLogs, .insert, entity: UUID(), after: 2),
            Self.write(.foods, .insert, entity: UUID(), after: 1),
            Self.write(.profiles, .update, entity: UUID(), after: 4),
        ])

        #expect(plan.work.map(\.table) == [.profiles, .foods, .foodLogs, .photoEstimates])
    }

    @Test("deletes go in the reverse of that order")
    func deletesUnwind() {
        let plan = OutboxDrain.plan([
            Self.write(.foods, .delete, entity: UUID(), after: 1),
            Self.write(.photoEstimates, .delete, entity: UUID(), after: 2),
            Self.write(.foodLogs, .delete, entity: UUID(), after: 3),
        ])

        #expect(plan.work.map(\.table) == [.photoEstimates, .foodLogs, .foods])
    }

    @Test("everything that creates goes before anything that removes")
    func upsertsPrecedeDeletes() {
        let plan = OutboxDrain.plan([
            Self.write(.foodLogs, .delete, entity: UUID(), after: 1),
            Self.write(.weightLogs, .insert, entity: UUID(), after: 2),
        ])

        #expect(plan.work.map(\.operation) == [.insert, .delete])
    }

    @Test("rows drain oldest first inside a table")
    func oldestFirst() {
        let first = UUID()
        let second = UUID()
        let plan = OutboxDrain.plan([
            Self.write(.foodLogs, .insert, entity: second, after: 90),
            Self.write(.foodLogs, .insert, entity: first, after: 10),
        ])

        #expect(plan.work.map(\.entityID) == [first, second])
    }

    // MARK: - Parking

    @Test("a row refused five times is parked, not worked")
    func fiveRefusalsPark() {
        let refused = UUID()
        let fine = UUID()
        let plan = OutboxDrain.plan([
            Self.write(.foodLogs, .insert, entity: refused, attempts: OutboxDrain.maxAttempts),
            Self.write(.foodLogs, .insert, entity: fine, after: 1, attempts: 4),
        ])

        #expect(plan.work.map(\.entityID) == [fine])
        #expect(plan.parked.map(\.entityID) == [refused])
    }

    @Test("a group takes the highest attempt count in it")
    func attemptsAreTheGroupsHighest() {
        let meal = UUID()
        let plan = OutboxDrain.plan([
            Self.write(.foodLogs, .insert, entity: meal, attempts: 5),
            Self.write(.foodLogs, .update, entity: meal, after: 1, attempts: 0),
        ])

        // Otherwise a corrected row would retry forever behind an entry that
        // never ages.
        #expect(plan.work.isEmpty)
        #expect(plan.parked.count == 1)
    }

    @Test("backoff doubles from two seconds and stops at five minutes")
    func backoffHasACeiling() {
        #expect(SyncBackoff.delay(afterConsecutiveFailures: 0) == 0)
        #expect(SyncBackoff.delay(afterConsecutiveFailures: 1) == 2)
        #expect(SyncBackoff.delay(afterConsecutiveFailures: 4) == 16)
        #expect(SyncBackoff.delay(afterConsecutiveFailures: 20) == SyncBackoff.ceiling)
    }

    @Test("only a refusal of this row is the row's fault")
    func failuresAreSplitByWhoseFaultTheyAre() {
        // The whole retry policy, and the reason a week logged on a plane does
        // not land already parked.
        #expect(SyncFailure.offline.isAboutTheConnection)
        #expect(SyncFailure.notSignedIn.isAboutTheConnection)
        #expect(SyncFailure.unavailable.isAboutTheConnection)
        #expect(!SyncFailure.refused(status: 409).isAboutTheConnection)
    }

    // MARK: - The row on the wire

    @Test("a food log carries Postgres column names, and neither derived column")
    func foodLogColumns() {
        let user = UUID()
        let log = FoodLog(
            userID: user,
            createdAt: Self.t0,
            updatedAt: Self.t0,
            loggedAt: Self.t0,
            grams: 250,
            entryMethod: .manual,
            kcal: 450,
            nameSnapshot: "Chicken salad bowl"
        )
        let row = SyncPayload.row(for: log)

        #expect(row.table == .foodLogs)
        #expect(row.columns["name_snapshot"] == .text("Chicken salad bowl"))
        #expect(row.columns["entry_method"] == .text("manual"))
        // ADR 0005 resolves conflicts by SERVER timestamp, and migration 001 is
        // emphatic about the word: a client-supplied one could be forged.
        #expect(row.columns["updated_at"] == nil)
        // §2.3's window is derived by trigger from `logged_at`, so the client
        // cannot move it.
        #expect(row.columns["locked_at"] == nil)
    }

    @Test("a health sample never carries the HealthKit anchor")
    func anchorsStayOnTheirDevice() {
        let sample = HealthSample(
            userID: UUID(),
            createdAt: Self.t0,
            day: Self.t0,
            steps: 8_412,
            anchor: Data("an anchor".utf8)
        )
        let row = SyncPayload.row(for: sample, calendar: .current)

        // An anchor describes what one device has already read. Handing it to a
        // second phone would tell that phone it had read a history it has never
        // seen — the exact failure §1.4 calls "the entire trick" for avoiding.
        #expect(row.columns["hk_anchor"] == nil)
        #expect(row.columns["steps"] == .integer(8_412))
    }

    @Test("a catalogue food is not ours to push")
    func onlyCustomFoodsSync() {
        let mirrored = Food(source: .off, name: "Baked beans", kcalPer100g: 78)
        #expect(SyncPayload.row(for: mirrored) == nil)

        let own = Food(source: .custom, createdBy: UUID(), name: "Dad's chilli", kcalPer100g: 140)
        #expect(SyncPayload.row(for: own)?.columns["source"] == .text("custom"))
    }

    @Test("the model's output reaches the wire exactly as it arrived")
    func modelOutputIsVerbatim() throws {
        // ADR 0010: re-scoring a stored estimate against a new prompt is only
        // possible if the original survived. Re-encoding it would leave the
        // benchmark scoring the app's idea of the answer.
        let verbatim = Data(#"{"items":[{"name":"Porridge","kcal":[290,390]}],"confidence":0.62}"#.utf8)
        // Registered in a context, because reading `estimate.log` is a
        // relationship access and a relationship is the one thing a `@Model`
        // does not obviously own on its own.
        let context = ModelContext(try ModelContainer.ninety(inMemory: true))
        let user = UUID()
        let log = FoodLog(
            userID: user,
            loggedAt: Self.t0,
            grams: 200,
            entryMethod: .photo,
            kcal: 340,
            nameSnapshot: "Porridge"
        )
        let estimate = PhotoEstimate(
            userID: user,
            createdAt: Self.t0,
            storagePath: "user/meal.jpg",
            modelOutput: verbatim,
            confidence: 0.62,
            log: log
        )
        context.insert(log)
        context.insert(estimate)
        try context.save()

        let row = try #require(SyncPayload.row(for: estimate))
        let body = try #require(String(bytes: row.body, encoding: .utf8))
        let sent = try #require(String(bytes: verbatim, encoding: .utf8))
        #expect(body.contains(sent))
        #expect(row.columns["log_id"] == .text(log.id.uuidString.lowercased()))
    }

    @Test("an estimate whose log has gone is not a row")
    func anEstimateWithoutItsLogIsNothing() throws {
        let context = ModelContext(try ModelContainer.ninety(inMemory: true))
        let orphan = PhotoEstimate(
            userID: UUID(),
            storagePath: "user/meal.jpg",
            modelOutput: Data("{}".utf8)
        )
        context.insert(orphan)
        try context.save()

        // `log_id` is `not null`, and half of ADR 0010's pair scores nothing.
        #expect(SyncPayload.row(for: orphan) == nil)
    }

    @Test("a name with a quote or a newline in it is still valid JSON")
    func stringsAreEscaped() throws {
        let row = SyncRow(
            table: .foods,
            id: UUID(),
            columns: ["name": .text("Sainsbury's \"Taste the Difference\"\nchilli\u{0B}")]
        )
        let decoded = try JSONSerialization.jsonObject(with: row.body) as? [String: Any]
        #expect(decoded?["name"] as? String == "Sainsbury's \"Taste the Difference\"\nchilli\u{0B}")
    }

    @Test("keys are emitted in a fixed order, so a payload is the same twice")
    func bodiesAreDeterministic() {
        let row = SyncRow(
            table: .weightLogs,
            id: UUID(),
            columns: ["kg": .number(78.4), "source": .text("manual"), "id": .null]
        )
        #expect(String(bytes: row.body, encoding: .utf8) == #"{"id":null,"kg":78.4,"source":"manual"}"#)
    }

    @Test("a timestamptz goes up as UTC, to the microsecond")
    func instantsAreUTC() {
        // Pinned, because this is hand-rolled now: `ISO8601DateFormatter` is a
        // class and not `Sendable`, so a shared one is exactly the static
        // property `SWIFT_STRICT_CONCURRENCY = complete` refuses.
        let moment = Date(timeIntervalSince1970: 1_800_050_400)
        #expect(SyncTime.instant(moment) == "2027-01-15T22:00:00.000000Z")
    }

    @Test("the instant is fixed width whatever the fraction is")
    func instantsAreFixedWidth() {
        let odd = Date(timeIntervalSince1970: 1_800_050_400.123_456)
        let text = SyncTime.instant(odd)

        // A ragged fraction is still valid ISO 8601, but a fixed width is what
        // makes a payload comparable against a literal — and an unpadded
        // microsecond field would silently mean a different instant.
        #expect(text.count == "2027-01-15T22:00:00.000000Z".count)
        #expect(text.hasPrefix("2027-01-15T22:00:00."))
        #expect(text.hasSuffix("Z"))
    }

    @Test("a day is the day in the user's own calendar, not the day in UTC")
    func daysAreLocal() throws {
        // 22:00 UTC on 15 January 2027, which is already the 16th in Auckland.
        // Both `profiles.dob` and `health_samples.date` are Postgres `date`
        // columns, and §10 S4 computes the age gate from an actual date —
        // someone turning 18 tomorrow is 17 today, and re-deriving a day in UTC
        // from a local midnight is the wrong day for half the year.
        let evening = Date(timeIntervalSince1970: 1_800_050_400)
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))

        #expect(SyncTime.day(evening, calendar: auckland) == "2027-01-16")
        #expect(SyncTime.day(evening, calendar: utc) == "2027-01-15")
    }

    @Test("the two natural keys are the two tables a reinstall collides on")
    func conflictTargets() {
        #expect(SyncTable.weightLogs.conflictTarget == "user_id,measured_at,source")
        #expect(SyncTable.healthSamples.conflictTarget == "user_id,date")
        #expect(SyncTable.foodLogs.conflictTarget == nil)
    }
}
