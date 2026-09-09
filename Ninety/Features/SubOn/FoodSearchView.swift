import SwiftUI

/// Path 1 — search.
///
/// Three sections in a fixed order: what you eat, what is on this phone, and the
/// mirrored catalogue. The first two answer on every keystroke and the third
/// answers after a pause, so the screen is never waiting on the network to show
/// something loggable. See `FoodSearchModel` for why that order is the ticket
/// rather than a preference.
struct FoodSearchView: View {
    let model: SubOnModel

    @State private var search: FoodSearchModel

    @Environment(\.dismiss)
    private var dismiss

    init(model: SubOnModel, catalogue: any FoodCatalogueProtocol) {
        self.model = model
        _search = State(
            initialValue: FoodSearchModel(foods: model.foods, catalogue: catalogue)
        )
    }

    var body: some View {
        Screen(title: SubOnCopy.searchRoute, meta: model.period.title) {
            VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                NinetyField(
                    label: SubOnCopy.searchPlaceholder,
                    unit: nil,
                    value: $search.query,
                    keyboard: .default
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                        habits
                        onThisPhone
                        results
                        emptyState
                    }
                    .padding(.bottom, Ninety.Space.xxl)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onChange(of: search.query) { search.queryChanged() }
    }

    // MARK: - Sections

    @ViewBuilder private var habits: some View {
        if !search.habitMatches.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                SectionHeading(title: SubOnCopy.squadHeading, detail: SubOnCopy.squadDetail)
                ForEach(search.habitMatches) { habit in
                    FoodRow(
                        name: habit.name,
                        detail: "\(Figure.grams(habit.grams)) · \(SubOnCopy.appearances(habit.appearances))",
                        kcal: habit.kcal
                    ) {
                        model.log(habit)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder private var onThisPhone: some View {
        if !search.localMatches.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                SectionHeading(title: SubOnCopy.yourFoodsHeading)
                ForEach(search.localMatches) { food in
                    FoodRow(
                        name: food.name,
                        detail: subtitle(brand: food.brand, kcalPer100g: food.kcalPer100g),
                        kcal: food.kcalPer100g
                    ) {
                        model.portion = PortionPrefill(
                            food: FoodDraft(
                                id: food.id,
                                source: food.source,
                                barcode: food.barcode,
                                name: food.name,
                                brand: food.brand,
                                kcalPer100g: food.kcalPer100g,
                                proteinG: food.proteinG,
                                carbsG: food.carbsG,
                                fatG: food.fatG
                            ),
                            entryMethod: .search
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder private var results: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            if !search.remoteMatches.isEmpty {
                SectionHeading(title: SubOnCopy.resultsHeading)
                ForEach(search.remoteMatches) { food in
                    FoodRow(
                        name: food.name,
                        detail: subtitle(brand: food.brand, kcalPer100g: food.kcalPer100g),
                        kcal: food.kcalPer100g
                    ) {
                        // Cached on the way past, so the next search finds it
                        // with no signal at all. This is how "works offline
                        // against a local cache of the user's own food set"
                        // becomes true over a week of use rather than on day one.
                        model.cache(food)
                        model.portion = PortionPrefill(food: food.draft, entryMethod: .search)
                    }
                }
            }

            if search.isSearching {
                Text(SubOnCopy.searchingNote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }

            if let note = search.catalogueNote {
                // A note, never a banner. What is above it is real and
                // loggable, and a warning over usable results tells the user
                // about a problem they do not have.
                Text(note)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if search.isEmptyResult {
            VStack(alignment: .leading, spacing: Ninety.Space.md) {
                Text(SubOnCopy.noMatch(for: search.query))
                    .ninetyType(.title3)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Text(SubOnCopy.catalogueNote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
                Button(SubOnCopy.addItManually) {
                    model.portion = PortionPrefill(
                        food: FoodDraft(
                            source: .custom,
                            name: search.query.trimmingCharacters(in: .whitespacesAndNewlines),
                            kcalPer100g: 0
                        ),
                        // Nothing in the catalogue matched, so nothing but the
                        // user found this food. `manual` is what happened.
                        entryMethod: .manual
                    )
                }
                .buttonStyle(.primary)
            }
            .chalkPanel(padding: Ninety.Space.lg)
        }
    }

    /// "Alpro · 47 kcal / 100 g". Per-100 g rather than a portion, because that
    /// is what the catalogue actually knows — inventing a serving size would be
    /// inventing a number.
    private func subtitle(brand: String?, kcalPer100g: Double) -> String {
        let energy = "\(Figure.kcal(kcalPer100g)) kcal / 100 g"
        guard let brand, !brand.isEmpty else { return energy }
        return "\(brand) · \(energy)"
    }
}
