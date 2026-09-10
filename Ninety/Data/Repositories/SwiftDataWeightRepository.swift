import Foundation
import SwiftData

/// Weight, in the local store.
///
/// **Its own file, because P1-G is what pushed `SwiftDataRepositories.swift` past
/// the 400-line limit** — and of the four repositories in there this is the one
/// that grew, from three methods to five plus a shared insert. Splitting the one
/// that changed is the honest version of clearing the violation; trimming a
/// comment until the number came down would have been the other one.
///
/// `Outbox` stays where it is. Every repository enqueues through it, so it
/// belongs beside all four rather than beside whichever moved out.

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
