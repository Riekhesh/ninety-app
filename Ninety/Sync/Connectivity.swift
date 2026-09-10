import Foundation
import Network

/// Whether there is a path to the network, as a stream of answers.
///
/// Deliberately only a stream, with no `isOnline` to read. A boolean you can
/// ask for invites a screen to ask before doing something, and §04's whole
/// decision is that nothing in this app asks: a log is written locally and
/// rendered immediately, always. Nobody may branch on this. The one legitimate
/// consumer is the drain, and what it needs is not the current state but the
/// **moment it changes** — walking out of the Underground is the event the
/// outbox has been waiting for.
///
/// **A function rather than a property, and that is not a style choice.** The
/// watcher is owned by `SyncService`, which is built per signed-in user, so
/// signing out and back in creates a second one. An `AsyncStream` has a single
/// consumer and is finished by the cancellation of the task reading it — so a
/// stored stream would work exactly once per launch, and then quietly stop
/// delivering reconnects for the rest of the session. Handing out a fresh
/// stream per caller costs a dictionary and removes a bug that would only ever
/// have appeared in somebody's second session of the day.
@MainActor
protocol ConnectivityWatching {
    /// A new stream, which yields the current state at once and then on every
    /// change.
    func changes() -> AsyncStream<Bool>
}

/// The real one, over `NWPathMonitor`.
///
/// `.satisfied` is as much as the system will tell you and rather less than it
/// sounds: a captive portal, a hotel wifi that has not been agreed to and a
/// train tunnel with one bar all report a satisfied path. That is fine here
/// precisely because nothing branches on it — a wrong `true` costs one failed
/// request and a backoff, and a wrong `false` costs nothing at all, because the
/// drain's own timer runs anyway.
@MainActor
final class PathConnectivity: ConnectivityWatching {
    private var listeners: [UUID: AsyncStream<Bool>.Continuation] = [:]

    /// The last thing the monitor said. Optimistic before it has said anything,
    /// because the first drain attempt is cheap and a pessimistic start would
    /// hold a queue back for no reason.
    private var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.ninety.connectivity")

    init() {
        // The handler runs on its own queue. A `@MainActor` class is implicitly
        // `Sendable` — its state is protected by the actor — so capturing it
        // weakly here is allowed, and the hop is what makes touching that state
        // legal rather than merely lucky.
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.publish(online) }
        }
        monitor.start(queue: queue)
    }

    func changes() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.listeners[id] = nil }
        }
        continuation.yield(isOnline)
        return stream
    }

    private func publish(_ online: Bool) {
        isOnline = online
        for listener in listeners.values { listener.yield(online) }
    }

    /// Explicit rather than a `deinit`.
    ///
    /// A `deinit` on a `@MainActor` type runs outside that isolation and cannot
    /// touch a stored property — `SessionController` has the same note, and it
    /// is the same Swift 6 rule. In practice nothing calls this: the monitor
    /// lives as long as the app does.
    func stop() {
        monitor.cancel()
        for listener in listeners.values { listener.finish() }
        listeners.removeAll()
    }
}
