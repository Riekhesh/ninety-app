import Foundation
import SwiftData

/// A food in the catalogue. Mirrors `public.foods`.
///
/// Locally this holds the user's own custom entries plus whatever the search
/// route has cached; the full Open Food Facts and USDA mirror lives in Postgres
/// and is queried, not copied to the phone.
@Model
final class Food {
    @Attribute(.unique)
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var sourceRaw: String
    /// Set only for custom foods. Nil for the shared catalogue, which belongs
    /// to nobody — the same distinction the Postgres policies key on.
    var createdBy: UUID?

    var barcode: String?
    var name: String
    var brand: String?

    var kcalPer100g: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?

    init(
        id: UUID = UUID(),
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast,
        source: FoodSource,
        createdBy: UUID? = nil,
        barcode: String? = nil,
        name: String,
        brand: String? = nil,
        kcalPer100g: Double,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceRaw = source.rawValue
        self.createdBy = createdBy
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.kcalPer100g = kcalPer100g
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}

extension Food {
    var source: FoodSource {
        get { FoodSource(rawValue: sourceRaw) ?? .custom }
        set { sourceRaw = newValue.rawValue }
    }

    /// Energy for a portion. Rounded, because §1.2 is explicit that hitting
    /// exactly 1,847 kcal is not a real human goal — and a decimal place on a
    /// calorie count is false precision the lint rules also refuse.
    func kcal(forGrams grams: Double) -> Double {
        (kcalPer100g * grams / 100).rounded()
    }
}
