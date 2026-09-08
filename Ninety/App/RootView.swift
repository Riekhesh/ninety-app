import SwiftData
import SwiftUI

/// What the app shows, decided by who is signed in and what they have agreed to.
///
/// Four screens, one per state, and the order is not arbitrary: nothing reaches
/// the tabs until there is a user id to key rows on *and* an Article 9 consent
/// recorded against it. A tracker that logs a meal before either exists has
/// written a row nobody owns.
struct RootView: View {
    let session: SessionController

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                LaunchHold()
            case .unconfigured, .signedOut:
                SignInView(session: session)
            case .signedIn(let userID):
                SignedInView(userID: userID, session: session)
            }
        }
        .task { await session.start() }
    }
}

/// The moment between launch and knowing. Deliberately not a spinner.
///
/// In the common case — no stored session — this is gone before it draws. When
/// it does show, it is the launch screen continuing rather than a new screen
/// appearing, which is why it is the masthead and the pitch and nothing else:
/// there is nothing true to say yet, and `DESIGN.md` rules out inventing
/// something to fill the space.
struct LaunchHold: View {
    var body: some View {
        Screen(title: PreSeasonCopy.signInTitle) { EmptyView() }
            .accessibilityLabel(PreSeasonCopy.launchLabel)
    }
}

/// Signed in, and gated — on consent, then on age, then on Pre-Season.
///
/// Four states in a fixed order, and the order is the argument. Nothing reaches
/// the tabs until there is a user id to key rows on, an Article 9 consent
/// recorded against it, an adult behind it, and the values the §10 gates read.
/// A tracker that logs a meal before all four exists has written a row nobody
/// owns, on a lawful basis nobody gave, for someone it should not be serving,
/// against a band it could not compute.
///
/// The gate reads the profile row rather than anything carried over from the
/// sign-in. A reinstall is a returning user with an empty phone, and once P1-I
/// drains the outbox their consent comes back from the server rather than being
/// asked for a second time — a second timestamp for a decision already made is
/// a worse record than one.
///
/// **Until P1-I, that is a design and not yet a behaviour.** The consent write
/// lands in SwiftData and in `sync_outbox`, and nothing sends it anywhere, so a
/// reinstall today does ask again. Recorded here rather than in a commit
/// message because the comment above would otherwise read as a claim about what
/// the code does.
private struct SignedInView: View {
    let userID: UUID
    let session: SessionController

    @Environment(\.modelContext)
    private var context

    /// Which gate the app is currently standing behind.
    ///
    /// Computed from the store, never advanced by a screen reporting success:
    /// every one of these re-reads the row it depends on, so a write that did
    /// not land leaves the user in front of the gate rather than past it.
    private enum Gate: Equatable {
        case consent
        /// §10 S4. A hard stop, and there is no transition out of it — the date
        /// of birth is on the profile, so this is recomputed and reached again
        /// on every launch.
        case blockedByAge
        case preSeason
        case playing
    }

    @State private var gate: Gate = .consent

    /// Built once and kept for the length of the flow. Rebuilding it per render
    /// would reset the step every time a field changed.
    ///
    /// Created in `refresh()` rather than lazily from `body`: assigning to
    /// `@State` while a view is being evaluated is the "Modifying state during
    /// view update" warning, and it is a warning about a real bug — the frame
    /// that triggered it renders against the old value.
    @State private var onboarding: OnboardingModel?

    private var repositories: Repositories {
        .live(context: context, userID: userID)
    }

    private var recorder: ConsentRecorder {
        ConsentRecorder(profiles: repositories.profile, userID: userID)
    }

    var body: some View {
        Group {
            switch gate {
            case .consent:
                ConsentView(
                    recorder: recorder,
                    onContinue: refresh,
                    onSignOut: { Task { await session.signOut() } }
                )
            case .blockedByAge:
                AgeGateView(onSignOut: { Task { await session.signOut() } })
            case .preSeason:
                if let onboarding {
                    OnboardingView(
                        model: onboarding,
                        onFinished: refresh,
                        onSignOut: { Task { await session.signOut() } }
                    )
                } else {
                    // Unreachable in practice — `refresh` sets both together —
                    // and the launch hold rather than nothing, because a blank
                    // screen is the one state with no explanation for itself.
                    LaunchHold()
                }
            case .playing:
                MainTabView(
                    repositories: repositories,
                    recorder: recorder,
                    onConsentChanged: refresh,
                    onSignOut: { Task { await session.signOut() } }
                )
            }
        }
        // Re-read on every appearance and on a change of user. Held in state
        // rather than computed in `body` so the gate is not a SwiftData fetch
        // per render — and read through `onAppear` rather than `task`, whose
        // closure is `@Sendable` and so does not inherit the view's isolation.
        .onAppear(perform: refresh)
        .onChange(of: userID) {
            onboarding = nil
            refresh()
        }
    }

    private func refresh() {
        let profiles = repositories.profile

        guard recorder.status.allowsHealthProcessing else {
            gate = .consent
            return
        }

        if let dob = profiles.current()?.dob,
           AgeGate.outcome(dob: dob, on: Date(), calendar: .current) == .blocked {
            gate = .blockedByAge
            return
        }

        if OnboardingModel.isComplete(profiles: profiles, weights: repositories.weight) {
            onboarding = nil
            gate = .playing
            return
        }

        if onboarding == nil {
            onboarding = OnboardingModel(
                profiles: profiles,
                weights: repositories.weight,
                userID: userID
            )
        }
        gate = .preSeason
    }
}

/// The navigation shell: three tabs over one shared pitch.
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

    /// Withdrawing consent from Settings has to reach the gate, not just the
    /// sheet. The shell re-reads the row and puts the consent screen back up.
    var onConsentChanged: () -> Void

    var onSignOut: () -> Void

    @State private var destination: Destination = .matchday
    @State private var isSubbingOn = false
    @State private var isShowingSettings = false
    @State private var features = CompetitiveFeatures(isOptedOut: false)
    @State private var calibration: CalibrationState?

    var body: some View {
        TabView(selection: $destination) {
            Tab(Destination.matchday.title, systemImage: Destination.matchday.symbol, value: .matchday) {
                MatchdayView(
                    subOn: { isSubbingOn = true },
                    openSettings: { isShowingSettings = true }
                )
            }
            Tab(Destination.theRun.title, systemImage: Destination.theRun.symbol, value: .theRun) {
                TheRunView()
            }
            if features.showsTheTable {
                Tab(Destination.theTable.title, systemImage: Destination.theTable.symbol, value: .theTable) {
                    TheTableView(calibration: calibration)
                }
            }
        }
        .tint(Ninety.Colour.accent)
        .sheet(isPresented: $isSubbingOn) {
            SubOnSheet()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                recorder: recorder,
                profiles: repositories.profile,
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

#Preview("Launch hold") {
    LaunchHold()
}
#endif
