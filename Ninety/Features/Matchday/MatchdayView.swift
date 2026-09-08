import SwiftUI

/// The daily driver.
///
/// P1-A builds the frame only. The band, the pitch meter, Form, the weight
/// sparkline and the team sheet are P1‑H, and each arrives with the real data
/// behind it rather than as a styled placeholder.
///
/// **The masthead control is S6's two-tap requirement.** §10 asks for the
/// competitive opt-out to be reachable in at most two taps from this screen, and
/// §1.6 caps the app at three tabs — so Settings can be neither a fourth tab nor
/// three taps deep. One glyph here, one switch there.
struct MatchdayView: View {
    /// Presents Sub On. Owned by the shell because logging is an action that
    /// returns you here, not a place you navigate to.
    var subOn: () -> Void

    /// Presents Settings, and with it the opt-out, the signposting, consent
    /// withdrawal and signing out.
    var openSettings: () -> Void

    var body: some View {
        Screen(
            title: Destination.matchday.title,
            meta: "No day started",
            accessory: { SettingsButton(action: openSettings) }
        ) {
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

/// The one control the masthead carries.
///
/// A system glyph rather than an authored chalk one: it has to hold at every
/// size class and at accessibility sizes, which is the same reason the tab bar
/// uses SF Symbols. Its label names what is behind it rather than the icon —
/// "settings" is what a screen reader user is looking for, and §10 requires the
/// support signposting inside to be findable.
struct SettingsButton: View {
    var action: () -> Void

    /// 44pt is Apple's minimum tap target and a glyph does not reach it on its
    /// own.
    @ScaledMetric(relativeTo: .title3)
    private var target: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .ninetyType(.title3)
                .foregroundStyle(Ninety.Colour.textTertiary)
                .frame(minWidth: target, minHeight: target, alignment: .trailing)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings, support and your consent")
    }
}

#Preview("Matchday") {
    MatchdayView(subOn: {}, openSettings: {})
}

#Preview("Matchday · accessibility 5") {
    MatchdayView(subOn: {}, openSettings: {}).dynamicTypeSize(.accessibility5)
}
