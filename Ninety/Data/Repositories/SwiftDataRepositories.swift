import Foundation
import SwiftData

/// The real implementations, over SwiftData.
///
/// Every write does the same three things in the same order: mutate the local
/// store, enqueue an outbox entry, save. The save is synchronous and local, so
/// the caller is unblocked before anything has been said to the network —
/// which is the whole of ADR 0005 in one sentence.

/// Shared plumbing. Not a base class: these are structs, and inheritance would
/// buy nothing that a stored `Outbox` does not.
@MainActor
struct Outbox {
    let context: ModelContext
    let userID: UUID

    /// Records that something changed, for the sync service to drain later.
    ///
    /// The payload is deliberately not the whole row. The sync service reads
    /// the current object by id when it runs, so a row edited three times
    /// offline syncs once, in its final state, rather than replaying three
    /// versions at the server in an order that last-write-wins would then have
    /// to arbitrate.
    func enqueue(_ operation: OutboxOperation, tableName: String, id: UUID, at moment: Date) {
        context.insert(
            OutboxEntry(
                userID: userID,
                createdAt: moment,
                tableName: tableName,
                entityID: id,
                operation: operation,
                payload: Data("{}".utf8)
            )
        )
    }
}

// MARK: - Profile

@MainActor
struct SwiftDataProfileRepository: ProfileRepositoryProtocol {
    let context: ModelContext
    let userID: UUID

    func current() -> Profile? {
        let id = userID
        var descriptor = FetchDescriptor<Profile>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func save(_ profile: Profile) throws -> Profile {
        let now = Date()
        profile.updatedAt = now
        if current() == nil {
            profile.createdAt = now
            context.insert(profile)
        }
        Outbox(context: context, userID: userID)
            .enqueue(.update, tableName: "profiles", id: profile.id, at: now)
        try context.save()
        return profile
    }

    func isCompetitiveOptOutEnabled() -> Bool {
        current()?.competitiveOptOut ?? false
    }
}

// MARK: - Food

@MainActor
struct SwiftDataFoodRepository: FoodRepositoryProtocol {
    let context: ModelContext
    let userID: UUID

