import Foundation

/// One food as the shared catalogue holds it.
///
/// A value rather than the `@Model`, and the split is the point. `Food` is a
/// SwiftData object with an identity in a store; this is what came back over the
/// wire. Keeping them apart means the search route can show results the phone
/// has never persisted — which is most of them, because the mirror is hundreds
/// of thousands of rows and the phone caches only what gets logged.
struct CatalogueFood: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let source: FoodSource
    let barcode: String?
    let name: String
    let brand: String?
    let kcalPer100g: Double
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?

    /// Spelled out rather than left to a key-decoding strategy. The strategy is
    /// a property of whichever decoder the SDK happens to hand over, and a
    /// silently-renamed column decodes to nil rather than to an error.
    enum CodingKeys: String, CodingKey {
        case id
        case source
        case barcode
        case name
        case brand
        case kcalPer100g = "kcal_per_100g"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }

    /// Energy for a portion, rounded — §1.2's rule about false precision holds
    /// on the way in as well as on the way out.
    func kcal(forGrams grams: Double) -> Double {
        (kcalPer100g * grams / 100).rounded()
    }

    /// What the row is turned into when it is cached on the phone.
    var draft: FoodDraft {
        FoodDraft(
            id: id,
            source: source,
            barcode: barcode,
            name: name,
            brand: brand,
            kcalPer100g: kcalPer100g,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}

/// The mirrored Open Food Facts and USDA catalogue, over the network.
///
/// §1.3 is explicit that this is *your* Postgres and never a third-party API on
/// a keystroke: a public food API is slow, rate-limited, and fails in exactly
/// the places people log food. The mirror is loaded by
/// `scripts/import_food_mirror.py`, and the `search_vector` column and its GIN
/// index have been in migration 001 since P1-B for this.
///
/// **Nothing on this protocol is allowed to be on the critical path of a log.**
/// The local repository answers first and this answers second; a search screen
/// that waits on it still shows the Squad, the Bench and every food already on
/// the phone. That is the whole of ADR 0005 as it applies to this route.
@MainActor
protocol FoodCatalogueProtocol {
    /// Full-text search against the tsvector index.
    func search(_ query: String, limit: Int) async throws -> [CatalogueFood]

    /// One packaged food by its barcode. Nil is a real answer — most of Open
    /// Food Facts is European, and a barcode genuinely absent from the mirror is
    /// the common case rather than a failure.
    func food(barcode: String) async throws -> CatalogueFood?
}

/// Why a catalogue call could not be answered.
///
/// Two cases, and neither is shown as an error state. Both degrade to what the
/// phone already holds, because a search box that reports a network failure has
/// told the user something they cannot act on in the queue they are standing in.
enum CatalogueError: LocalizedError, Equatable, CaseIterable {
    case offline
    /// A build with no Supabase project in it, or a server that declined.
    case unavailable

    var errorDescription: String? {
        switch self {
        // The copy deck's offline wording. Reassuring, not a warning — the
        // local results above it are real and loggable.
        case .offline: "Saved on your phone. It'll sync when you're back online."
        case .unavailable: "Showing what's on your phone."
        }
    }
}

/// The catalogue for a build with no Supabase project in it.
///
/// Not a `#if DEBUG` mock — this ships. A clone without `Config/Local.xcconfig`
/// runs, and `SupabaseConfiguration` already decided that the honest answer to a
/// missing project is a working app that says what it cannot do rather than a
/// crash. The search screen it produces is exactly the offline one: the user's
/// own foods, and a note saying that is what there is.
@MainActor
struct EmptyFoodCatalogue: FoodCatalogueProtocol {
    func search(_ query: String, limit: Int) async throws -> [CatalogueFood] { [] }

    func food(barcode: String) async throws -> CatalogueFood? { nil }
}
