import Foundation
import Testing
@testable import Ninety

/// P1-F Path 1 and Path 2 — search and barcode.
///
/// The property under test in almost every case is the same one: **the phone
/// answers first.** A search with no signal is not a degraded search, it is the
/// same screen missing its last section, and a barcode the phone has seen before
/// never touches the network at all.
@Suite("Search and barcode")
@MainActor
struct FoodSearchTests {
    static func food(_ name: String, kcal: Double = 100, barcode: String? = nil) -> Food {
        Food(source: .custom, createdBy: UUID(), barcode: barcode, name: name, kcalPer100g: kcal)
    }

    static func log(_ name: String, hoursAgo: TimeInterval, from now: Date) -> FoodLog {
        FoodLog(
            userID: UUID(),
            loggedAt: now.addingTimeInterval(-hoursAgo * 3_600),
            grams: 100,
            entryMethod: .manual,
            kcal: 200,
            nameSnapshot: name
        )
    }

    /// The debounce is real time, so a test that waits for it has to wait for
    /// slightly more than it. Two of them, which is short enough not to slow the
    /// suite and long enough not to be flaky on a loaded machine.
    static let settle = Duration.milliseconds(600)

    // MARK: - Ordering

    /// *"Recent and frequent foods surface above raw search results."* What
    /// somebody eats is a set of about thirty things, and a catalogue of four
    /// hundred thousand rows will always be able to bury one of them under a
    /// brand match.
    @Test("what you eat comes above what is on the phone, which comes above the catalogue")
    func historyOutranksTheCatalogue() async {
        let now = Date()
        let foods = MockFoodRepository(
            logs: [
                Self.log("Greek yogurt & berries", hoursAgo: 2, from: now),
                Self.log("Greek yogurt & berries", hoursAgo: 26, from: now),
            ],
            catalogue: [Self.food("Greek yogurt, own brand")],
            now: now
        )
        let catalogue = MockFoodCatalogue()
        let model = FoodSearchModel(foods: foods, catalogue: catalogue, now: { now })

        model.query = "greek"
        model.queryChanged()

        // The two local sections answered synchronously, before anything was
        // asked of the network.
        #expect(model.habitMatches.map(\.name) == ["Greek yogurt & berries"])
        #expect(model.localMatches.map(\.name) == ["Greek yogurt, own brand"])
        #expect(catalogue.searches.isEmpty)

        try? await Task.sleep(for: Self.settle)
        #expect(!catalogue.searches.isEmpty)
        #expect(model.remoteMatches.contains { $0.name.contains("Greek") })
    }

    @Test("a food already on the phone is not repeated as a habit and a food")
    func localResultsDoNotRepeatHabits() {
        let now = Date()
        let foods = MockFoodRepository(
            logs: [Self.log("Porridge", hoursAgo: 1, from: now), Self.log("Porridge", hoursAgo: 25, from: now)],
            catalogue: [Self.food("Porridge")],
            now: now
        )
        let model = FoodSearchModel(
            foods: foods,
            catalogue: MockFoodCatalogue(foods: []),
            now: { now }
        )

        model.query = "porridge"
        model.queryChanged()

        #expect(model.habitMatches.count == 1)
        #expect(model.localMatches.isEmpty)
    }

    // MARK: - Offline

    /// *"Works with no signal against a local cache of the user's own food
    /// set."*
    @Test("with no signal the local sections still answer and the note is calm")
    func offlineStillAnswers() async throws {
        let now = Date()
        let foods = MockFoodRepository(
            logs: [Self.log("Flat white", hoursAgo: 1, from: now)],
            catalogue: [Self.food("Flat white")],
            now: now
        )
        let model = FoodSearchModel(
            foods: foods,
            catalogue: MockFoodCatalogue(failure: .offline),
            now: { now }
        )

        model.query = "flat"
        model.queryChanged()
        #expect(model.habitMatches.count == 1)

        try? await Task.sleep(for: Self.settle)
        #expect(model.remoteMatches.isEmpty)
        // The copy deck's offline line: reassuring, not a warning. What is above
        // it on screen is real and loggable.
        let note = try #require(model.catalogueNote)
        #expect(note == CatalogueError.offline.errorDescription)
        #expect(!note.lowercased().contains("error"))
        // And it is never an empty state — there are results, just not remote ones.
        #expect(!model.isEmptyResult)
    }

