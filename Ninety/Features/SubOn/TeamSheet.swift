import Foundation

/// The Squad and the Bench, worked out from the user's own logs.
///
/// **The whole of the ticket's claim about speed lives here, and there is no
/// algorithm in it.** Most people rotate through roughly thirty distinct foods;
/// putting the frequent ones and the recent ones above a search box makes
/// logging feel dramatically faster than the incumbents without anything clever
/// happening — because for most meals the answer is already on the screen and
/// the fastest search is the one nobody types.
///
/// Pure, and separate from the repository, for the usual reason: this is the
/// part with a rule in it, and a rule that can only be exercised through a store
/// is a rule nobody writes the third test for.
enum TeamSheet {
    /// How far back a habit counts from. Thirty days is about a rotation: long
    /// enough that a weekly meal still appears, short enough that a food dropped
    /// two months ago stops taking up a row.
    static let window: TimeInterval = 30 * 24 * 60 * 60

    /// The Squad's entry price. **Twice, not once** — a food logged one time is
    /// recent, not frequent, and letting it into the Squad makes the two lists
    /// the same list with different headings.
    static let squadThreshold = 2

    /// One food, its count and its last portion, from a set of logs.
    ///
    /// Grouped on `nameSnapshot`. See `FoodHabit` for why the name is the key
    /// and not the food id — a quick-add by calories has no food row at all,
    /// and it still has to reach the team sheet.
    static func habits(from logs: [FoodLog]) -> [FoodHabit] {
        var order: [String] = []
        var grouped: [String: [FoodLog]] = [:]

        for log in logs {
            let key = log.nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(log)
        }

        return order.compactMap { key in
            guard
                let entries = grouped[key],
                // `max(by:)` rather than `first`: the caller's sort is a
                // contract this would otherwise silently depend on, and a
                // repository that changed its ordering would move every
                // portion on the team sheet without failing anything.
                let latest = entries.max(by: { $0.loggedAt < $1.loggedAt })
            else { return nil }

            return FoodHabit(
                name: key,
                appearances: entries.count,
                lastLoggedAt: latest.loggedAt,
                grams: latest.grams,
                kcal: latest.kcal,
                foodID: latest.food?.id
            )
        }
    }

    /// The Squad: what you eat most, most-logged first.
    ///
    /// Ties break on recency, so two foods on nine appearances put the one you
    /// ate this morning above the one you ate three weeks ago.
    static func squad(from habits: [FoodHabit], limit: Int) -> [FoodHabit] {
        Array(
            habits
                .filter { $0.appearances >= squadThreshold }
                .sorted { lhs, rhs in
                    lhs.appearances == rhs.appearances
                        ? lhs.lastLoggedAt > rhs.lastLoggedAt
                        : lhs.appearances > rhs.appearances
                }
                .prefix(limit)
        )
    }

    /// On the Bench: what you ate recently and do not eat often, newest first.
    ///
    /// Everything the Squad took is excluded rather than repeated. A row that
    /// appears twice on one screen is a row the user has to read twice to find
    /// out it is the same thing.
    static func bench(from habits: [FoodHabit], excluding squad: [FoodHabit], limit: Int) -> [FoodHabit] {
        let taken = Set(squad.map(\.id))
        return Array(
            habits
                .filter { !taken.contains($0.id) }
                .sorted { $0.lastLoggedAt > $1.lastLoggedAt }
                .prefix(limit)
        )
    }
}
