import Foundation
import SwiftData

/// What the drain should actually do about one unit of work.
enum SyncAction: Equatable {
    case upsert(SyncRow)
    case delete(from: SyncTable, id: UUID)
    /// Nothing, and the queue entry can go.
    case nothing(Vacuous)

    /// Why there is nothing to say. Each of these is a normal outcome rather
    /// than a failure, and each is logged by its name so a quiet outbox can be
    /// explained afterwards.
    enum Vacuous: String, Equatable {
        /// The row is not in the local store any more. It was created and
        /// deleted before either reached the server, or its parent was deleted
        /// and took it with it — a `PhotoEstimate` cascades off its `FoodLog`
        /// locally exactly as it does in Postgres. Either way the queued insert
        /// describes something that does not exist, and sending it would create
        /// a row on the server that the phone has already forgotten.
        case rowIsGone
        /// §2.3. A correction made inside the 48-hour window that did not reach
        /// the server before it closed. `food_logs_update_before_lock` will
        /// refuse it, and it is right to: the rule bounds the window in which a
        /// last-write-wins conflict is possible at all (ADR 0005), and the
        /// price of that is an edit this late being dropped. Dropped
        /// deliberately and in the log, rather than by five refusals and a
        /// parked row that looks like a bug.
        case editWindowClosed
        /// A catalogue row, which belongs to nobody and is not ours to push.
        /// `SwiftDataFoodRepository` already declines to enqueue these; this
        /// catches one queued by an older build.
        case notOurs
        /// A queued table name this build does not know. Left in the queue and
        /// counted, never deleted — see `SyncService`.
        case unknownTable
    }
}

/// The drain's window onto the local store.
///
/// Deliberately not a repository in `Repositories`: nothing above the sync
/// layer has any business reading the outbox, and adding a fifth protocol to
/// the injectable struct would offer every ViewModel a queue it must not touch.
///
/// **This type never deletes anything but an outbox entry.** That is the rule
/// the 21-day clock turns into a requirement: the drain's job is to copy the
/// phone's truth to the server, and a sync service that can remove a logged day
/// is one bad response away from costing three weeks. `SyncTests` asserts it.
@MainActor
struct SyncStore {
    let context: ModelContext
    let userID: UUID
    /// Injected, because two of the six tables carry a *day* rather than an
    /// instant and a day is a property of the user's calendar.
    var calendar: Calendar = .current

