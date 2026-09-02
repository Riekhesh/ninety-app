import SwiftUI

/// The one action that moves a screen forward.
///
/// **One per screen, and it is the only gold-filled control in the app.** Gold
/// belongs to the division; spending it anywhere else costs the weekly rank
/// reveal the contrast it depends on.
///
/// Geometry from `design/spec/02-components.md`: height 50 — the 44pt minimum
/// tap target plus breathing room — `Radius.full`, and the label in the
/// broadcast voice the artboards set KICK OFF and GIVE THE DECISION in.
struct PrimaryButtonStyle: ButtonStyle {
    /// 44pt is the floor Apple sets; the spec adds six for the rest.
    private static let height: CGFloat = 50

    @Environment(\.isEnabled)
    private var isEnabled

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Grows with the label, so the pill does not clip its own text at
    /// accessibility sizes — the height is a minimum, never a fixed frame.
    @ScaledMetric(relativeTo: .headline)
    private var minimumHeight: CGFloat = height

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .ninetyType(.button)
            .foregroundStyle(isEnabled ? Ninety.Colour.textInverse : Ninety.Colour.textDisabled)
            .padding(.horizontal, Ninety.Space.xxl)
            .padding(.vertical, Ninety.Space.md)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .background(fill(pressed: configuration.isPressed))
            .ninetyCorners(Ninety.Radius.full)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                Ninety.Motion.animation(.easeOut(duration: Ninety.Motion.instant), reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }

    /// Disabled is the fill at 40%, never the only signal — anything that
    /// disables this button owes the user a sentence saying why.
    private func fill(pressed: Bool) -> Color {
        guard isEnabled else { return Ninety.Colour.accent.opacity(0.4) }
        return pressed ? Ninety.Colour.accentPressed : Ninety.Colour.accent
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

#Preview("Primary button") {
    VStack(spacing: Ninety.Space.xl) {
        Button("Sub on") {}
            .buttonStyle(.primary)

        Button("Kick off") {}
            .buttonStyle(.primary)
            .disabled(true)
    }
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
}

#Preview("Primary button · accessibility 5") {
    Button("Give the decision") {}
        .buttonStyle(.primary)
        .padding(Ninety.Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Pitch())
        .dynamicTypeSize(.accessibility5)
}
