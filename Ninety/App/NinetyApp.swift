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

    init() {
        TabBarStyle.apply()
        BrandFont.verify()
        do {
            container = try ModelContainer.ninety()
        } catch {
            Log.app.critical("Could not open the local store: \(error.localizedDescription, privacy: .public)")
            fatalError("Local store unavailable: \(error)")
        }
        Log.app.info("Ninety launched.")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
