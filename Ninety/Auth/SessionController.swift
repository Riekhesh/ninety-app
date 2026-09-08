import AuthenticationServices
import Foundation
import Observation

/// Who is signed in, as the one thing the shell switches on.
///
/// ADR 0004's shape: an `@Observable` object between the views and a protocol.
/// It owns the nonce pair as well as the state, and that is not tidiness — the
/// raw nonce and its hash have to be generated together and used in opposite
/// directions, so keeping them in a view's `@State` next to each other is how
/// they get swapped. `prepare(_:)` and `finish(_:)` are the only two ways in.
@MainActor
@Observable
final class SessionController {
    /// Four states, and the app renders exactly one screen for each.
    enum State: Equatable {
        /// Reading the Keychain. Short, and not a loading spinner — see
        /// `LaunchHold`.
        case restoring

        /// No Supabase project in this build. A clone without a
        /// `Config/Local.xcconfig`, not something a user can reach.
        case unconfigured

        case signedOut

        /// Signed in. Whether the user has consented yet is a separate
        /// question, answered from the profile row rather than from here — a
        /// reinstall is a returning user whose consent lives on the server.
        case signedIn(UUID)
    }

    private(set) var state: State = .restoring

    /// The last thing that went wrong, in the copy deck's words. Nil for a
    /// cancelled sign-in, which is a decision rather than a failure.
    private(set) var failure: AuthFailure?

    /// True while Apple's sheet or the token exchange is in flight. The button
    /// disables on it, so a double tap cannot start two exchanges with two
    /// different nonces and have the first one's reply rejected.
    private(set) var isSigningIn = false

    private let service: (any AuthServiceProtocol)?

    /// The raw nonce for the authorisation currently in flight.
    ///
    /// Cleared as soon as it is used: a nonce is a single-use replay guard, and
    /// one kept around to be helpful is one that can be replayed.
    private var pendingNonce: String?

    /// Cancelled by the stream ending, not by a `deinit`: the loop below holds
    /// `self` weakly and returns the moment the controller is gone. A `deinit`
    /// touching this would be a nonisolated context reaching a `@MainActor`
    /// stored property, which Swift 6 rightly refuses.
    private var observation: Task<Void, Never>?

    /// Nil service means unconfigured, which is why this takes an optional
    /// rather than the app deciding to crash. `SupabaseConfiguration.fromBundle`
    /// returns nil on a fresh clone and a fresh clone should still run.
    init(service: (any AuthServiceProtocol)?) {
        self.service = service
        state = service == nil ? .unconfigured : .restoring
    }

    // MARK: - Lifecycle

    /// Cold-launch restore, then stay listening.
    ///
    /// Both halves matter for the ticket: the first is "session restore across
    /// a cold launch", the second is "the token refreshes without user action"
    /// — the SDK does the refreshing, and this is how the app finds out that it
    /// did, or that the session went away underneath it.
    func start() async {
        guard let service else { return }

        do {
            let session = try await service.restore()
            state = session.map { .signedIn($0.userID) } ?? .signedOut
        } catch {
            // A session that would not revive. The user is signed out, and
            // told why rather than shown the sign-in screen with no
            // explanation for why they are looking at it again.
            failure = AppleIdentity.failure(from: error)
            state = .signedOut
        }

        observe(service)
    }

    private func observe(_ service: any AuthServiceProtocol) {
        observation?.cancel()
        observation = Task { [weak self] in
            for await session in service.changes {
                guard let self else { return }
                // Only ever moves between signed in and signed out. Nothing
                // the SDK reports can put the app back into `.restoring` or
                // `.unconfigured`, and letting it would flash the launch hold
                // in the middle of a session.
                state = session.map { .signedIn($0.userID) } ?? .signedOut
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Fills in Apple's request: the hashed nonce, and no scopes at all.
    ///
    /// **No scopes on purpose.** Name and email are offered exactly once, on
    /// the first authorisation, and Ninety needs neither — the user id is what
    /// every row is keyed on. Asking for data you will not use is the cheapest
    /// possible privacy mistake to avoid, and one the App Privacy labels then
    /// do not have to declare.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let raw = AppleIdentity.makeNonce()
        pendingNonce = raw
        request.requestedScopes = []
        request.nonce = AppleIdentity.hashed(raw)
    }

    /// Takes Apple's answer through to a Supabase session.
    func finish(_ result: Result<ASAuthorization, any Error>) async {
        guard let service else {
            failure = .notConfigured
            return
        }

        let nonce = pendingNonce
        pendingNonce = nil

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let authorization = try result.get()
            guard let nonce else { throw AuthFailure.rejected }
            let token = try AppleIdentity.identityToken(from: authorization)
            let session = try await service.signIn(idToken: token, rawNonce: nonce)
            failure = nil
            state = .signedIn(session.userID)
        } catch {
            let mapped = AppleIdentity.failure(from: error)
            failure = mapped.isSilent ? nil : mapped
        }
    }

    // MARK: - Sign out

    /// Ends the session. The local store is deliberately left alone: erasing a
    /// device's health data is Phase 3's deletion path, and signing out on a
    /// shared phone should not be the thing that destroys three weeks of logs.
    func signOut() async {
        guard let service else { return }
        do {
            try await service.signOut()
            failure = nil
        } catch {
            // The session is gone locally either way, so this is a note rather
            // than a reason to keep the user signed in.
            failure = AppleIdentity.failure(from: error)
        }
        state = .signedOut
    }

    /// Clears a shown failure, so the sign-in screen does not keep an old one
    /// on display through the next attempt.
    func dismissFailure() {
        failure = nil
    }
}
