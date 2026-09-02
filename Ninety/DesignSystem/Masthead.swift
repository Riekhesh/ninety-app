import SwiftUI

/// The top of every screen: kit stripes, the screen's name in the broadcast
/// voice, and one line of context on the right.
///
/// It replaces a navigation title rather than sitting under one — a large title
/// in San Francisco above a chalk masthead would read as two competing headers.
/// The screen name is still exposed as a heading to VoiceOver, so the structure
/// a sighted user sees and the one a screen reader hears are the same.
struct Masthead: View {
    let title: String

    /// The right-hand caption — the date, the matchweek, a count. Optional
    /// because a screen with nothing true to say there says nothing.
    let meta: String?

    @Environment(\.dynamicTypeSize)
    private var typeSize

    /// Grows with the masthead beside it, so the club device does not shrink
    /// to a speck at accessibility sizes.
    @ScaledMetric(relativeTo: .title3)
    private var stripeHeight: CGFloat = 19

    init(title: String, meta: String? = nil) {
        self.title = title
        self.meta = meta
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

    /// Default: one line, meta pushed to the trailing edge.
    private var inline: some View {
        HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
            name
            if let meta {
                Spacer(minLength: Ninety.Space.sm)
                Text(meta)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }
        }
    }

    /// At accessibility sizes the caption drops under the name instead of
    /// competing with it for a line that is no longer wide enough for both.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            name
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
