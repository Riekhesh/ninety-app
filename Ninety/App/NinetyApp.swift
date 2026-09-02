import SwiftUI

@main
struct NinetyApp: App {
    init() {
        TabBarStyle.apply()
        BrandFont.verify()
        Log.app.info("Ninety launched.")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
