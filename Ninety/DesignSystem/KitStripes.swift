import SwiftUI

/// The club device: three vertical bars, gold–chalk–gold.
///
/// It appears beside every masthead and nowhere else. That restraint is what
/// makes it read as a crest rather than as decoration — and it is the one mark
/// that identifies the app at a glance in a screenshot.
struct KitStripes: View {
    /// Bar height. Scales with the masthead it stands beside, so the device
    /// does not shrink into a speck at accessibility sizes.
    var height: CGFloat

    private var barWidth: CGFloat { max(2, height * 0.16) }

    var body: some View {
        HStack(spacing: Ninety.Space.hair) {
            Rectangle().fill(Ninety.Colour.accent)
            Rectangle().fill(Ninety.Colour.textPrimary)
            Rectangle().fill(Ninety.Colour.accent)
        }
        .frame(width: barWidth * 3 + Ninety.Space.hair * 2, height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Ninety.Space.lg) {
        KitStripes(height: 19)
        KitStripes(height: 32)
    }
    .padding()
    .background(Ninety.Colour.canvas)
}
