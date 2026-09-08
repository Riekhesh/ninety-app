import Foundation

/// A signed-in user, as the app needs to know them.
///
/// Deliberately two fields and no SDK types. Everything above the auth
/// boundary — the shell, the repositories, the consent gate — is handed one of
/// these, so `import Supabase` appears in exactly one file in the app
/// (`SupabaseAuthService`) and swapping the provider is a file, not a refactor.
///
/// **No email, no name, no Apple user identifier.** Sign in with Apple offers
/// all three on the first authorisation and the app takes none of them: the
/// `id` is the only thing any query needs, and a field you never store is a
/// field that cannot leak, cannot go stale behind Hide My Email, and does not
/// have to appear on an Article 9 export.
struct AuthSession: Equatable, Sendable {
    /// The Supabase auth user id, which is also `profiles.id` and the
    /// `user_id` every RLS policy compares against.
    let userID: UUID

    /// When the access token stops being accepted. Held so the app can say
    /// something true about the session without asking the SDK, not so it can
    /// refresh by hand — the SDK does that, and doing it in two places is how
    /// you get a refresh race.
    let expiresAt: Date
}
