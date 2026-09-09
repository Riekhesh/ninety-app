import SwiftUI

/// Logging, as a sheet.
///
/// A sheet rather than a tab because logging a meal has a beginning and an end
/// and returns you to where you started — Apple's rule is that tabs are
/// sections, not actions. It keeps the app inside §1.6's three-tab cap without
/// spending one of the three on a control.
///
/// **The screen you land on is the team sheet, not a search box**, and that is
/// the ticket's whole claim about speed. Most people rotate through roughly
/// thirty distinct foods, so for most meals the answer is already on the screen
/// and the fastest search is the one nobody types. The four routes sit above it
/// for the meals where it is not.
struct SubOnSheet: View {
    @State private var model: SubOnModel
    private let catalogue: any FoodCatalogueProtocol
    private let estimator: (any MealEstimating)?

    @Environment(\.dismiss)
    private var dismiss

    init(
        repositories: Repositories,
        catalogue: any FoodCatalogueProtocol,
        estimator: (any MealEstimating)?
    ) {
        _model = State(
            initialValue: SubOnModel(
                foods: repositories.food,
                profiles: repositories.profile,
                weights: repositories.weight
            )
        )
        self.catalogue = catalogue
        self.estimator = estimator
    }

    var body: some View {
        NavigationStack {
            Screen(title: SubOnCopy.masthead, meta: model.period.title) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                        RouteChips(route: $model.route)

                        if model.writeFailed {
                            Text(SubOnCopy.writeFailed)
                                .ninetyType(.footnote)
                                .foregroundStyle(Ninety.Colour.safety)
                        }

                        if let logged = model.lastLogged {
                            LoggedStrip(
                                name: logged.nameSnapshot,
                                undo: model.undoLast,
                                dismiss: model.dismissUndo
                            )
                        }

                        squad
                        bench
                        roomLeft
                    }
                    .padding(.bottom, Ninety.Space.xxl)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationDestination(item: $model.route) { route in
                destination(for: route)
            }
            // Declared once, here, for the reason `SubOnModel.portion` gives:
            // two routes end on this screen and a stack may only be told about
            // a type once.
            .navigationDestination(item: $model.portion) { prefill in
                ManualEntryView(model: model, prefill: prefill)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SubOnCopy.close) { dismiss() }
                }
            }
            // Hidden rather than tinted: a filled bar above the masthead reads
            // as two competing headers. Close floats over the pitch instead.
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(Ninety.Colour.accent)
        .presentationDragIndicator(.visible)
        .onAppear(perform: model.refresh)
    }

    // MARK: - The team sheet

    @ViewBuilder private var squad: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            SectionHeading(title: SubOnCopy.squadHeading, detail: SubOnCopy.squadDetail)

            if model.squad.isEmpty {
                // A holding note rather than an empty box. `DESIGN.md`: never a
                // spinner or a skeleton where the answer is "there is nothing
                // yet" — say what the surface will hold and what has to land.
                HoldingNote(
                    eyebrow: SubOnCopy.squadHeading,
                    headline: SubOnCopy.emptySquadHeadline,
                    detail: SubOnCopy.emptySquad
                )
            } else {
                ForEach(model.squad) { habit in
                    FoodRow(
                        name: habit.name,
                        detail: detail(for: habit, showingCount: true),
                        kcal: habit.kcal,
                        badge: "\(habit.appearances)"
                    ) {
                        model.log(habit)
                    }
                }
            }
        }
    }

    @ViewBuilder private var bench: some View {
        if !model.bench.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                SectionHeading(title: SubOnCopy.benchHeading, detail: SubOnCopy.benchDetail)
                ForEach(model.bench) { habit in
                    FoodRow(
                        name: habit.name,
                        detail: detail(for: habit, showingCount: false),
                        kcal: habit.kcal
                    ) {
                        model.log(habit)
                    }
                }
            }
        }
    }

    /// "170 g · Yesterday" or "50 g · 9 apps". The portion first, because it is
    /// what the tap is about to repeat.
    private func detail(for habit: FoodHabit, showingCount: Bool) -> String {
        let portion = Figure.grams(habit.grams)
        if showingCount {
            return "\(portion) · \(SubOnCopy.appearances(habit.appearances))"
        }
        return "\(portion) · \(habit.lastLoggedAt.formatted(.relative(presentation: .named)))"
    }

    // MARK: - The band

    private var roomLeft: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            SectionHeading(title: SubOnCopy.roomLeft)

            if let band = model.band, let room = model.roomLeftKcal, let state = model.bandState {
                VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                    Text("\(Figure.kcal(room)) ±\(band.tolerance)")
                        .ninetyType(.metricL)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                    Text(state.label)
                        .ninetyType(.footnote)
                        .foregroundStyle(state.tone.colour)
                    if let note = state.note {
                        Text(note)
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.textTertiary)
                    }
                }
                .chalkPanel(padding: Ninety.Space.lg)
                .accessibilityElement(children: .combine)
            } else {
                Text(SubOnCopy.roomLeftUnknown)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    // MARK: - Routing

    @ViewBuilder
    private func destination(for route: SubOnModel.Route) -> some View {
        switch route {
        case .manual:
            ManualEntryView(model: model, prefill: nil)
        case .search:
            FoodSearchView(model: model, catalogue: catalogue)
        case .barcode:
            BarcodeRouteView(model: model, catalogue: catalogue)
        case .photo:
            PhotoRouteView(model: model, estimator: estimator)
        }
    }
}

#if DEBUG
@MainActor
private func previewSheet() -> some View {
    let user = UUID()
    let now = Date()
    let repositories = Repositories.mock(
        profile: MockProfileRepository(
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
        food: MockFoodRepository(logs: PreviewLogs.week(userID: user, endingAt: now), userID: user),
        weight: MockWeightRepository(logs: [WeightLog(userID: user, measuredAt: now, kg: 84, source: .manual)])
    )
    return SubOnSheet(
        repositories: repositories,
        catalogue: MockFoodCatalogue(),
        estimator: MockMealEstimator()
    )
}

#Preview("Sub On") {
    previewSheet()
}

#Preview("Sub On · light") {
    previewSheet().preferredColorScheme(.light)
}

#Preview("Sub On · accessibility 5") {
    previewSheet().dynamicTypeSize(.accessibility5)
}
#endif
