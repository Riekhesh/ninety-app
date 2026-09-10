import Foundation

/// The one thing the drain needs from the network.
///
/// Two methods, because the outbox only ever says three things and an upsert
/// covers two of them. Behind a protocol for the same reason every other
/// boundary in this app is: the interesting part of P1-I is the *policy* —
/// which order, what counts as a retry, what gets parked — and a policy that
/// can only be tested against a live Supabase project is one that gets tested
/// once, by hand, on the day it is written.
@MainActor
protocol SyncWriting {
    /// Insert the row, or overwrite the one already there. Idempotent by
    /// construction: the id is minted on the device, so a replayed payload
    /// resolves to the row it already wrote rather than a second copy of it.
    func upsert(_ row: SyncRow) async throws

    /// Remove the row by id. A row the server never received is not an error —
    /// removing something that is not there is the state the caller wanted.
    func delete(from table: SyncTable, id: UUID) async throws
}

/// Why a write did not land, split by whose fault it is.
///
/// The split is the whole of the retry policy, and it exists because of the
/// clock. Three weeks of logs sitting in an outbox on an aeroplane must not
/// burn five attempts each and arrive at the ground already parked — so a
/// failure that is *not about this row* costs no attempts at all and simply
/// stops the drain until there is a point in trying again.
enum SyncFailure: Error, Equatable {
    /// No usable connection. The ordinary case, and the one the whole feature
    /// is for.
    case offline
    /// No session, or one the server would not accept. Nothing to do until the
    /// user is signed in again; the SDK owns the refresh.
    case notSignedIn
    /// The server answered, and the answer was about the server. 5xx, and the
    /// rate limiter, which is a request to come back later rather than a
    /// verdict on the row.
    case unavailable
    /// The server answered, and the answer was about **this row**. A constraint,
    /// a policy, a column that does not exist. Asking again unchanged will get
    /// the same reply, so this is the only failure that counts toward parking.
    case refused(status: Int)

    /// True when the failure says nothing about the row that provoked it.
    ///
    /// The drain stops on one of these rather than working down the queue
    /// collecting the same error, and no attempt is recorded against anything.
    var isAboutTheConnection: Bool {
        switch self {
        case .offline, .notSignedIn, .unavailable: true
        case .refused: false
        }
    }
}