    /// Everything queued for this user, oldest first.
    func pending() -> [PendingWrite] {
        let id = userID
        let descriptor = FetchDescriptor<OutboxEntry>(
            predicate: #Predicate { $0.userID == id },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.compactMap(\.pending)
    }

    /// Entries whose table this build cannot map. Counted as stuck rather than
    /// discarded — an unreadable note is still a record that something was
    /// written, and deleting it would be the sync layer quietly deciding a row
    /// does not matter.
    func unmappable() -> [OutboxEntry] {
        let id = userID
        let descriptor = FetchDescriptor<OutboxEntry>(predicate: #Predicate { $0.userID == id })
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.pending == nil }
    }

    func action(for unit: SyncUnit, at moment: Date) -> SyncAction {
        if unit.operation == .delete {
            return .delete(from: unit.table, id: unit.entityID)
        }

        switch unit.table {
        case .profiles:
            guard let profile = profile(unit.entityID) else { return .nothing(.rowIsGone) }
            return .upsert(SyncPayload.row(for: profile, calendar: calendar))

        case .foods:
            guard let food = food(unit.entityID) else { return .nothing(.rowIsGone) }
            guard let row = SyncPayload.row(for: food) else { return .nothing(.notOurs) }
            return .upsert(row)

        case .foodLogs:
            guard let log = foodLog(unit.entityID) else { return .nothing(.rowIsGone) }
            // An insert is never refused for lateness — `food_logs_insert` has
            // no lock clause, and it must not: a week logged with the radio off
            // has to arrive whole however late it is. Only a *correction* to a
            // row the server already holds runs into the closed window.
            if unit.operation == .update, !log.isEditable(at: moment) {
                return .nothing(.editWindowClosed)
            }
            return .upsert(SyncPayload.row(for: log))

        case .photoEstimates:
            guard let estimate = photoEstimate(unit.entityID) else { return .nothing(.rowIsGone) }
            guard let row = SyncPayload.row(for: estimate) else { return .nothing(.rowIsGone) }
            return .upsert(row)

        case .weightLogs:
            guard let weight = weightLog(unit.entityID) else { return .nothing(.rowIsGone) }
            return .upsert(SyncPayload.row(for: weight))

        case .healthSamples:
            guard let sample = healthSample(unit.entityID) else { return .nothing(.rowIsGone) }
            return .upsert(SyncPayload.row(for: sample, calendar: calendar))
        }
    }

    /// The queue entries this unit stood for, gone. Called only after the write
    /// landed — or after it turned out there was nothing to write.
    func discard(_ entryIDs: [UUID]) {
        for entry in entries(entryIDs) { context.delete(entry) }
        save()
    }

    /// One more refusal against every entry in the unit.
    ///
    /// All of them rather than the newest, because they are discarded together
    /// and `OutboxDrain` reads the group's highest count. Recording it on one
    /// would let a corrected row retry forever behind an entry that never
    /// ages.
    func recordAttempt(on entryIDs: [UUID]) {
        for entry in entries(entryIDs) { entry.attempts += 1 }
        save()
    }

    /// Every parked entry, back in the queue.
    ///
    /// Zero rather than a decrement, because the button that calls this says
    /// "try these again" and one more go at a row that has been refused five
    /// times is not what the person meant. The count is a record of how the
    /// server answered, not a budget, so resetting it is honest: the user has
    /// asked for a fresh set of answers.
    func revive() {
        let id = userID
        let descriptor = FetchDescriptor<OutboxEntry>(predicate: #Predicate { $0.userID == id })
        for entry in (try? context.fetch(descriptor)) ?? [] where entry.attempts > 0 {
            entry.attempts = 0
        }
        save()
    }

    private func entries(_ ids: [UUID]) -> [OutboxEntry] {
        let wanted = Set(ids)
        let descriptor = FetchDescriptor<OutboxEntry>()
        return ((try? context.fetch(descriptor)) ?? []).filter { wanted.contains($0.id) }
    }

    /// A save that cannot take the app down.
    ///
    /// Everywhere else in this app a failed save is a bug to fix rather than to
    /// paper over, and the repositories throw. Here it is different in kind:
    /// the write the user made already landed, this is bookkeeping about
    /// whether a *copy* of it landed, and throwing out of a background drain
    /// would turn a failed housekeeping save into a crash mid-log. The entry
    /// stays queued and the next drain tries again, which is exactly what an
    /// outbox is for.
    private func save() {
        do {
            try context.save()
        } catch {
            Log.data.error("Outbox bookkeeping did not save: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - One row, by id

    private func profile(_ id: UUID) -> Profile? {
        first(FetchDescriptor<Profile>(predicate: #Predicate { $0.id == id }))
    }

    private func food(_ id: UUID) -> Food? {
        first(FetchDescriptor<Food>(predicate: #Predicate { $0.id == id }))
    }

    private func foodLog(_ id: UUID) -> FoodLog? {
        first(FetchDescriptor<FoodLog>(predicate: #Predicate { $0.id == id }))
    }

    private func photoEstimate(_ id: UUID) -> PhotoEstimate? {
        first(FetchDescriptor<PhotoEstimate>(predicate: #Predicate { $0.id == id }))
    }

    private func weightLog(_ id: UUID) -> WeightLog? {
        first(FetchDescriptor<WeightLog>(predicate: #Predicate { $0.id == id }))
    }

    private func healthSample(_ id: UUID) -> HealthSample? {
        first(FetchDescriptor<HealthSample>(predicate: #Predicate { $0.id == id }))
    }

    private func first<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> T? {
        var descriptor = descriptor
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}

extension OutboxEntry {
    /// The queued note as the planner sees it, or nil when this build has no
    /// table of that name.
    ///
    /// The nil case is the reason `tableName` is a `String` on the model rather
    /// than an enum: a stored enum turns an unrecognised value into a decode
    /// failure at fetch time, which would take the whole queue down instead of
    /// one row of it.
    var pending: PendingWrite? {
        guard let table = SyncTable(rawValue: tableName) else { return nil }
        return PendingWrite(
            entryID: id,
            table: table,
            entityID: entityID,
            operation: operation,
            createdAt: createdAt,
            attempts: attempts
        )
    }
}
