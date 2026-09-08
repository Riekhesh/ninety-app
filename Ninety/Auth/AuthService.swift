import Foundation

/// Identity, as a protocol.
///
/// The same shape as the four repositories in `Ninety/Data`, and for the same
/// reason: the shell talks to this, and whether the answer came from Supabase,
/// from the Keychain or from a mock is not its business. `SupabaseAuthService`
/// is the only implementation that touches the network, and the only file in
/// the app that imports the SDK.
///
/// **Everything here is `async` and none of it is optional-returning by
/// accident.** `restore()` gives nil for "nobody is signed in", which is the
/// ordinary first-launch state and not an error — the same rule the
/// repositories hold to. It throws only when it genuinely could not find out.
@MainActor
protocol AuthServiceProtocol {
    /// The session already in hand, if any, without going to the network.
    /// Nil during launch before `restore()` has run.
    var currentSession: AuthSession? { get }

    /// Cold-launch restore. Reads the persisted session and refreshes it if
    /// the access token has expired, which is why it is async and why the app
    /// has no refresh code of its own.
    ///
    /// Returns nil when there is no session to restore. Throws only when a
    /// session exists and could not be revived — an expired refresh token, or
    /// a server that said no — because that is a signed-out user who deserves
    /// to be told why rather than silently shown the sign-in screen again.
    func restore() async throws -> AuthSession?

    /// Exchanges an Apple identity token for a Supabase session.
    ///
    /// `rawNonce` is the *unhashed* string. Apple was given its SHA-256; the
    /// identity token carries that hash, and Supabase recomputes it from this
    /// value. Sending the hashed one here is the classic failure and it
    /// presents as a flat rejection with nothing in the message that names the
    /// nonce — see `AppleIdentity`.
    func signIn(idToken: String, rawNonce: String) async throws -> AuthSession

    /// Ends the session locally and at the server. Local health data is left
    /// where it is; erasing it is Phase 3's deletion path, not this.
    func signOut() async throws

    /// Session changes the app did not ask for: a token refreshed in the
    /// background, or a session revoked at the server.
    ///
    /// A stream rather than a delegate because the refresh is the SDK's job and
    /// the app's only interest is being told it happened — the acceptance
    /// criterion is that the token refreshes *without user action*, and an app
    /// that has to poll to find out is one refresh away from signing someone
    /// out mid-log. Yields nil when the session goes away.
    var changes: AsyncStream<AuthSession?> { get }
}

/// What can go wrong signing in, in the copy deck's words.
///
/// The wording is the point. A `URLError` or a `GoTrueError` surfaced raw tells
/// the user the name of a library, and the ticket's acceptance criteria say
/// failure states use `design/spec/04-copy-deck.md` rather than whatever the
/// SDK happened to throw. Every case here maps to one line in §1 of that file
/// and `AuthCopyTests` checks they still agree.
enum AuthFailure: Error, LocalizedError, Equatable, CaseIterable {
    /// The user dismissed Apple's sheet. Not a failure state — see `isSilent`.
    case cancelled

    /// Apple completed but handed back no identity token. Rare, and there is
    /// nothing to do about it except go round again.
    case appleReturnedNoToken

    /// No route to the server. Distinguished from `rejected` because the two
    /// have different next actions and "try again" is only honest for one.
    case offline

    /// The server declined the exchange. Deliberately not repeated verbatim to
    /// the user: an auth error's text is written for a developer.
    case rejected

    /// This build has no Supabase project in it. A developer state — a clone
    /// without `Config/Local.xcconfig` — surfaced rather than crashed on, so a
    /// fresh checkout still runs and says what is missing.
    case notConfigured

    /// The server could not be told about the sign-out. The session is gone
    /// locally either way, which is what the user asked for.
    case signOutIncomplete

    /// True when the right response is to show nothing at all.
    ///
    /// Cancelling is a decision, not an error. An app that answers "you
    /// dismissed the sheet" with a red banner is arguing with the user about
    /// something they did on purpose.
    var isSilent: Bool { self == .cancelled }

    var errorDescription: String? {
        switch self {
        case .cancelled:
            nil
        case .appleReturnedNoToken:
            "Apple didn't hand back a sign-in token. Worth another go."
        case .offline:
            "Can't reach Ninety right now. Check your connection and try again."
        case .rejected:
            "Ninety couldn't finish signing you in. Try again in a moment."
        case .notConfigured:
            "This build isn't connected to a Ninety project yet."
        case .signOutIncomplete:
            "Signed out on this phone. The server hasn't confirmed it yet."
        }
    }

    /// The second line, where there is one worth saying. Same rule as the
    /// copy deck's: state the fact, then give the next action.
    var recoveryDescription: String? {
        switch self {
        case .notConfigured:
            "Config/Local.xcconfig needs SUPABASE_HOST and SUPABASE_ANON_KEY. See docs/security/secrets.md."
        case .offline:
            "Anything already on this phone stays where it is."
        default:
            nil
        }
    }
}
