import Foundation
import Observation

/// Path 1 — text search, local first and network second.
///
/// **The local answer is not a fallback, it is the first answer.** Every
/// keystroke re-filters what is already on the phone and renders immediately;
/// the mirrored catalogue is queried after a pause and appends underneath. So a
/// search with no signal is not a degraded search — it is the same screen
/// missing its last section, which is the offline-first requirement stated as a
/// layout rather than as an error state.
///
/// **Three sections, in one order, and the order is the ticket.** *"Recent and
/// frequent foods surface above raw search results."* What somebody eats is a
/// set of about thirty things, and a catalogue of four hundred thousand rows
/// will always be able to bury one of them under a brand match. So the user's
/// own history is first, the rest of their phone is second, and the mirror is
/// third.
@MainActor
@Observable
final class FoodSearchModel {
    /// How long a pause counts as "stopped typing".
    ///
    /// 250 ms: long enough that a fast typist makes one request rather than
    /// eleven, short enough to feel like it answered while they were still
    /// looking at the box. It only ever delays the *third* section — the first
    /// two are already on screen — which is why it can afford to be this long.
    static let debounce = Duration.milliseconds(250)

    static let localLimit = 20
    static let remoteLimit = 25

    var query = ""

    private(set) var habitMatches: [FoodHabit] = []
    private(set) var localMatches: [Food] = []
    private(set) var remoteMatches: [CatalogueFood] = []
    private(set) var isSearching = false

    /// Set when the catalogue could not be reached. Renders as a note under the
    /// local results, never as an error — what is on screen is real and
    /// loggable, and saying "no connection" over the top of usable results is
    /// telling the user about a problem they do not have.
    private(set) var catalogueNote: String?

    private let foods: any FoodRepositoryProtocol
    private let catalogue: any FoodCatalogueProtocol
    private let now: () -> Date
    private var pending: Task<Void, Never>?

    init(
        foods: any FoodRepositoryProtocol,
        catalogue: any FoodCatalogueProtocol,
        now: @escaping () -> Date = { Date() }
    ) {
        self.foods = foods
        self.catalogue = catalogue
        self.now = now
    }

    // Deliberately no `deinit` cancelling `pending`. It is a `@MainActor`
    // stored property and a `deinit` is nonisolated, which Swift 6 rightly
    // refuses — the same note `SessionController` carries. The task holds
    // `self` weakly and returns on its next resume, so there is nothing to
    // clean up.

    /// True when there is nothing at all to show for a query that was typed.
    var isEmptyResult: Bool {
        !trimmed.isEmpty && !isSearching
            && habitMatches.isEmpty && localMatches.isEmpty && remoteMatches.isEmpty
    }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Called on every keystroke.
    ///
    /// The local half runs synchronously and the remote half is scheduled, so
    /// the two sections that can answer instantly always do.
    func queryChanged() {
        pending?.cancel()
        searchLocally()

        guard !trimmed.isEmpty else {
            remoteMatches = []
            isSearching = false
            catalogueNote = nil
            return
        }

        isSearching = true
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.searchCatalogue()
        }
    }

    /// Everything the phone already holds, ranked the way the ticket asks.
    private func searchLocally() {
        let text = trimmed
        guard !text.isEmpty else {
            habitMatches = []
            localMatches = []
            return
        }

        let habits = TeamSheet.habits(
            from: foods.recentLogs(since: now().addingTimeInterval(-TeamSheet.window), limit: 500)
        )
        habitMatches = habits
            .filter { $0.name.localizedCaseInsensitiveContains(text) }
            .sorted { lhs, rhs in
                lhs.appearances == rhs.appearances
                    ? lhs.lastLoggedAt > rhs.lastLoggedAt
                    : lhs.appearances > rhs.appearances
            }

        // Anything already surfaced as a habit is not repeated below it.
        let named = Set(habitMatches.map(\.name.localizedLowercase))
        localMatches = foods
            .foods(matching: text, limit: Self.localLimit)
            .filter { !named.contains($0.name.localizedLowercase) }
    }

    private func searchCatalogue() async {
        let text = trimmed
        defer { isSearching = false }

        do {
            let results = try await catalogue.search(text, limit: Self.remoteLimit)
            // The query moved on while this was in flight. Dropping the answer
            // is right: showing results for a string the user has already
            // finished editing is worse than showing none.
            guard text == trimmed else { return }

            let known = Set(localMatches.map(\.id))
            remoteMatches = results.filter { !known.contains($0.id) }
            catalogueNote = nil
        } catch let error as CatalogueError {
            guard text == trimmed else { return }
            remoteMatches = []
            catalogueNote = error.errorDescription
        } catch {
            guard text == trimmed else { return }
            remoteMatches = []
            catalogueNote = CatalogueError.unavailable.errorDescription
        }
    }
}
