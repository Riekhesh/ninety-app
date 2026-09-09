import Foundation
import Supabase

/// The real catalogue, over PostgREST.
///
/// Two queries and nothing else. Both are `select` against `public.foods`, whose
/// read policy is the one policy in the schema that is deliberately not
/// user-scoped — *"a food catalogue only its creator can see is a catalogue
/// nobody benefits from"* — so this needs no user id and cannot leak one user's
/// custom foods to another, because a custom row still belongs to whoever made
/// it and the policy says so.
@MainActor
struct SupabaseFoodCatalogue: FoodCatalogueProtocol {
    let stack: SupabaseStack

    /// What `search_foods` takes. A type rather than a dictionary so the two
    /// argument names are checked by the compiler against one declaration
    /// instead of being spelled twice.
    private struct SearchArguments: Encodable, Sendable {
        let query: String
        let maxResults: Int

        enum CodingKeys: String, CodingKey {
            case query
            case maxResults = "max_results"
        }
    }

    func search(_ query: String, limit: Int) async throws -> [CatalogueFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        do {
            // The `search_foods` function rather than a filter built here, and
            // the reason is ranking: the tsvector weights set in migration 001
            // (name above brand) only do anything if something orders by
            // `ts_rank`, and that is a `select` clause rather than a filter.
            // It also keeps `websearch_to_tsquery` server-side — the parser
            // that reads "greek yogurt" as an AND of both words and that never
            // raises on the punctuation a search box actually receives.
            return try await stack.client
                .rpc("search_foods", params: SearchArguments(query: trimmed, maxResults: limit))
                .execute()
                .value
        } catch {
            throw Self.failure(from: error)
        }
    }

    func food(barcode: String) async throws -> CatalogueFood? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        do {
            let rows: [CatalogueFood] = try await stack.client
                .from("foods")
                .select(Self.columns)
                .eq("barcode", value: trimmed)
                // A barcode is not unique in the mirror — Open Food Facts and
                // USDA can both carry one, and the same product is sometimes
                // listed twice. `limit(1)` rather than `.single()`, which turns
                // "two rows" into a thrown error on a route whose whole job is
                // to answer quickly.
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw Self.failure(from: error)
        }
    }

    /// The columns, once. A `select("*")` would also pull `search_vector`,
    /// which is a large opaque value on every row and is never read by the app.
    ///
    /// The search path does not use it: `search_foods` returns `setof foods`,
    /// so its rows carry `search_vector` too. `CatalogueFood` decodes the keys
    /// it declares and ignores the rest, which costs some bytes on that route
    /// and buys ranking — the trade is worth it, and narrowing the function's
    /// return type would mean a second row type to keep in step with this one.
    private static let columns = "id,source,barcode,name,brand,kcal_per_100g,protein_g,carbs_g,fat_g"

    /// Every failure becomes one of two states the UI already has copy for.
    ///
    /// The URLError check is the same shape `AppleIdentity` uses for sign-in:
    /// only a real transport failure gets the offline wording, because mapping
    /// every failure to "check your connection" states a cause the app does not
    /// know.
    private static func failure(from error: any Error) -> CatalogueError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                return .offline
            default:
                return .unavailable
            }
        }
        return .unavailable
    }
}
