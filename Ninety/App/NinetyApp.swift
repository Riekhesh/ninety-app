import SwiftData
import SwiftUI

@main
struct NinetyApp: App {
    /// Opened once, at launch, and handed to the view tree.
    ///
    /// Not `try?` with a fallback to an in-memory store: a store that silently
    /// becomes ephemeral looks like a working app right up to the moment the
    /// user reopens it and a day of logging has gone. Once the 21-day clock is
    /// running that is the most expensive bug in the project, so it fails
    /// loudly here instead.
    private let container: ModelContainer

    /// Built once, at launch, because the SDK client behind it holds the
    /// Keychain session and the background refresh timer — a second one would
    /// be a second refresh loop racing the first.
    ///
    /// Nil configuration is not a crash. A clone without `Config/Local.xcconfig`
    /// has no Supabase project in it, and the app still runs and says so on the
    /// sign-in screen; a `fatalError` here would make a fresh checkout
    /// unlaunchable to punish a configuration mistake.
    @State private var session: SessionController

    /// Nil on a clone with no `Config/Local.xcconfig`. Everything that needs the
    /// network takes it as an optional and has a designed answer for nil, which
    /// is what keeps a fresh checkout runnable.
    private let stack: SupabaseStack?

    /// One path monitor for the process, for the same reason there is one
    /// Supabase client: it is a system resource with a callback queue behind it,
    /// and a second one would be a second set of notifications about the same
    /// radio. Handed down rather than reached for, so the sync service can be
    /// built with a stub in a test.
    private let connectivity = PathConnectivity()

    init() {
        TabBarStyle.apply()
        BrandFont.verify()
        do {
            container = try ModelContainer.ninety()
        } catch {
            Log.app.critical("Could not open the local store: \(error.localizedDescription, privacy: .public)")
            fatalError("Local store unavailable: \(error)")
        }

        let configuration = SupabaseConfiguration.fromBundle()
        if configuration == nil {
            Log.auth.error("No Supabase project in this build; Config/Local.xcconfig is not filled in.")
        }
        // One client for the whole process. See `SupabaseStack` for why a
        // second one would be a second refresh loop over one session.
        let stack = configuration.map { SupabaseStack(configuration: $0) }
        self.stack = stack
        let service: (any AuthServiceProtocol)? = stack.map { SupabaseAuthService(stack: $0) }
        _session = State(initialValue: SessionController(service: service))

        Log.app.info("Ninety launched.")
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, stack: stack, connectivity: connectivity)
        }
        .modelContainer(container)
    }
}
