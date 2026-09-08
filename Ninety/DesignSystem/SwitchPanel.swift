import SwiftUI

/// A decision the user can take and untake: what it is, what it does, and a
/// switch that records it on the spot.
///
/// Not a new component — a system `Toggle` inside a chalk panel, which is what
/// `design/spec/02-components.md` means by leaving switches off the component
/// list. It is a shared type rather than a copy per screen because the same
/// shape now carries three different §10 obligations, and they have to keep
/// behaving identically:
///
/// - **Article 9 consent** (ADR 0017) — terms and health data, on the consent
///   screen and again in Settings, where withdrawal has to be as easy as giving.
/// - **S6's competitive opt-out** — reversible, history preserved.
///
/// The switch is the control, not a button that opens a confirmation. Consent
/// that takes two taps to withdraw and one to give is not freely given, and an
/// opt-out behind a confirmation dialogue is one the user is being talked out of.
struct SwitchPanel: View {
    let heading: String

    /// Not `body`: `View` already owns that name on this type.
    let explainer: String

    /// The second paragraph, where a decision needs one. Nil is the common case.
    var detail: String?

    /// The switch's own label. It states the decision in the first person,
    /// because that is who is making it.
    let action: String

    let isOn: Bool

    /// Called on any change. Deliberately not a `Binding`: every one of these
    /// writes to a store and reads the result back rather than trusting local
    /// state, and a binding invites a screen to move its own toggle and find out
    /// later that the write failed.
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text(heading)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)

            Text(explainer)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

            if let detail {
                Text(detail)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }

            Toggle(action, isOn: Binding(get: { isOn }, set: { _ in toggle() }))
                .ninetyType(.callout)
                .tint(Ninety.Colour.accent)
        }
        .chalkPanel(padding: Ninety.Space.lg)
    }
}

#Preview("Switch panel") {
    VStack(spacing: Ninety.Space.xl) {
        SwitchPanel(
            heading: "Competitive features",
            explainer: """
                Turns off tiers, ranks and scores. Logging, your weight trend and Apple Health \
                sync all keep working exactly as they do now.
                """,
            action: "Turn off competitive features",
            isOn: false,
            toggle: {}
        )

        SwitchPanel(
            heading: "Health data",
            explainer: "Special category data under UK GDPR.",
            detail: "Withdrawing stops Ninety processing anything new.",
            action: "I consent to Ninety processing my health data",
            isOn: true,
            toggle: {}
        )
    }
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
}
