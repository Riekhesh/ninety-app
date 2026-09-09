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

/// One logged meal, as a fixture.
///
/// A struct rather than a four-member tuple, and not only because SwiftLint says
/// so: `entry.2` for "kcal" is exactly how a fixture quietly starts asserting
/// against the wrong number, and the two numbers here are both `Double`s that
/// mean different things.
struct SampleLog {
    let name: String
    let grams: Double
    let kcal: Double
    /// How long before the fixture's "now" this was eaten.
    let hoursAgo: Double

    func made(for userID: UUID, endingAt end: Date) -> FoodLog {
        FoodLog(
            userID: userID,
            loggedAt: end.addingTimeInterval(-hoursAgo * 3_600),
            grams: grams,
            entryMethod: .manual,
            kcal: kcal,
            nameSnapshot: name
        )
    }
}

extension [SampleLog] {
    func logs(for userID: UUID, endingAt end: Date) -> [FoodLog] {
        map { $0.made(for: userID, endingAt: end) }
    }
}

/// A week of plausible logs, for the team sheet.
///
/// The counts are what make the Squad and the Bench different lists: the flat
/// white and the porridge repeat, the rest do not.
enum PreviewLogs {
    static func week(userID: UUID, endingAt end: Date) -> [FoodLog] {
        [
            SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 5),
            SampleLog(name: "Porridge & semi-skimmed", grams: 250, kcal: 320, hoursAgo: 10),
            SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 29),
            SampleLog(name: "Chicken salad bowl", grams: 380, kcal: 545, hoursAgo: 34),
            SampleLog(name: "Porridge & semi-skimmed", grams: 250, kcal: 320, hoursAgo: 58),
            SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 53),
            SampleLog(name: "Greek yogurt & berries", grams: 170, kcal: 233, hoursAgo: 79),
            SampleLog(name: "Sourdough toast & butter", grams: 90, kcal: 280, hoursAgo: 108),
            SampleLog(name: "Flat white", grams: 220, kcal: 120, hoursAgo: 125),
        ]
        .logs(for: userID, endingAt: end)
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
