import AuthenticationServices
import CryptoKit
import Foundation

/// The Apple half of signing in: the nonce, and reading the credential.
///
/// Small, pure, and separate from `SupabaseAuthService` on purpose — this is
/// where the one bug everybody writes lives, and a pure type is one a test can
/// hold still.
///
/// **The bug.** `ASAuthorizationAppleIDRequest.nonce` wants the SHA-256 *hash*
/// of a random string; the identity token Apple returns carries that hash in
/// its `nonce` claim. Supabase is then given the *raw* string and hashes it
/// again to compare. Send the hash to both and the comparison fails — and the
/// rejection comes back as a generic invalid-token error that never mentions
/// the nonce, so the natural next move is to go looking at the project keys.
/// `makeNonce()` returns the raw value and `hashed(_:)` is the only thing that
/// goes to Apple, which makes the two hard to swap by accident.
enum AppleIdentity {
    /// URL-safe characters only. The value travels inside a JWT claim, and a
    /// character that needs escaping there is a bug that only shows up for the
    /// unlucky one sign-in in sixty.
    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    /// A fresh raw nonce. 32 characters from a 64-symbol alphabet is 192 bits,
    /// which is well past what a single-use replay guard needs.
    ///
    /// Not `randomElement()`: it returns an optional and the only way to use it
    /// inline is a force-unwrap, which is a warning in this project for a good
    /// reason — a crash here is a crash on the sign-in screen.
    static func makeNonce(length: Int = 32) -> String {
        var generator = SystemRandomNumberGenerator()
        let count = UInt64(alphabet.count)
        return String(
            (0..<length).map { _ in
                alphabet[Int(generator.next(upperBound: count))]
            }
        )
    }

    /// The value Apple is given: lowercase hex SHA-256 of the raw nonce.
    ///
    /// Hex rather than base64 because that is what Apple's own sample does and
    /// what every Supabase example assumes; a base64 digest is accepted by
    /// Apple and then silently mismatches at the server.
    static func hashed(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Pulls the identity token out of a completed authorisation.
    ///
    /// The full name and email Apple offers on the very first authorisation are
    /// deliberately dropped on the floor: nothing in Ninety needs them, and the
    /// first authorisation is the *only* time they are ever offered, so a field
    /// stored here would be one the app could never repair and would have to
    /// carry through every Article 9 export and deletion path.
    static func identityToken(from authorization: ASAuthorization) throws -> String {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let data = credential.identityToken,
            let token = String(data: data, encoding: .utf8),
            !token.isEmpty
        else {
            throw AuthFailure.appleReturnedNoToken
        }
        return token
    }

    /// Turns whatever Apple threw into one of ours.
    ///
    /// `.canceled` is the case that matters: it is a user decision and has to
    /// stay distinguishable all the way to the view, which shows nothing for
    /// it. Everything else collapses to one line, because the difference
    /// between `.invalidResponse` and `.notHandled` is not something a user can
    /// act on — and mapping any of them to "check your connection" would be
    /// stating a cause the app does not actually know.
    ///
    /// Only a genuine `URLError` earns the offline wording.
    static func failure(from error: any Error) -> AuthFailure {
        if let failure = error as? AuthFailure { return failure }
        if error is URLError { return .offline }

        if let authError = error as? ASAuthorizationError {
            return authError.code == .canceled ? .cancelled : .rejected
        }

        return .rejected
    }
}
