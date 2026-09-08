#if DEBUG
import Foundation

/// Mocks and fixtures for the logging routes.
///
/// `#if DEBUG` so none of it can reach a release build, and in one file so the
/// previews and the tests share the same fixtures — a preview built on
/// different numbers from the tests is a preview of something nobody checked.

/// A catalogue that answers from a fixed list.
///
/// Deliberately has a `delay` and a `failure`, because the two states worth
/// looking at on the search screen are "the network is slow" and "there is no
/// network", and neither is reachable from a mock that always answers instantly.
@MainActor
final class MockFoodCatalogue: FoodCatalogueProtocol {
    var foods: [CatalogueFood]
    var failure: CatalogueError?
    var delay: Duration = .zero
    private(set) var searches: [String] = []
    private(set) var barcodeLookups: [String] = []

    init(foods: [CatalogueFood] = CatalogueFood.samples, failure: CatalogueError? = nil) {
        self.foods = foods
        self.failure = failure
    }

    func search(_ query: String, limit: Int) async throws -> [CatalogueFood] {
        searches.append(query)
        if delay > .zero { try? await Task.sleep(for: delay) }
        if let failure { throw failure }
        return Array(
            foods.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(limit)
        )
    }

    func food(barcode: String) async throws -> CatalogueFood? {
        barcodeLookups.append(barcode)
        if delay > .zero { try? await Task.sleep(for: delay) }
        if let failure { throw failure }
        return foods.first { $0.barcode == barcode }
    }
}

extension CatalogueFood {
    /// Real products with real label figures, so a preview shows something a
    /// person could have eaten rather than "Food 1".
    static let samples: [CatalogueFood] = [
        CatalogueFood(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID(),
            source: .off,
            barcode: "5000169005286",
            name: "Greek style natural yogurt",
            brand: "Waitrose",
            kcalPer100g: 133,
            proteinG: 5.7,
            carbsG: 4.5,
            fatG: 10.2
        ),
        CatalogueFood(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2") ?? UUID(),
            source: .off,
            barcode: "5011026101010",
            name: "Porridge oats",
            brand: "Quaker",
            kcalPer100g: 356,
            proteinG: 11.0,
            carbsG: 60.0,
            fatG: 8.0
        ),
        CatalogueFood(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3") ?? UUID(),
            source: .usda,
            barcode: nil,
            name: "Blueberries, raw",
            brand: nil,
            kcalPer100g: 57,
            proteinG: 0.7,
            carbsG: 14.5,
            fatG: 0.3
        ),
    ]
}

/// A week of plausible logs, for the team sheet.
///
/// The counts are what make the Squad and the Bench different lists: the flat
/// white and the porridge repeat, the rest do not.
enum PreviewLogs {
    static func week(userID: UUID, endingAt end: Date) -> [FoodLog] {
        let day: TimeInterval = 24 * 60 * 60
        let entries: [(String, Double, Double, Double)] = [
            ("Flat white", 220, 120, 0.2),
            ("Porridge & semi-skimmed", 250, 320, 0.4),
            ("Flat white", 220, 120, 1.2),
            ("Chicken salad bowl", 380, 545, 1.4),
            ("Porridge & semi-skimmed", 250, 320, 2.4),
            ("Flat white", 220, 120, 2.2),
            ("Greek yogurt & berries", 170, 233, 3.3),
            ("Sourdough toast & butter", 90, 280, 4.5),
            ("Flat white", 220, 120, 5.2),
        ]
        return entries.map { name, grams, kcal, daysAgo in
            FoodLog(
                userID: userID,
                loggedAt: end.addingTimeInterval(-daysAgo * day),
                grams: grams,
                entryMethod: .manual,
                kcal: kcal,
                nameSnapshot: name
            )
        }
    }
}

/// `SubOnModel` is `@MainActor`, so this extension's members inherit the
/// isolation and need no attribute of their own.
extension SubOnModel {
    /// A model over the preview fixtures. Built fresh each time — a shared one
    /// would carry state between previews and show the second one a log the
    /// first one made.
    static var preview: SubOnModel {
        let user = UUID()
        let now = Date()
        return SubOnModel(
            foods: MockFoodRepository(logs: PreviewLogs.week(userID: user, endingAt: now), userID: user),
            profiles: MockProfileRepository(
                profile: Profile(
                    id: user,
                    dob: Calendar.current.date(byAdding: .year, value: -32, to: now),
                    heightCm: 178,
                    sex: .male,
                    activityLevel: .moderate,
                    goalType: .lose,
                    goalWeightKg: 76,
                    targetRateKgPerWeek: 0.5,
                    termsAcceptedAt: now,
                    healthConsentAt: now
                )
            ),
            weights: MockWeightRepository(
                logs: [WeightLog(userID: user, measuredAt: now, kg: 84, source: .manual)]
            )
        )
    }
}
#endif
