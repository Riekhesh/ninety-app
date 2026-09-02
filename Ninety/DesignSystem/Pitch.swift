import SwiftUI

/// The ground every screen stands on: a lit pitch, not a dark app painted green.
///
/// Two layers, both derived from tokens so light mode is the same world at
/// midday rather than an inversion:
///
///   · **Mow stripes** — vertical bands at the width a real mower leaves.
///   · **The floodlight** — one source, thrown from the top-left gantry. One
///     light, not an ambient wash: it is what makes the surface read as lit
///     rather than tinted.
struct Pitch: View {
    /// One mow stripe. A constant rather than a spacing token because it is a
    /// property of the drawing, not a layout decision — nothing is aligned to it.
    private static let stripeWidth: CGFloat = 49

    @Environment(\.colorScheme)
    private var scheme

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        Ninety.Colour.canvas
            .overlay(alignment: .topLeading) { stripes }
            .overlay(alignment: .topLeading) { floodlight }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private var stripes: some View {
        GeometryReader { proxy in
            let count = Int((proxy.size.width / Self.stripeWidth).rounded(.up)) + 1
            HStack(spacing: 0) {
                ForEach(Array(0..<max(count, 1)), id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? Color.clear : stripeInk)
                        .frame(width: Self.stripeWidth)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// A single ellipse, off-canvas top-left, faded to nothing well before the
    /// opposite corner. Reduce Transparency drops it: the canvas colour alone
    /// still carries the world, and a gradient wash is exactly what that
    /// setting exists to remove.
    @ViewBuilder private var floodlight: some View {
        if !reduceTransparency {
            EllipticalGradient(
                colors: [
                    Ninety.Colour.textPrimary.opacity(scheme == .dark ? 0.10 : 0.05),
                    Ninety.Colour.textPrimary.opacity(0),
                ],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.7
            )
            .frame(width: 500, height: 460)
            .offset(x: -90, y: -180)
            .blendMode(scheme == .dark ? .plusLighter : .multiply)
        }
    }

    /// Light mode needs a firmer stripe: the same alpha over a near-white
    /// canvas is invisible, and the mow pattern is the world's signature.
    private var stripeInk: Color {
        Ninety.Colour.chartGrid.opacity(scheme == .dark ? 0.5 : 0.9)
    }
}

#Preview("Pitch · dark") {
    Pitch().preferredColorScheme(.dark)
}

#Preview("Pitch · light") {
    Pitch().preferredColorScheme(.light)
}
