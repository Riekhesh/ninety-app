import Foundation
import Supabase

/// The real one. **The only file in the app that imports the SDK.**
///
/// That is the whole reason `AuthServiceProtocol` exists. ADR 0003 accepts
/// vendor lock-in on auth as the price of Supabase, and the honest way to hold
/// a lock-in is to keep it in one file where its size is visible, rather than
/// letting `Session` and `AuthError` spread through the shell until the cost of
/// the decision can only be measured by trying to reverse it.
///
/// Three things are deliberately *not* here, because the SDK already does them
/// and doing them twice is worse than doing them once:
///
/// - **Token refresh.** `auth.session` refreshes an expired access token before
///   returning, and the client refreshes in the background while the app is
///   foregrounded. A second refresh loop of our own would race it.
/// - **Session storage.** The SDK persists to the Keychain, which survives a
///   cold launch, an app update, and a device restore. A `UserDefaults` copy
///   for convenience would be a second, staler source of truth for whether
///   somebody is signed in.
/// - **Retry.** A failed sign-in returns the user to a screen with one button
///   on it. That is the retry.
@MainActor
final class SupabaseAuthService: AuthServiceProtocol {
    private let client: SupabaseClient

    private(set) var currentSession: AuthSession?

    let changes: AsyncStream<AuthSession?>
    private let continuation: AsyncStream<AuthSession?>.Continuation
    private var observation: Task<Void, Never>?

    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey
        )
        (changes, continuation) = AsyncStream.makeStream()
        observe()
    }

    // Only the continuation, which is an immutable Sendable `let` and so
    // readable from a nonisolated deinit. The observation task is not touched
    // here: it holds `self` weakly and returns on the next event.
    deinit {
        continuation.finish()
    }

    // MARK: - AuthServiceProtocol

    func restore() async throws -> AuthSession? {
        // Nothing in the Keychain is the ordinary first-launch state, and it is
        // a value here rather than an error — the same rule the repositories
        // hold to. Asking the network about a user who has never signed in
        // would also make the launch screen wait on a round trip.
        guard client.auth.currentSession != nil else {
            currentSession = nil
            return nil
        }

        do {
            let session = try await client.auth.session
            let restored = Self.session(from: session)
            currentSession = restored
            Log.auth.info("Session restored; refresh handled by the SDK.")
            return restored
        } catch {
            let failure = AppleIdentity.failure(from: error)

            // A refresh that failed for want of a network is not a revoked
            // session. ADR 0005 is explicit that the UI never waits on the
            // network, and gyms and basements have no signal — which is exactly
            // where and when people log food. So a launch with the radio off
            // keeps the session already in the Keychain and lets the SDK
            // refresh when connectivity returns.
            if failure == .offline, let local = client.auth.currentSession {
                let kept = Self.session(from: local)
                currentSession = kept
                Log.auth.info("Offline at launch; keeping the stored session.")
                return kept
            }

            // Anything else is a session that exists and cannot be revived.
            // That is a real failure and the user is owed the reason, so it
            // throws rather than quietly showing the sign-in screen again.
            currentSession = nil
            throw failure
        }
    }

    func signIn(idToken: String, rawNonce: String) async throws -> AuthSession {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    // The RAW nonce. Apple got its SHA-256; the server hashes
                    // this and compares. See AppleIdentity for what happens
                    // when the hashed one is sent here instead.
                    nonce: rawNonce
                )
            )
            let signedIn = Self.session(from: session)
            currentSession = signedIn
            Log.auth.info("Signed in with Apple.")
            return signedIn
        } catch {
            Log.auth.error("Sign in with Apple did not complete: \(error.localizedDescription, privacy: .public)")
            throw AppleIdentity.failure(from: error)
        }
    }

    func signOut() async throws {
        // Cleared first, and on purpose. If the server call fails the user is
        // still signed out on this device, which is what they asked for; the
        // alternative leaves somebody looking at their data after tapping sign
        // out because a request timed out.
        currentSession = nil
        do {
            try await client.auth.signOut()
            Log.auth.info("Signed out.")
        } catch {
            Log.auth.error("Sign-out was not confirmed by the server: \(error.localizedDescription, privacy: .public)")
            throw AuthFailure.signOutIncomplete
        }
    }

    // MARK: - Plumbing

    /// Mirrors the SDK's own stream, mapped to our value and nothing else.
    ///
    /// **With one correction, which the SDK itself asks for.** `authStateChanges`
    /// emits its initial session only *after* trying to refresh, so a launch
    /// with no signal and an expired access token emits nil — and an observer
    /// that took that at face value would sign the user out for being on the
    /// Underground. The SDK logs a warning about this and offers
    /// `emitLocalSessionAsInitialSession` to opt into the fixed behaviour in a
    /// future major version (supabase/supabase-swift#822).
    ///
    /// Falling back to `currentSession` gets the same result from the API that
    /// exists today: a nil emission means signed out only when the Keychain
    /// agrees. A real sign-out clears both, so that case still reads correctly.
    private func observe() {
        observation = Task { [weak self] in
            guard let stream = self?.client.auth.authStateChanges else { return }
            for await (event, session) in stream {
                guard let self else { return }
                let live = session ?? client.auth.currentSession
                let mapped = live.map(Self.session(from:))
                currentSession = mapped
                if event == .tokenRefreshed {
                    Log.auth.debug("Access token refreshed without user action.")
                }
                continuation.yield(mapped)
            }
        }
    }

    /// The SDK's session, reduced to the two fields the app uses.
    ///
    /// `expiresAt` is epoch seconds on the wire, not a `Date`.
    private static func session(from session: Session) -> AuthSession {
        AuthSession(
            userID: session.user.id,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}
