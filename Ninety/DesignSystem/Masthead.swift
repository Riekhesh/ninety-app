import SwiftUI

/// The top of every screen: kit stripes, the screen's name in the broadcast
/// voice, and one line of context on the right.
///
/// It replaces a navigation title rather than sitting under one — a large title
/// in San Francisco above a chalk masthead would read as two competing headers.
/// The screen name is still exposed as a heading to VoiceOver, so the structure
/// a sighted user sees and the one a screen reader hears are the same.
///
/// **The accessory is the only control the masthead will ever hold**, and it
/// exists for one reason: S6 requires the competitive opt-out to be reachable in
/// at most two taps from Matchday, and §1.6 caps the app at three tabs — so
/// Settings cannot be a fourth tab and cannot be three taps deep. A single glyph
/// at the trailing edge is the cheapest thing that satisfies both. Anything else
/// that wants to live up here belongs in the content instead.
struct Masthead<Accessory: View>: View {
    let title: String

    /// The right-hand caption — the date, the matchweek, a count. Optional
    /// because a screen with nothing true to say there says nothing.
    let meta: String?

    /// One control at the trailing edge, or nothing at all. `EmptyView` by
    /// default, so the screens that do not want one read exactly as they did.
    let accessory: Accessory

    @Environment(\.dynamicTypeSize)
    private var typeSize

    /// Grows with the masthead beside it, so the club device does not shrink
    /// to a speck at accessibility sizes.
    @ScaledMetric(relativeTo: .title3)
    private var stripeHeight: CGFloat = 19

    init(
        title: String,
        meta: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.meta = meta
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xs) {
            if typeSize.isAccessibilitySize {
                stacked
            } else {
                inline
            }
        }
        .padding(.bottom, Ninety.Space.sm)
        .chalkRule()
    }

    /// Default: one line, meta and the accessory pushed to the trailing edge.
    private var inline: some View {
        HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
            name
            Spacer(minLength: Ninety.Space.sm)
            if let meta {
                Text(meta)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }
            accessory
        }
    }

    /// At accessibility sizes the caption drops under the name instead of
    /// competing with it for a line that is no longer wide enough for both.
    ///
    /// The accessory stays on the name's line. It is a fixed-size glyph rather
    /// than text, so it does not grow into the space the caption needed — and
    /// dropping it below would put a control between the heading and its
    /// caption, which reads as belonging to neither.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
                name
                Spacer(minLength: Ninety.Space.sm)
                accessory
            }
            if let meta {
                Text(meta)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    private var name: some View {
        HStack(spacing: Ninety.Space.sm + Ninety.Space.xs) {
            KitStripes(height: stripeHeight)
            Text(title)
                .ninetyType(.masthead)
                .foregroundStyle(Ninety.Colour.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

#Preview("Masthead") {
    VStack(spacing: Ninety.Space.xxxl) {
        Masthead(title: "Matchday", meta: "Mon 3 Aug · MW 32")
        Masthead(title: "The Table")
    }
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
}

#Preview("Masthead · accessibility 5") {
    Masthead(title: "Matchday", meta: "Mon 3 Aug · MW 32")
        .padding(Ninety.Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Pitch())
        .dynamicTypeSize(.accessibility5)
}
