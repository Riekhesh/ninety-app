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

/// Signed in, and gated on consent.
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

    @State private var status: ConsentStatus = .none

    private var repositories: Repositories {
        .live(context: context, userID: userID)
    }

    private var recorder: ConsentRecorder {
        ConsentRecorder(profiles: repositories.profile, userID: userID)
    }

    var body: some View {
        Group {
            if status.allowsHealthProcessing {
                MainTabView()
            } else {
                ConsentView(
                    recorder: recorder,
                    onContinue: { status = recorder.status },
                    onSignOut: { Task { await session.signOut() } }
                )
            }
        }
        // Re-read on every appearance and on a change of user. Held in state
        // rather than computed in `body` so the gate is not a SwiftData fetch
        // per render — and read through `onAppear` rather than `task`, whose
        // closure is `@Sendable` and so does not inherit the view's isolation.
        .onAppear { status = recorder.status }
        .onChange(of: userID) { status = recorder.status }
    }
}

/// The navigation shell: three tabs over one shared pitch.
///
/// The pitch is drawn per screen by `Screen`, not once here: a `TabView` child
/// can be handed an opaque system background, and a root background that a
/// screen might silently cover is worse than one drawn where it is used. Every
/// screen draws it at the same origin, so the floodlight lands in the same
/// place on all three and a tab change reads as turning a page.
struct MainTabView: View {
    @State private var destination: Destination = .matchday
    @State private var isSubbingOn = false

    var body: some View {
        TabView(selection: $destination) {
            Tab(Destination.matchday.title, systemImage: Destination.matchday.symbol, value: .matchday) {
                MatchdayView(subOn: { isSubbingOn = true })
            }
            Tab(Destination.theRun.title, systemImage: Destination.theRun.symbol, value: .theRun) {
                TheRunView()
            }
            Tab(Destination.theTable.title, systemImage: Destination.theTable.symbol, value: .theTable) {
                TheTableView()
            }
        }
        .tint(Ninety.Colour.accent)
        .sheet(isPresented: $isSubbingOn) {
            SubOnSheet()
        }
    }
}

#Preview("Shell · dark") {
    MainTabView().preferredColorScheme(.dark)
}

#Preview("Shell · light") {
    MainTabView().preferredColorScheme(.light)
}

#Preview("Shell · accessibility 5") {
    MainTabView().dynamicTypeSize(.accessibility5)
}

#Preview("Launch hold") {
    LaunchHold()
}
