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
    func enqueue(_ operation: OutboxOperation, entity: String, id: UUID, at moment: Date) {
        context.insert(
            OutboxEntry(
                userID: userID,
                createdAt: moment,
                entity: entity,
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
            .enqueue(.update, entity: "profiles", id: profile.id, at: now)
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

    @discardableResult
    func log(
        food: Food?,
        grams: Double,
        kcal: Double,
        name: String,
        entryMethod: EntryMethod,
        at loggedAt: Date
    ) throws -> FoodLog {
        let now = Date()
        let entry = FoodLog(
            userID: userID,
            createdAt: now,
            updatedAt: now,
            loggedAt: loggedAt,
            grams: grams,
            entryMethod: entryMethod,
            kcal: kcal,
            nameSnapshot: name,
            food: food
        )
        context.insert(entry)
        Outbox(context: context, userID: userID)
            .enqueue(.insert, entity: "food_logs", id: entry.id, at: now)
        try context.save()
        return entry
    }

    func update(_ log: FoodLog, grams: Double, kcal: Double, at moment: Date) throws {
        guard log.isEditable(at: moment) else { throw RepositoryError.logIsLocked(since: log.locksAt) }
        log.grams = grams
        log.kcal = kcal
        log.updatedAt = moment
        Outbox(context: context, userID: userID)
            .enqueue(.update, entity: "food_logs", id: log.id, at: moment)
        try context.save()
    }

    func delete(_ log: FoodLog, at moment: Date) throws {
        guard log.isEditable(at: moment) else { throw RepositoryError.logIsLocked(since: log.locksAt) }
        let id = log.id
        context.delete(log)
        Outbox(context: context, userID: userID)
            .enqueue(.delete, entity: "food_logs", id: id, at: moment)
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

    @discardableResult
    func record(kg: Double, at measuredAt: Date, source: WeightSource) throws -> WeightLog {
        let now = Date()
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
            .enqueue(.insert, entity: "weight_logs", id: entry.id, at: now)
        try context.save()
        return entry
    }

    func delete(_ log: WeightLog) throws {
        let now = Date()
        let id = log.id
        context.delete(log)
        Outbox(context: context, userID: userID)
            .enqueue(.delete, entity: "weight_logs", id: id, at: now)
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
            .enqueue(existing == nil ? .insert : .update, entity: "health_samples", id: sample.id, at: now)
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
