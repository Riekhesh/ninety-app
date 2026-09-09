import Foundation
import Observation

/// The confirm-and-correct screen, as state.
///
/// **This type is the safety gate**, and it is a gate in the structural sense
/// rather than the copy sense: `confirm(...)` is the only method on it that
/// writes, nothing else on the photo route can reach a repository, and it cannot
/// be called with an empty sheet. So *"no estimate reaches `food_logs` without
/// an explicit confirmation"* is a property of the type rather than a habit of
/// whoever wrote the view.
///
/// §1.3 is why the screen is mandatory rather than a setting: trained dietitians
/// misestimate portions by 20–30% and vision models do worse, so an estimate
/// accepted silently is a number the app is presenting as a fact when it knows
/// better. Owning that loudly is the better product, and ADR 0010's amendment
/// says it in as many words — *"the photo estimate is always presented as a
/// helper, never as truth"*.
@MainActor
@Observable
final class UnderReviewModel {
    /// How much one tap moves a portion.
    ///
    /// Two steps rather than a percentage, because this is a control somebody
    /// taps four times in a row and a step that changes size as they do is one
    /// they cannot aim. Ten grams above 50 g, five below — so a 170 g yoghurt
    /// and an 18 g drizzle both take a sensible number of taps.
    static func step(forGrams grams: Double) -> Double { grams >= 50 ? 10 : 5 }

    let estimate: MealEstimate

    /// The sheet as it currently stands. Starts as the model's items at their
    /// midpoints and is what `confirm` writes.
    private(set) var items: [EstimatedItem]

    /// True once something has been written. The button reads it and cannot be
    /// pressed twice — a double tap on a slow phone would otherwise log the
    /// meal twice, and the second copy is indistinguishable from a real one.
    private(set) var isConfirmed = false
    private(set) var writeFailed = false

    private let calendar: Calendar
    private let now: () -> Date

    init(
        estimate: MealEstimate,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.estimate = estimate
        self.items = estimate.items
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Derived

    /// What the model said the meal was, as a figure and a tolerance.
    var estimatedTotal: EstimateRange {
        EstimateRange(
            low: items.reduce(0) { $0 + $1.kcal.low },
            high: items.reduce(0) { $0 + $1.kcal.high }
        )
    }

    /// What is about to be logged.
    var confirmedKcal: Double { items.reduce(0) { $0 + $1.confirmedKcal } }

    /// Nothing to give a decision about. The screen says so and offers a retake
    /// and manual entry, rather than a button that logs nothing.
    var isEmpty: Bool { items.isEmpty }

    /// True if the user moved anything at all — including removing an item or
    /// adding one the model missed.
    var wasCorrected: Bool {
        items.contains(where: \.wasCorrected) || items.count != estimate.items.count
    }

    // MARK: - Correcting

    /// One tap up or down. The energy follows the portion at the model's own
    /// density; see `EstimatedItem.adjust(toGrams:)` for why it is not re-derived
    /// from a food table.
    func nudge(_ id: EstimatedItem.ID, up: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let step = Self.step(forGrams: items[index].confirmedGrams)
        items[index].adjust(toGrams: items[index].confirmedGrams + (up ? step : -step))
    }

    /// A typed portion. Same write path as the taps, so both record a correction.
    func setGrams(_ grams: Double, for id: EstimatedItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].adjust(toGrams: grams)
    }

    func remove(_ id: EstimatedItem.ID) {
        items.removeAll { $0.id == id }
    }

    /// Something the model missed. Recorded as a correction against an estimate
    /// of zero rather than logged separately — see `EstimatedItem.added`.
    func add(name: String, grams: Double, kcal: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, kcal > 0 else { return }
        items.append(EstimatedItem.added(name: trimmed, grams: grams, kcal: kcal))
    }

    // MARK: - The decision

    /// Writes one `food_logs` row per item, each with its own
    /// `photo_estimates` row alongside it.
    ///
    /// **Per item rather than per meal**, and that is the shape the benchmark
    /// wants: `spikes/vision-accuracy` scores per food — its ground-truth CSV is
    /// one row per item — so a single meal-level delta would not be scoreable
    /// against it. The photo path and the model's whole output are repeated on
    /// each row, which costs a few kilobytes and makes every row re-scoreable on
    /// its own.
    ///
    /// `wasCorrected` and `correctionDelta` are written **every** time,
    /// including when nothing moved. A dataset that only records corrections
    /// cannot tell "the model was right" from "nobody looked", and that
    /// distinction is the whole value of the set.
    @discardableResult
    func confirm(using model: SubOnModel) -> Bool {
        guard !isConfirmed, !items.isEmpty else { return false }
        let moment = now()

        for item in items {
            let draft = FoodLogDraft(
                food: nil,
                // The schema requires grams > 0, and an item the user zeroed
                // out is one they meant to remove. One gram rather than a
                // refusal: the row is about the energy, and blocking the whole
                // meal on it would be the screen arguing about a rounding.
                grams: max(item.confirmedGrams, 1),
                kcal: item.confirmedKcal,
                name: item.name,
                entryMethod: .photo,
                loggedAt: moment
            )
            let record = PhotoEstimateDraft(
                storagePath: estimate.storagePath,
                modelOutput: estimate.rawOutput,
                confidence: item.confidence?.ordinal,
                wasCorrected: item.wasCorrected,
                correctionDelta: item.correctionDelta
            )
            guard model.log(draft, estimate: record) != nil else {
                writeFailed = true
                return false
            }
        }

        isConfirmed = true
        writeFailed = false
        return true
    }
}
