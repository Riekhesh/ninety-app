import Foundation

/// What a catalogue row implies once you say how much of it you ate.
///
/// **This type exists because its absence was writing wrong numbers.** The
/// portion screen used to put `100` in the grams field and `kcal_per_100g` in
/// the calories field, and then log whatever was in the calories field — so
/// changing the portion to 200 g logged 200 g of food at 100 g of energy,
/// silently, with nothing on screen suggesting anything was wrong. Half a meal,
/// into the twenty-one days the entire ranking engine is designed against.
///
/// `Food.kcal(forGrams:)` already existed and was already tested. The screen
/// simply never called it. So the arithmetic now lives in a type of its own,
/// with its own tests, rather than inside a view where the only thing checking
/// it is whoever is reading the code.
struct PortionBasis: Equatable, Sendable {
    /// Per 100 g, which is the unit the catalogue stores and the only one a
    /// food row actually knows.
    let kcalPer100g: Double
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?

    /// Nil when there is nothing to scale from.
    ///
    /// A food with no energy figure is not a basis, it is a name — the manual
    /// route handles that case by asking for both numbers, and a basis of zero
    /// would quietly derive zero calories for every portion.
    init?(_ draft: FoodDraft) {
        guard draft.kcalPer100g > 0 else { return nil }
        kcalPer100g = draft.kcalPer100g
        proteinPer100g = draft.proteinG
        carbsPer100g = draft.carbsG
        fatPer100g = draft.fatG
    }

    init(kcalPer100g: Double, proteinPer100g: Double? = nil, carbsPer100g: Double? = nil, fatPer100g: Double? = nil) {
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
    }

    /// The portion, worked out.
    func scaled(toGrams grams: Double) -> ScaledPortion {
        let factor = max(grams, 0) / 100
        return ScaledPortion(
            // Rounded, because §1.2 rules out a decimal place on a calorie
            // figure and `no_false_precision_kcal` catches the formatted version.
            kcal: (kcalPer100g * factor).rounded(),
            // Macros keep one decimal: 0.4 g of fat in a coffee is a real
            // difference at the scale macros are read at, and rounding it to
            // zero would be the opposite mistake from the calorie one.
            proteinG: Self.macro(proteinPer100g, factor),
            carbsG: Self.macro(carbsPer100g, factor),
            fatG: Self.macro(fatPer100g, factor)
        )
    }

    private static func macro(_ per100g: Double?, _ factor: Double) -> Double? {
        per100g.map { ($0 * factor * 10).rounded() / 10 }
    }
}

/// One portion's worth of numbers.
struct ScaledPortion: Equatable, Sendable {
    let kcal: Double
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
}
