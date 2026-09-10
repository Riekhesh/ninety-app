import SwiftUI

/// The navigation shell: three tabs over one shared pitch.
///
/// **Moved out of `RootView.swift` in P1-I**, and not as a tidy-up: that file
/// crossed the 400-line limit when the sync service was threaded through it,
/// and `--strict` is a failed build. The split follows a seam the file already
/// had — `RootView` and `SignedInView` decide *which screen*, and this decides
/// *what the tabs are* once that question is settled. P1-G split
/// `SwiftDataWeightRepository` off the same limit for the same reason, and
/// recorded the wrong fix there: trimming comments until the number comes down.
///
/// The pitch is drawn per screen by `Screen`, not once here: a `TabView` child
/// can be handed an opaque system background, and a root background that a
/// screen might silently cover is worse than one drawn where it is used. Every
/// screen draws it at the same origin, so the floodlight lands in the same
/// place on all three and a tab change reads as turning a page.
///
/// **The Table is conditional now** (§10 S6). The competitive opt-out takes the
/// rank surface away and leaves everything else exactly as it was — logging, the
/// weight trend, Apple Health — which is the half of the requirement that makes
/// it an opt-out rather than a threat. `CompetitiveFeatures` holds both halves.
struct MainTabView: View {
    let repositories: Repositories
    let recorder: ConsentRecorder

    /// P1-F's two network dependencies. Both are optional in effect — the
    /// catalogue degrades to what the phone holds, and a nil estimator turns the
    /// photo route into a screen that says why it is not available — because
    /// three of the four logging routes must work with no signal at all.
    let catalogue: any FoodCatalogueProtocol
    let estimator: (any MealEstimating)?

    /// P1-G's second weight route. Optional for the same reason as the other
    /// two: a device without a health store still gets the whole of The Run,
    /// because manual entry is the route that has to work with nothing at all.
    let bodyMass: (any BodyMassSourcing)?

    /// P1-I. Read by exactly one surface — the sync panel in Settings — and
    /// nudged by one more, the Sub On sheet closing. Nothing on any of the three
    /// tabs waits on it or branches on it, which is §04's rule stated as a
    /// dependency graph rather than as a comment.
    let sync: SyncService?

    /// Withdrawing consent from Settings has to reach the gate, not just the
    /// sheet. The shell re-reads the row and puts the consent screen back up.
    var onConsentChanged: () -> Void

    var onSignOut: () -> Void

    @State private var destination: Destination = .matchday
    @State private var isSubbingOn = false
    @State private var isShowingSettings = false
    @State private var features = CompetitiveFeatures(isOptedOut: false)
    @State private var calibration: CalibrationState?

    /// Bumped when Sub On closes, to tell Matchday to re-read the day.
    ///
    /// **A counter rather than a call, because there is nothing here to call.**
    /// `MatchdayView` owns its model in `@State`, so the instance this closure
    /// constructs on every render is discarded after the first one — which is
    /// the behaviour `TheRunModel` relies on and the reason neither model
    /// fetches in `init`. The dashboard is *behind* the sheet rather than
    /// replaced by it, so dismissing Sub On fires no `onAppear`, and a meal
    /// logged into a sheet over a stale band would show the old figure until the
    /// tab was left and come back to. One `Int` and one `onChange` is the whole
    /// of the fix.
    @State private var matchdayRefresh = 0

    var body: some View {
        TabView(selection: $destination) {
            Tab(Destination.matchday.title, systemImage: Destination.matchday.symbol, value: .matchday) {
                MatchdayView(
                    model: MatchdayModel(
                        foods: repositories.food,
                        profiles: repositories.profile,
                        weights: repositories.weight
                    ),
                    refreshToken: matchdayRefresh,
                    subOn: { isSubbingOn = true },
                    openSettings: { isShowingSettings = true }
                )
            }
            Tab(Destination.theRun.title, systemImage: Destination.theRun.symbol, value: .theRun) {
                TheRunView(
                    model: TheRunModel(
                        weights: repositories.weight,
                        profiles: repositories.profile,
                        health: bodyMass
                    )
                )
            }
            if features.showsTheTable {
                Tab(Destination.theTable.title, systemImage: Destination.theTable.symbol, value: .theTable) {
                    TheTableView(calibration: calibration)
                }
            }
        }
        .tint(Ninety.Colour.accent)
        // Closing Sub On is the moment a meal has just been logged, and the one
        // point in the app where a drain has something new to carry. Everything
        // else is a timer or an event; this is the write itself.
        //
        // It is also the moment Matchday has something new to show, and the two
        // are deliberately adjacent rather than entangled: the drain is asked to
        // run and the dashboard is asked to re-read, neither waits on the other,
        // and the screen would show the same figures with the radio off.
        .sheet(
            isPresented: $isSubbingOn,
            onDismiss: {
                sync?.requestDrain()
                matchdayRefresh += 1
            },
            content: {
                SubOnSheet(
                    repositories: repositories,
                    catalogue: catalogue,
                    estimator: estimator
                )
            }
        )
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                recorder: recorder,
                profiles: repositories.profile,
                sync: sync,
                onConsentChanged: onConsentChanged,
                onCompetitiveChanged: readCompetitiveState,
                onSignOut: onSignOut
            )
        }
        .onAppear {
            readCompetitiveState()
            calibration = CalibrationRecorder(profiles: repositories.profile)
                .state(on: Date(), calendar: .current)
        }
    }

    /// Reading the opt-out also has to move the user off a tab that is about to
    /// stop existing. `TabView` handed a selection with no matching tab shows
    /// nothing at all, and "the app went blank" is a worse first impression of
    /// the opt-out than anything the switch was meant to prevent.
    private func readCompetitiveState() {
        features = CompetitiveFeatures(profiles: repositories.profile)
        if !features.showsTheTable, destination == .theTable {
            destination = .matchday
        }
    }
}

// See the note in SignInView: these build DEBUG-only mocks.
#if DEBUG
@MainActor
private func previewShell() -> MainTabView {
    let user = UUID()
    let repositories = Repositories.mock(
        profile: MockProfileRepository(
            profile: Profile(id: user, termsAcceptedAt: .now, healthConsentAt: .now)
        )
    )
    return MainTabView(
        repositories: repositories,
        recorder: ConsentRecorder(profiles: repositories.profile, userID: user),
        catalogue: MockFoodCatalogue(),
        estimator: MockMealEstimator(),
        bodyMass: MockBodyMassSource(),
        sync: nil,
        onConsentChanged: {},
        onSignOut: {}
    )
}

#Preview("Shell · dark") {
    previewShell().preferredColorScheme(.dark)
}

#Preview("Shell · light") {
    previewShell().preferredColorScheme(.light)
}

#Preview("Shell · accessibility 5") {
    previewShell().dynamicTypeSize(.accessibility5)
}
#endif
