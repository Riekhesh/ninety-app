import SwiftUI

/// Rank as a league table — the screen the whole project exists for.
///
/// It is empty on purpose and stays empty for the whole of Phase 1. The
/// ranking maths is Phase 2 (ADR 0006), and a division badge showing an
/// invented score would be the exact false-precision failure the design
/// principles rule out. `Packages/RankingEngine` is scaffolded now only so the
/// purity lint rules have a boundary to police from day one.
struct TheTableView: View {
    var body: some View {
        Screen(title: Destination.theTable.title) {
            VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                HoldingNote(
                    eyebrow: "Division",
                    headline: "Ranking arrives in the next update.",
                    detail: """
                        There is no division yet because there is no fortnight of logs \
                        to work one out from. Ninety ranks on how much you improve \
                        against your own baseline, so it needs a baseline first.
                        """
                )
                weights
            }
        }
    }

    /// The weights are published from day one even though nothing computes
    /// them yet. They are the thesis stated plainly, and a rank whose workings
    /// only appear once it is flattering is not a fair rank.
    private var weights: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text("How it will be scored")
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)

            ForEach(Self.weighting) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.name)
                        .ninetyType(.subhead)
                        .foregroundStyle(Ninety.Colour.textSecondary)
                    Spacer(minLength: Ninety.Space.md)
                    Text(row.weight)
                        .ninetyType(.metricS)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }

            Text(
                """
                Consistency counts double because showing up predicts results better \
                than any single week does — and it's the part you control.
                """
            )
            .ninetyType(.footnote)
            .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }

    /// The published weighting (§2.2). A struct rather than a tuple because
    /// `ForEach` needs a stable identity and Swift has no key paths into tuples.
    private struct Weighting: Identifiable {
        let name: String
        let weight: String
        var id: String { name }
    }

    private static let weighting = [
        Weighting(name: "Consistency", weight: "0.50"),
        Weighting(name: "Adherence", weight: "0.25"),
        Weighting(name: "Progress", weight: "0.25"),
    ]
}

#Preview("The Table") {
    TheTableView()
}

#Preview("The Table · light") {
    TheTableView().preferredColorScheme(.light)
}

#Preview("The Table · accessibility 5") {
    TheTableView().dynamicTypeSize(.accessibility5)
}
