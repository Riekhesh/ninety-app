import Foundation
import Observation

/// Drains the outbox, and is the only thing in the app that does.
///
/// ADR 0005 in one object. Every write in Ninety has always landed in SwiftData
/// and returned immediately, and every write has always left a note in
/// `sync_outbox` — since P1-B. What has never existed until now is anything that
/// reads those notes, which is why `RootView` carried a comment saying a
/// reinstall still asks for consent again and why the Phase 1 exit criterion
/// about airplane mode stayed open. This is that half.
///
/// **Four properties, and the clock is why each of them is not negotiable.**
///
/// 1. *It never blocks a write.* Nothing here is on the path between a user
///    tapping "Log it" and the row existing. The drain reads a queue that is
///    already durable.
/// 2. *It never deletes anything but a queue entry.* A sync service that can
///    remove a logged day is one bad response away from costing three weeks.
///    `SyncStore` is written so that it cannot, and `SyncTests` asserts it.
/// 3. *A failure that is not the row's fault costs the row nothing.* A week
///    logged on a plane must not land already parked because it spent five
///    attempts on an aeroplane. Only a refusal of *this row* counts.
/// 4. *It stops asking.* Five refusals and a row is parked, kept, and counted
///    where the user can see the number — never retried silently forever.
///
/// **What this deliberately is not: a restore.** The outbox is a push. Nothing
/// here reads a row back down, so the server copy is a backup that protects the
/// data against a lost phone and does not yet repopulate a new one. Pulling is a
/// different job with a different conflict story — last-write-wins on a device
/// with no rows is indistinguishable from a wipe — and it is not what the
/// exit criterion asks for. `docs/phase-1/README.md` says so where a reader of
/// the tracker will find it.
@MainActor
@Observable
final class SyncService {
    /// Recomputed after every pass. The panel in Settings renders this and
    /// nothing else.
    private(set) var status: SyncStatus = .upToDate(lastSentAt: nil)

    /// Rows the drain has stopped asking about. Separate from `status` because
    /// a day spent underground can have forty changes waiting *and* one parked,
    /// and a single headline cannot say both.
    private(set) var stuckCount = 0

    private let store: SyncStore
    /// Nil on a clone with no Supabase project. The whole app is built to run
    /// without one, and this is the state that says so out loud rather than
    /// queueing forever against nothing.
    private let client: (any SyncWriting)?
    private let connectivity: (any ConnectivityWatching)?
    private let now: () -> Date

    private var isDraining = false
    private var consecutiveFailures = 0
    private var lastSentAt: Date?
    private var watching: Task<Void, Never>?
    private var polling: Task<Void, Never>?
    private var retrying: Task<Void, Never>?

    /// How often a foregrounded app looks at its own queue.
    ///
    /// Not a heartbeat against the network: the tick reads one indexed table and
    /// returns when it is empty. It exists so that a meal logged while the app
    /// is open and online reaches the server without the user having to leave
    /// the app and come back — every other trigger here is an *event*
    /// (reconnect, foreground, launch, a tap), and logging is not one of them.
    static let pollInterval: Duration = .seconds(30)

    init(
        store: SyncStore,
        client: (any SyncWriting)?,
        connectivity: (any ConnectivityWatching)? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.client = client
        self.connectivity = connectivity
        self.now = now
        refreshStatus()
    }

    // MARK: - Lifecycle

