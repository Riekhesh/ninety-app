import AuthenticationServices
import Foundation
import Testing
@testable import Ninety

/// Sign in with Apple, and the state the shell switches on.
///
/// Nothing here talks to Supabase. The service is behind a protocol precisely
/// so these can run in a simulator with the network off — what is under test is
/// the nonce pairing, the failure mapping and the state machine, and all three
/// are things this app got wrong rather than things the SDK might.
@MainActor
@Suite("Authentication")
struct AuthTests {
    // MARK: - The nonce

    /// The bug this whole type exists to prevent.
    ///
    /// Apple is given the SHA-256 of the nonce; Supabase is given the raw one
    /// and hashes it again to compare. Send the same string to both and the
    /// exchange is rejected with a message that never mentions the nonce, which
    /// is why it costs an afternoon rather than a minute.
    @Test("Apple gets the hash, the server gets the raw nonce, and they are not the same string")
    func nonceGoesToBothInTheRightForm() {
        let raw = AppleIdentity.makeNonce()
        let hashed = AppleIdentity.hashed(raw)

        #expect(hashed != raw)
        #expect(AppleIdentity.hashed(raw) == hashed, "hashing has to be deterministic or nothing can compare")
        #expect(AppleIdentity.hashed(hashed) != hashed, "hashing twice is the mistake, and it changes the value")
    }

    @Test("the hash is lowercase hex SHA-256, which is the form Apple's own sample uses")
    func hashIsLowercaseHexSHA256() {
        // A published vector, so this fails if the digest or the encoding moves.
        #expect(AppleIdentity.hashed("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(AppleIdentity.hashed("abc").count == 64)
    }

    @Test("every nonce is new, and URL-safe")
    func nonceIsFreshAndSafe() {
        let nonces = (0..<200).map { _ in AppleIdentity.makeNonce() }
        #expect(Set(nonces).count == nonces.count, "a repeated nonce is a replay guard that does not guard")

        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        for nonce in nonces {
            #expect(nonce.count == 32)
            #expect(nonce.unicodeScalars.allSatisfy(allowed.contains), "\(nonce) needs escaping inside a JWT claim")
        }
    }

    // MARK: - Failures, in the copy deck's words