    @Test("an empty query asks nothing of anybody")
    func emptyQueryIsNotASearch() async {
        let now = Date()
        let catalogue = MockFoodCatalogue()
        let model = FoodSearchModel(foods: MockFoodRepository(now: now), catalogue: catalogue, now: { now })

        model.query = "   "
        model.queryChanged()

        try? await Task.sleep(for: Self.settle)
        #expect(catalogue.searches.isEmpty)
        #expect(!model.isSearching)
        #expect(!model.isEmptyResult)
    }

    /// A search box that fires per keystroke makes eleven requests for one word.
    /// The debounce is why the third section is the only one that ever waits.
    @Test("typing quickly produces one request, not one per keystroke")
    func typingIsDebounced() async {
        let now = Date()
        let catalogue = MockFoodCatalogue()
        let model = FoodSearchModel(foods: MockFoodRepository(now: now), catalogue: catalogue, now: { now })

        for text in ["p", "po", "por", "porr", "porri", "porrid", "porridg", "porridge"] {
            model.query = text
            model.queryChanged()
        }

        try? await Task.sleep(for: Self.settle)
        #expect(catalogue.searches == ["porridge"])
    }

    @Test("a query with no match anywhere reaches the empty state")
    func noMatchAnywhere() async {
        let now = Date()
        let model = FoodSearchModel(
            foods: MockFoodRepository(now: now),
            catalogue: MockFoodCatalogue(foods: []),
            now: { now }
        )
        model.query = "quinoa salad"
        model.queryChanged()

        try? await Task.sleep(for: Self.settle)
        #expect(model.isEmptyResult)
        #expect(SubOnCopy.noMatch(for: "quinoa salad") == "No match for \"quinoa salad\"")
    }

    // MARK: - Barcode

    /// *"Scan resolves against the mirrored Open Food Facts data."*
    @Test("a scanned barcode resolves against the mirror")
    func barcodeResolvesAgainstTheMirror() async throws {
        let catalogue = MockFoodCatalogue()
        let found = try await catalogue.food(barcode: "5000169005286")
        let resolved = try #require(found)
        #expect(resolved.name == "Greek style natural yogurt")
        #expect(resolved.source == .off)
    }

    /// *"Unknown barcode falls back to manual search rather than dead-ending,
    /// and offers to save as a custom food."*
    @Test("an unknown barcode is a nil rather than a failure")
    func unknownBarcodeIsAValue() async throws {
        let catalogue = MockFoodCatalogue()
        // Most of Open Food Facts is European; a barcode genuinely absent from
        // the mirror is the common case, not an error state.
        let missing = try await catalogue.food(barcode: "0000000000000")
        #expect(missing == nil)
    }

    @Test("a barcode the phone has already seen never reaches the network")
    func knownBarcodeIsAnsweredLocally() {
        let foods = MockFoodRepository(catalogue: [Self.food("Baked beans", barcode: "5000157024671")])
        let local = foods.food(withBarcode: "5000157024671")
        #expect(local?.name == "Baked beans")
        #expect(foods.food(withBarcode: "0000000000000") == nil)
    }

    /// The offer after a miss carries the barcode forward, which is what makes
    /// the *second* scan of the same tin a local hit.
    @Test("saving after a miss keeps the barcode")
    func customFoodKeepsTheBarcode() throws {
        let foods = MockFoodRepository()
        let saved = try foods.saveFood(
            FoodDraft(source: .custom, barcode: "5000157024671", name: "Baked beans", kcalPer100g: 78)
        )
        #expect(saved.barcode == "5000157024671")
        #expect(saved.source == .custom)
        #expect(saved.createdBy != nil)
        #expect(foods.food(withBarcode: "5000157024671")?.id == saved.id)
    }

    /// A catalogue row belongs to nobody. Setting `created_by` on one would make
    /// the insert policy reject it as a custom food somebody else already owns —
    /// the check constraint in migration 001 says the same thing.
    @Test("a cached catalogue row has no owner")
    func cachedCatalogueRowsHaveNoOwner() throws {
        let foods = MockFoodRepository()
        let cached = try foods.saveFood(CatalogueFood.samples[0].draft)
        #expect(cached.source == .off)
        #expect(cached.createdBy == nil)
    }

    @Test("caching the same catalogue row twice keeps one copy")
    func cachingIsIdempotent() throws {
        let foods = MockFoodRepository()
        let first = try foods.saveFood(CatalogueFood.samples[0].draft)
        let second = try foods.saveFood(CatalogueFood.samples[0].draft)
        #expect(first.id == second.id)
        #expect(foods.catalogue.count == 1)
    }
}