    func logs(on day: Date, calendar: Calendar) -> [FoodLog] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let id = userID
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.userID == id && $0.loggedAt >= start && $0.loggedAt < end },
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func foods(matching query: String, limit: Int) -> [Food] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var descriptor = FetchDescriptor<Food>(
            predicate: #Predicate { $0.name.localizedStandardContains(trimmed) },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func food(withBarcode barcode: String) -> Food? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Typed as the optional the column is, rather than relying on the
        // predicate macro promoting a `String` to `String?` inside a generated
        // expression. Explicit is cheaper than finding out at runtime that a
        // comparison never matched.
        let target: String? = trimmed
        var descriptor = FetchDescriptor<Food>(predicate: #Predicate { $0.barcode == target })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func saveFood(_ draft: FoodDraft) throws -> Food {
        let now = Date()
        let existing = draft.id.flatMap(food(withID:))
        let food = existing ?? Food(
            id: draft.id ?? UUID(),
            createdAt: now,
            source: draft.source,
            // Ownership follows the source, and the check constraint in
            // migration 001 says the same thing: a custom food has an owner and
            // a catalogue row has none. Setting `created_by` on a cached Open
            // Food Facts row would make the insert policy reject it as a custom
            // food somebody else already owns.
            createdBy: draft.source == .custom ? userID : nil,
            name: draft.name,
            kcalPer100g: draft.kcalPer100g
        )

        food.barcode = draft.barcode
        food.name = draft.name
        food.brand = draft.brand
        food.kcalPer100g = draft.kcalPer100g
        food.proteinG = draft.proteinG
        food.carbsG = draft.carbsG
        food.fatG = draft.fatG
        food.updatedAt = now
        if existing == nil { context.insert(food) }

        // Only a custom food is ever pushed. A cached catalogue row is a local
        // copy of something the server already has, and syncing it back would
        // be the client trying to write a row its own RLS policy refuses.
        if draft.source == .custom {
            Outbox(context: context, userID: userID)
                .enqueue(existing == nil ? .insert : .update, tableName: "foods", id: food.id, at: now)
        }
        try context.save()
        return food
    }

    func recentLogs(since moment: Date, limit: Int) -> [FoodLog] {
        let id = userID
        var descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.userID == id && $0.loggedAt >= moment },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func log(_ draft: FoodLogDraft) throws -> FoodLog {
        try write(draft, estimate: nil)
    }

    @discardableResult
    func log(_ draft: FoodLogDraft, estimate: PhotoEstimateDraft) throws -> FoodLog {
        try write(draft, estimate: estimate)
    }

    func photoEstimates(limit: Int) -> [PhotoEstimate] {
        let id = userID
        var descriptor = FetchDescriptor<PhotoEstimate>(
            predicate: #Predicate { $0.userID == id },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The one write path, so the estimate cannot land without its log or the
    /// log without its estimate. Both objects are inserted before the single
    /// `save`, which is what makes the pair atomic rather than merely adjacent.
    private func write(_ draft: FoodLogDraft, estimate: PhotoEstimateDraft?) throws -> FoodLog {
        let now = Date()
        let entry = FoodLog(
            userID: userID,
            createdAt: now,
            updatedAt: now,
            loggedAt: draft.loggedAt,
            grams: draft.grams,
            entryMethod: draft.entryMethod,
            kcal: draft.kcal,
            nameSnapshot: draft.name,
            food: draft.food
        )
        context.insert(entry)
        let outbox = Outbox(context: context, userID: userID)
        outbox.enqueue(.insert, tableName: "food_logs", id: entry.id, at: now)

        if let estimate {
            let record = PhotoEstimate(
                userID: userID,
                createdAt: now,
                updatedAt: now,
                storagePath: estimate.storagePath,
                modelOutput: estimate.modelOutput,
                confidence: estimate.confidence,
                wasCorrected: estimate.wasCorrected,
                correctionDelta: estimate.correctionDelta,
                log: entry
            )
            context.insert(record)
            outbox.enqueue(.insert, tableName: "photo_estimates", id: record.id, at: now)
        }

        try context.save()
        return entry
    }

    private func food(withID id: UUID) -> Food? {
        var descriptor = FetchDescriptor<Food>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func update(_ log: FoodLog, grams: Double, kcal: Double, at moment: Date) throws {
        guard log.isEditable(at: moment) else { throw RepositoryError.logIsLocked(since: log.locksAt) }
        log.grams = grams
        log.kcal = kcal
        log.updatedAt = moment
        Outbox(context: context, userID: userID)
            .enqueue(.update, tableName: "food_logs", id: log.id, at: moment)
        try context.save()
    }

    func delete(_ log: FoodLog, at moment: Date) throws {
        guard log.isEditable(at: moment) else { throw RepositoryError.logIsLocked(since: log.locksAt) }
        let id = log.id
        context.delete(log)
        Outbox(context: context, userID: userID)
            .enqueue(.delete, tableName: "food_logs", id: id, at: moment)
        try context.save()
    }
}

// MARK: - Weight

@MainActor
struct SwiftDataWeightRepository: WeightRepositoryProtocol {
    let context: ModelContext
    let userID: UUID

    func recent(limit: Int) -> [WeightLog] {
        let id = userID
        var descriptor = FetchDescriptor<WeightLog>(
            predicate: #Predicate { $0.userID == id },
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func readings(since moment: Date) -> [WeightLog] {
        let id = userID
        let descriptor = FetchDescriptor<WeightLog>(
            predicate: #Predicate { $0.userID == id && $0.measuredAt >= moment },
            sortBy: [SortDescriptor(\.measuredAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func record(kg: Double, at measuredAt: Date, source: WeightSource) throws -> WeightLog {
        let now = Date()
        let entry = insert(kg: kg, at: measuredAt, source: source, now: now)
        try context.save()
        return entry
    }

    /// Reads what is already held, asks the rule which of the incoming readings
    /// are new, and writes those — in one save.
    ///
    /// The window is the whole store rather than the sync's own window: a
    /// duplicate is a duplicate whenever it was first recorded, and the day the
    /// user syncs a scale for the first time is exactly the day the store
    /// already holds the readings they typed by hand.
    @discardableResult
    func importReadings(_ readings: [BodyMassReading], calendar: Calendar) throws -> [WeightLog] {
        let existing = self.readings(since: .distantPast).map(\.weighIn)
        let unseen = WeightReconciliation.unseen(readings, against: existing, calendar: calendar)
        guard !unseen.isEmpty else { return [] }

        let now = Date()
        let written = unseen.map {
            insert(kg: $0.kg, at: $0.measuredAt, source: .healthkit, now: now)
        }
        // One save for the batch. A save per reading on a first sync of a year
        // of a smart scale's output is three hundred round trips through the
        // store for one user action.
        try context.save()
        return written
    }

    /// The insert and its outbox entry, without the save. Shared so a single
    /// write and a batch cannot drift into enqueuing differently.
    private func insert(kg: Double, at measuredAt: Date, source: WeightSource, now: Date) -> WeightLog {
        let entry = WeightLog(
            userID: userID,
            createdAt: now,
            updatedAt: now,
            measuredAt: measuredAt,
            kg: kg,
            source: source
        )
        context.insert(entry)
        Outbox(context: context, userID: userID)
            .enqueue(.insert, tableName: "weight_logs", id: entry.id, at: now)
        return entry
    }

    func delete(_ log: WeightLog) throws {
        let now = Date()
        let id = log.id
        context.delete(log)
        Outbox(context: context, userID: userID)
            .enqueue(.delete, tableName: "weight_logs", id: id, at: now)
        try context.save()
    }
}

// MARK: - Health

@MainActor
struct SwiftDataHealthRepository: HealthRepositoryProtocol {
    let context: ModelContext
    let userID: UUID

    func samples(from start: Date, to end: Date) -> [HealthSample] {
        let id = userID
        let descriptor = FetchDescriptor<HealthSample>(
            predicate: #Predicate { $0.userID == id && $0.day >= start && $0.day <= end },
            sortBy: [SortDescriptor(\.day)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Upsert by day, because a day is re-read every time HealthKit reports a
    /// change and a second row for the same date would double-count it.
    @discardableResult
    func upsert(
        day: Date,
        steps: Int?,
        activeEnergy: Double?,
        exerciseMinutes: Int?,
        workoutCount: Int
    ) throws -> HealthSample {
        let now = Date()
        let existing = samples(from: day, to: day).first
        let sample = existing ?? HealthSample(userID: userID, createdAt: now, day: day)

        sample.steps = steps
        sample.activeEnergy = activeEnergy
        sample.exerciseMinutes = exerciseMinutes
        sample.workoutCount = workoutCount
        sample.updatedAt = now
        if existing == nil { context.insert(sample) }

        Outbox(context: context, userID: userID)
            .enqueue(existing == nil ? .insert : .update, tableName: "health_samples", id: sample.id, at: now)
        try context.save()
        return sample
    }

    /// The most recent anchor written, from any day's row.
    func anchor() -> Data? {
        let id = userID
        var descriptor = FetchDescriptor<HealthSample>(
            predicate: #Predicate { $0.userID == id && $0.anchor != nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.anchor
    }

    func saveAnchor(_ anchor: Data) throws {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let sample = samples(from: today, to: today).first
            ?? {
                let fresh = HealthSample(userID: userID, createdAt: now, day: today)
                context.insert(fresh)
                return fresh
            }()
        sample.anchor = anchor
        sample.updatedAt = now
        try context.save()
    }
}
