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
        let service: (any AuthServiceProtocol)? = configuration.map {
            SupabaseAuthService(configuration: $0)
        }
        _session = State(initialValue: SessionController(service: service))

        Log.app.info("Ninety launched.")
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
        .modelContainer(container)
    }
}