    /// Begin watching, and drain once.
    ///
    /// Idempotent: called from the shell's `onAppear`, which runs again on every
    /// return to the tab.
    func start() {
        guard watching == nil, polling == nil else { return }

        if let connectivity {
            watching = Task { [weak self] in
                for await online in connectivity.changes() {
                    // `return` on a gone service, not `continue`: the task holds
                    // self weakly, so a loop that carried on would keep reading a
                    // stream on behalf of nobody.
                    guard let self else { return }
                    guard online else { continue }
                    // A path that has just come back is the event the queue has
                    // been waiting for, so the accumulated backoff is thrown
                    // away rather than served out.
                    consecutiveFailures = 0
                    retrying?.cancel()
                    await drain()
                }
            }
        }

        polling = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: SyncService.pollInterval)
                guard let self, !Task.isCancelled else { return }
                await drain()
            }
        }

        requestDrain()
    }

    func stop() {
        watching?.cancel()
        polling?.cancel()
        retrying?.cancel()
        watching = nil
        polling = nil
        retrying = nil
    }

    /// Drain, without waiting for it. What a view calls.
    func requestDrain() {
        Task { [weak self] in await self?.drain() }
    }

    /// Un-park everything and try once more. The "try these again" button.
    ///
    /// Deliberately a user action rather than something the app does on a timer.
    /// A row that has been refused five times is refused for a reason, and the
    /// honest thing is to say so and let the person decide, not to keep asking
    /// on their behalf and call it resilience.
    func retryStuck() {
        store.revive()
        consecutiveFailures = 0
        requestDrain()
    }

    // MARK: - One pass

    func drain() async {
        guard let client else {
            status = .noProject
            return
        }
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }

        let plan = OutboxDrain.plan(store.pending())
        guard !plan.work.isEmpty else {
            refreshStatus()
            return
        }

        status = .sending(changes: plan.work.count)

        // Labelled `queue`, because the two `break`s below have to leave the
        // loop and not the `switch`. A drain that stopped one case early and carried on
        // down the queue would collect the same connection error six times and
        // report the last one.
        queue: for unit in plan.work {
            switch store.action(for: unit, at: now()) {
            case .nothing(let reason):
                // Not a failure. The row is gone, or the window closed, and
                // there is nothing left to say about it — but it is logged by
                // name, because a queue that empties without sending anything
                // has to be explicable afterwards.
                Log.data.info(
                    "Dropping a queued \(unit.table.postgres, privacy: .public): \(reason.rawValue, privacy: .public)"
                )
                store.discard(unit.entryIDs)

            case .upsert(let row):
                let carriedOn = await send(unit) { try await client.upsert(row) }
                if !carriedOn { break queue }

            case .delete(let table, let id):
                let carriedOn = await send(unit) { try await client.delete(from: table, id: id) }
                if !carriedOn { break queue }
            }
        }

        refreshStatus()
    }

    /// One write, and what its failure means. Returns false when the drain
    /// should stop.
    private func send(_ unit: SyncUnit, _ write: () async throws -> Void) async -> Bool {
        do {
            try await write()
            store.discard(unit.entryIDs)
            lastSentAt = now()
            consecutiveFailures = 0
            return true
        } catch {
            let failure = (error as? SyncFailure) ?? .unavailable
            guard failure.isAboutTheConnection else {
                // This row, and only this row. Five of these and it parks.
                store.recordAttempt(on: unit.entryIDs)
                return true
            }
            // Nothing about the rest of the queue will go any better, and none
            // of it deserves an attempt against its name for a connection that
            // was not there.
            consecutiveFailures += 1
            scheduleRetry()
            return false
        }
    }

    private func scheduleRetry() {
        retrying?.cancel()
        let delay = SyncBackoff.delay(afterConsecutiveFailures: consecutiveFailures)
        retrying = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            await drain()
        }
    }

    // MARK: - What the panel reads

    func refreshStatus() {
        guard client != nil else {
            status = .noProject
            stuckCount = 0
            return
        }

        let plan = OutboxDrain.plan(store.pending())
        // An entry this build cannot map is counted here rather than deleted.
        // See `SyncStore.unmappable`.
        stuckCount = plan.parked.count + store.unmappable().count

        if !plan.work.isEmpty {
            status = .waiting(changes: plan.work.count)
        } else if stuckCount > 0 {
            status = .stuck(changes: stuckCount)
        } else {
            status = .upToDate(lastSentAt: lastSentAt)
        }
    }
}
