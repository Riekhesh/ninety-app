import SwiftUI

/// The navigation shell: three tabs over one shared pitch.
///
/// The pitch is drawn per screen by `Screen`, not once here: a `TabView` child
/// can be handed an opaque system background, and a root background that a
/// screen might silently cover is worse than one drawn where it is used. Every
/// screen draws it at the same origin, so the floodlight lands in the same
/// place on all three and a tab change reads as turning a page.
struct RootView: View {
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
    RootView().preferredColorScheme(.dark)
}

#Preview("Shell · light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Shell · accessibility 5") {
    RootView().dynamicTypeSize(.accessibility5)
}