    @Test("a cancelled sign-in shows nothing at all")
    func cancellingIsSilent() {
        #expect(AuthFailure.cancelled.isSilent)
        #expect(AuthFailure.cancelled.errorDescription == nil)

        let cancelled = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.Code.canceled.rawValue
        )
        #expect(AppleIdentity.failure(from: cancelled) == .cancelled)
    }

    @Test("only a real network error gets the offline wording")
    func offlineIsNotGuessedAt() {
        #expect(AppleIdentity.failure(from: URLError(.notConnectedToInternet)) == .offline)
        #expect(AppleIdentity.failure(from: NSError(domain: "GoTrue", code: 400)) == .rejected)
        #expect(AppleIdentity.failure(from: AuthFailure.appleReturnedNoToken) == .appleReturnedNoToken)
    }

    @Test("no failure state shows the user a raw error string")
    func everyFailureHasItsOwnWording() {
        for failure in AuthFailure.allCases where !failure.isSilent {
            let description = failure.errorDescription
            #expect(description?.isEmpty == false, "\(failure) reaches the user with nothing to read")
            // The tells of an error written for a developer rather than a user.
            for tell in ["Error", "error", "nil", "Optional", "GoTrue", "Supabase Auth", "HTTP"] {
                #expect(description?.contains(tell) != true, "\(failure) leaks \"\(tell)\"")
            }
        }
    }

    // MARK: - The state machine

    @Test("a build with no Supabase project says so instead of pretending it can sign in")
    func noConfigurationIsItsOwnState() async {
        let controller = SessionController(service: nil)
        #expect(controller.state == .unconfigured)

        await controller.start()
        #expect(controller.state == .unconfigured, "start() must not walk an unconfigured build into signed-out")

        await controller.finish(.failure(AuthFailure.rejected))
        #expect(controller.failure == .notConfigured)
    }

    @Test("a cold launch with nothing stored lands on sign-in, not on an error")
    func firstLaunchIsSignedOut() async {
        let controller = SessionController(service: MockAuthService())
        await controller.start()

        #expect(controller.state == .signedOut)
        #expect(controller.failure == nil, "having never signed in is not a failure")
    }

    @Test("a stored session survives a cold launch")
    func sessionRestores() async {
        let user = UUID()
        let service = MockAuthService(
            session: AuthSession(userID: user, expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
        )
        let controller = SessionController(service: service)
        await controller.start()

        #expect(controller.state == .signedIn(user))
    }

    @Test("a session that will not revive signs the user out and says why")
    func unrevivableSessionExplainsItself() async {
        let service = MockAuthService(session: AuthSession(userID: UUID(), expiresAt: .distantPast))
        service.restoreError = URLError(.notConnectedToInternet)

        let controller = SessionController(service: service)
        await controller.start()

        #expect(controller.state == .signedOut)
        #expect(controller.failure == .offline)
    }

    @Test("cancelling at Apple's sheet leaves no message on screen")
    func cancellingLeavesNoMessage() async {
        let controller = SessionController(service: MockAuthService())
        let cancelled = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.Code.canceled.rawValue
        )

        await controller.finish(.failure(cancelled))

        #expect(controller.failure == nil)
        #expect(controller.isSigningIn == false)
    }

    @Test("signing out ends the session even when the server never confirms it")
    func signOutIsLocalFirst() async {
        let service = MockAuthService(session: AuthSession(userID: UUID(), expiresAt: .distantFuture))
        service.signOutError = AuthFailure.signOutIncomplete

        let controller = SessionController(service: service)
        await controller.start()
        await controller.signOut()

        #expect(controller.state == .signedOut, "a failed server call must not leave the user looking at their data")
        #expect(controller.failure == .signOutIncomplete)
        #expect(service.signOutCount == 1)
    }

    // MARK: - Configuration

    @Test("the host is a host, and the scheme is added rather than pasted")
    func configurationBuildsItsOwnURL() {
        let configuration = SupabaseConfiguration(host: "abcdefgh.supabase.co", anonKey: "sb_publishable_xxx")
        #expect(configuration?.url.absoluteString == "https://abcdefgh.supabase.co")

        // What a pasted URL becomes after xcconfig eats everything from `//`.
        // This is the case that shipped broken: `https:` has no slash, so a
        // guard that only rejected `/` built `https://https:` and handed the
        // user a sign-in button that could never work.
        #expect(SupabaseConfiguration(host: "https:", anonKey: "k") == nil)
        // And what it would have been if xcconfig had not.
        #expect(SupabaseConfiguration(host: "https://abcdefgh.supabase.co", anonKey: "k") == nil)
        // The neighbouring ways to write something that is not a host.
        #expect(SupabaseConfiguration(host: "abcdefgh.supabase.co:5432", anonKey: "k") == nil)
        #expect(SupabaseConfiguration(host: "localhost", anonKey: "k") == nil)
        #expect(SupabaseConfiguration(host: "abcdefgh supabase co", anonKey: "k") == nil)

        // A custom domain is still a host, and the Data API settings offer one.
        let custom = SupabaseConfiguration(host: "api.ninety.app", anonKey: "k")
        #expect(custom?.url.absoluteString == "https://api.ninety.app")
    }

    @Test("a clone with nothing filled in is unconfigured rather than half-configured")
    func blankConfigurationIsNil() {
        #expect(SupabaseConfiguration(host: "", anonKey: "") == nil)
        #expect(SupabaseConfiguration(host: "  ", anonKey: "key") == nil)
        #expect(SupabaseConfiguration(host: "abcdefgh.supabase.co", anonKey: "   ") == nil)
        #expect(SupabaseConfiguration(host: nil, anonKey: nil) == nil)
    }
}
