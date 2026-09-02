import SwiftUI

/// The daily driver.
///
/// P1-A builds the frame only. The band, the pitch meter, Form, the weight
/// sparkline and the team sheet are P1‑H, and each arrives with the real data
/// behind it rather than as a styled placeholder.
struct MatchdayView: View {
    /// Presents Sub On. Owned by the shell because logging is an action that
    /// returns you here, not a place you navigate to.
    var subOn: () -> Void

    var body: some View {
        Screen(title: Destination.matchday.title, meta: "No day started") {
            VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                HoldingNote(
                    eyebrow: "Today",
                    headline: "Nothing logged yet.",
                    detail: """
                        The band, the pitch and the team sheet land with P1‑H. \
                        Until then this screen is honest about being empty rather \
                        than filled with a number nobody measured.
                        """
                )
                subOnButton
            }
        }
    }

    private var subOnButton: some View {
        Button("Sub on", action: subOn)
            .buttonStyle(.primary)
            .accessibilityLabel("Sub on. Log food.")
    }
}

#Preview("Matchday") {
    MatchdayView(subOn: {})
}

#Preview("Matchday · accessibility 5") {
    MatchdayView(subOn: {}).dynamicTypeSize(.accessibility5)
}
