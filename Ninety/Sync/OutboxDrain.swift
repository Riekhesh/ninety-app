import Foundation

/// One queued note, as a value.
///
/// `OutboxEntry` is a `@Model`, and the planning below is a rule rather than a
/// query — which order, which operation, what has run out of retries. A rule
/// that needs a store to test is a rule nobody tests, which is the same
/// argument `WeightTrend` and `WeightReconciliation` are already built on.
struct PendingWrite: Equatable, Sendable {
    let entryID: UUID
    let table: SyncTable
    let entityID: UUID
    let operation: OutboxOperation
    let createdAt: Date
    let attempts: Int
}

/// One row's worth of work, whatever it took to get there.
///
/// A row logged, corrected and corrected again offline is three outbox entries
/// and **one** of these. `Outbox.enqueue` already promised this in its doc
/// comment — the payload is deliberately not the whole row, because the sync
/// service reads the current object by id when it runs — and this is where the
/// promise is kept.
struct SyncUnit: Equatable, Sendable {
    let table: SyncTable
    let entityID: UUID
    /// What the sequence adds up to. See `OutboxDrain.coalesce`.
    let operation: OutboxOperation
    /// Every entry this stands for. They are discarded together, so a partial
    /// success cannot leave one of three behind to be replayed on its own.
    let entryIDs: [UUID]
    /// The highest attempt count in the group.
    let attempts: Int
    /// When the earliest of them was queued. The drain order within a table.
    let queuedAt: Date
}

/// What one drain should do, in the order it should do it.
struct DrainPlan: Equatable, Sendable {
    let work: [SyncUnit]
    /// Rows that have been rejected too many times to keep trying. Kept, never
    /// deleted, and counted where the user can see the number — `OutboxEntry`
    /// says why the column exists at all: "so a row that fails forever can be
    /// found rather than retried silently until the end of time".
    let parked: [SyncUnit]
}

/// The drain's policy, with nothing in it that touches a store or a socket.
enum OutboxDrain {
    /// Five, and then it stops asking.
    ///
    /// Only a rejection of *this row* ever counts — see `SyncService`, where a
    /// failure that is not the row's fault costs no attempts at all. Five
    /// genuine refusals is a row the server will not take in its current shape,
    /// and the sixth request would only be the same request.
    static let maxAttempts = 5

    static func plan(_ pending: [PendingWrite], maxAttempts: Int = OutboxDrain.maxAttempts) -> DrainPlan {
        let units = grouped(pending)
        let live = units.filter { $0.attempts < maxAttempts }
        let parked = units.filter { $0.attempts >= maxAttempts }

        // Upserts in dependency order, then deletes in the reverse of it.
        //
        // The reversal is not decoration. `photo_estimates` references
        // `food_logs` and `food_logs` references `foods`, so a batch that
        // creates a food and a log has to send them in that order or the second
        // insert violates a foreign key — and a batch that removes them has to
        // do the opposite. Ties inside a rank drain oldest-first, which is the
        // order the user did them in.
        let upserts = live
            .filter { $0.operation != .delete }
            .sorted(by: ordered(by: { $0.table.rank }))
        let deletes = live
            .filter { $0.operation == .delete }
            .sorted(by: ordered(by: { -$0.table.rank }))

        return DrainPlan(
            work: upserts + deletes,
            parked: parked.sorted(by: ordered(by: { $0.table.rank }))
        )
    }

    /// Group by the row, then decide what the sequence meant.
    private static func grouped(_ pending: [PendingWrite]) -> [SyncUnit] {
        var buckets: [Key: [PendingWrite]] = [:]
        for write in pending {
            buckets[Key(table: write.table, entityID: write.entityID), default: []].append(write)
        }

        return buckets.map { key, writes in
            let ordered = writes.sorted { left, right in
                left.createdAt == right.createdAt
                    ? left.entryID.uuidString < right.entryID.uuidString
                    : left.createdAt < right.createdAt
            }
            return SyncUnit(
                table: key.table,
                entityID: key.entityID,
                operation: coalesce(ordered.map(\.operation)),
                entryIDs: ordered.map(\.entryID),
                attempts: ordered.map(\.attempts).max() ?? 0,
                queuedAt: ordered.first?.createdAt ?? .distantPast
            )
        }
    }

    /// What a sequence of operations on one row adds up to.
    ///
    /// Three cases, and the middle one is the one that matters. A row created
    /// and then edited offline is **an insert**, not an update: if it collapsed
    /// to an update, the row would be patched at a server that has never seen
    /// it, and a `PATCH` matching nothing succeeds quietly — the whole meal
    /// would be gone from the server while the phone showed it perfectly. So
    /// any insert in the sequence wins, and the send is an upsert that is
    /// correct whether the row is there or not.
    ///
    /// A trailing delete beats everything before it: the row does not exist any
    /// more, and its final state is its absence. Deleting a row the server
    /// never received is a no-op there, which is the right answer rather than a
    /// lucky one.
    static func coalesce(_ operations: [OutboxOperation]) -> OutboxOperation {
        guard let last = operations.last else { return .update }
        if last == .delete { return .delete }
        return operations.contains(.insert) ? .insert : .update
    }

    private static func ordered(
        by rank: @escaping (SyncUnit) -> Int
    ) -> (SyncUnit, SyncUnit) -> Bool {
        { left, right in
            if rank(left) != rank(right) { return rank(left) < rank(right) }
            if left.queuedAt != right.queuedAt { return left.queuedAt < right.queuedAt }
            return left.entityID.uuidString < right.entityID.uuidString
        }
    }

    private struct Key: Hashable {
        let table: SyncTable
        let entityID: UUID
    }
}

/// How long to wait before asking again after the network said no.
///
/// Doubling from two seconds to a five-minute ceiling. The ceiling is the
/// interesting number rather than the ramp: this backs off a *connection*, not
/// a row, and the common cause is a phone in a basement or on a plane. Backing
/// off past five minutes would mean a user who walks back into signal waits
/// longer than they can be bothered to, and the reconnect notification is what
/// actually ends most waits anyway — the timer is only there for the case where
/// the radio never dropped and the server was simply unreachable.
enum SyncBackoff {
    static let first: TimeInterval = 2
    static let ceiling: TimeInterval = 300

    static func delay(afterConsecutiveFailures failures: Int) -> TimeInterval {
        guard failures > 0 else { return 0 }
        let doubled = first * pow(2, Double(failures - 1))
        return min(doubled, ceiling)
    }
}
