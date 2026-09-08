import Foundation
import Supabase

/// The one `SupabaseClient` in the process.
///
/// P1-C's `SupabaseAuthService` used to build its own, and its doc comment said
/// why a second one would be a mistake: the client holds the Keychain session
/// and the background refresh timer, so two clients are two refresh loops racing
/// each other over one session. That reasoning did not change when P1-F needed
/// the network for a second and third thing — it just stopped being satisfiable
/// by one file owning a private client.
///
/// So the client moved here, and the three things that speak to Supabase take
/// this rather than a configuration:
///
/// - `SupabaseAuthService` — the id-token exchange and the session
/// - `SupabaseFoodCatalogue` — the text search and the barcode lookup (P1-F)
/// - `SupabaseMealEstimator` — the photo upload and the Edge Function (P1-F)
///
/// **The lock-in claim is unchanged and is still worth checking against.** ADR
/// 0003 accepts vendor lock-in on Supabase as the price of Supabase, and the
/// honest way to hold one is to keep it where its size is visible. It is now
/// four files rather than one, each behind a protocol the rest of the app talks
/// to instead — `AuthServiceProtocol`, `FoodCatalogueProtocol`,
/// `MealEstimating` — so the cost of reversing it is still countable without
/// trying it.
///
/// `@MainActor` for the same reason the repositories are: everything that holds
/// it is, the async calls on it suspend rather than block, and the alternative
/// is asserting a `Sendable` guarantee about an SDK type that this project does
/// not own.
@MainActor
final class SupabaseStack {
    let client: SupabaseClient
    let configuration: SupabaseConfiguration

    init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey
        )
    }

    /// The signed-in user's id, or nil.
    ///
    /// Read from the client rather than passed in, because everything that uses
    /// it is building a Storage path whose first segment the storage policies
    /// compare against `auth.uid()`. Passing the id in would let a caller build
    /// a path for somebody else and find out at the server; reading it here
    /// means the only path the app can construct is its own.
    var currentUserID: UUID? {
        client.auth.currentSession?.user.id
    }
}
