import Foundation

/// What the outbox looks like right now, as the one value a screen renders.
///
/// Five states and no spinner among them. §04's rule is that the UI never waits
/// on the network, and a progress indicator is a small way of breaking it — it
/// tells the user something is in flight that they might want to wait for, and
/// on this screen there is never anything worth waiting for. `sending` says what
/// is happening and stays a sentence.
enum SyncStatus: Equatable, Sendable {
    /// Nothing queued. The date is the last time something actually landed, and
    /// nil until something has.
    case upToDate(lastSentAt: Date?)
    /// Written on the phone, not yet on the server. The ordinary state of a day
    /// spent underground.
    case waiting(changes: Int)
    case sending(changes: Int)
    /// Refused often enough that Ninety has stopped asking. Still on the phone,
    /// still visible, still countable — never silently retried forever, which
    /// is the whole reason `OutboxEntry.attempts` exists.
    case stuck(changes: Int)
    /// No Supabase project in this build. A clone without `Config/Local.xcconfig`
    /// — not a state a user can reach.
    case noProject

    /// True when there is something a "try again" could act on.
    var invitesRetry: Bool {
        switch self {
        case .waiting, .stuck: true
        case .upToDate, .sending, .noProject: false
        }
    }
}
