import SwiftUI

/// What a screen says before the thing it is for exists.
///
/// Deliberately not a spinner, a skeleton or a grey rectangle: those imply the
/// content is arriving in a moment. This states plainly what the surface will
/// hold and what has to land first, because the alternative — inventing a
/// number so the layout looks finished — is the one thing the design principles
/// rule out outright. Real content or an honest sentence; never lorem.
struct HoldingNote: View {
    /// The broadcast micro-label. Names the slot, not the state.
    let eyebrow: String

    /// One sentence, in the product's voice.
    let headline: String

    /// Why it is not here yet, and what is true in the meantime.
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text(eyebrow)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)

            Text(headline)
                .ninetyType(.title3)
                .foregroundStyle(Ninety.Colour.textPrimary)

            Text(detail)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)
        }
        .chalkPanel(padding: Ninety.Space.lg)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Holding note") {
    HoldingNote(
        eyebrow: "Division",
        headline: "Ranking arrives in the next update.",
        detail: "There is no division yet because there is no fortnight of logs to work one out from."
    )
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
}
