#if DEBUG
import Foundation

/// An auth service with no server behind it.
///
/// Same reasoning as `MockRepositories`: `#if DEBUG` so it cannot reach a
/// release build, and plain stored properties rather than closures so a test
/// can be read top to bottom and be certain what it returns.
///
/// It also covers the previews. A `SignInView` preview backed by the real
/// service would try to open a Supabase client from Xcode's preview process,
/// which is a slow way to render a screen with one button on it.
@MainActor
final class MockAuthService: AuthServiceProtocol {
    var storedSession: AuthSession?

    /// Set any of these to make the matching call throw.
    var restoreError: (any Error)?
    var signInError: (any Error)?
    var signOutError: (any Error)?

    private(set) var signInCount = 0
    private(set) var signOutCount = 0

    /// What `signIn` was handed. The nonce is here so a test can assert the
    /// *raw* one reached the server — the one bug `AppleIdentity` exists to
    /// prevent is invisible in every other observable way.
    private(set) var lastIDToken: String?
    private(set) var lastRawNonce: String?

    let changes: AsyncStream<AuthSession?>
    private let continuation: AsyncStream<AuthSession?>.Continuation

    init(session: AuthSession? = nil) {
        storedSession = session
        (changes, continuation) = AsyncStream.makeStream()
    }

    deinit {
        continuation.finish()
    }

    var currentSession: AuthSession? { storedSession }

    func restore() async throws -> AuthSession? {
        if let restoreError { throw restoreError }
        return storedSession
    }

    func signIn(idToken: String, rawNonce: String) async throws -> AuthSession {
        lastIDToken = idToken
        lastRawNonce = rawNonce
        if let signInError { throw signInError }
        signInCount += 1
        let session = storedSession ?? AuthSession(userID: UUID(), expiresAt: Date().addingTimeInterval(3_600))
        storedSession = session
        return session
    }

    func signOut() async throws {
        signOutCount += 1
        storedSession = nil
        if let signOutError { throw signOutError }
    }

    /// Pushes a change as if the SDK had — a background refresh, or a session
    /// revoked at the server. Nothing else can drive that path in a test.
    func emit(_ session: AuthSession?) {
        storedSession = session
        continuation.yield(session)
    }
}
#endif
