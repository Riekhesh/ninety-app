import SwiftUI

/// Rank as a league table — the screen the whole project exists for.
///
/// It is empty on purpose and stays empty for the whole of Phase 1. The
/// ranking maths is Phase 2 (ADR 0006), and a division badge showing an
/// invented score would be the exact false-precision failure the design
/// principles rule out. `Packages/RankingEngine` is scaffolded now only so the
/// purity lint rules have a boundary to police from day one.
struct TheTableView: View {
    /// Where the calibration window stands, or nil before there is a profile to
    /// ask about. Passed in rather than read here: the recorder writes when the
    /// window closes, and a view that fetches and writes on every render is a
    /// view that writes more than once.
    var calibration: CalibrationState?

    var body: some View {
        Screen(title: Destination.theTable.title, meta: calibration?.chip) {
            VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                HoldingNote(
                    eyebrow: "Division",
                    headline: "Ranking arrives in the next update.",
                    detail: detail
                )
                weights
            }
        }
    }

    /// Two honest sentences, and which one is true depends on the window.
    ///
    /// **The calibrating state is not an empty leaderboard**, which is the
    /// story's acceptance criterion: an empty table implies a table that could
    /// have had rows in it. During calibration there is a countdown and a reason;
    /// afterwards there is still no rank in Phase 1, and the screen says that
    /// instead of inventing one (ADR 0006 — the maths is Phase 2).
    private var detail: String {
        if let calibration, case .calibrating(let remaining) = calibration {
            let days = remaining == 1 ? "day" : "days"
            return """
                Ninety is learning your baseline. \(remaining) \(days) of the first week \
                to go, and no division is assigned until it closes — a rank built on two \
                days of data would be meaningless.
                """
        }
        return """
            There is no division yet because the ranking maths lands in the next update. \
            Ninety ranks on how much you improve against your own baseline, so it needs a \
            baseline first.
            """
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

#Preview("The Table · calibrating") {
    TheTableView(calibration: .calibrating(daysRemaining: 6))
}

#Preview("The Table · calibration closed") {
    TheTableView(calibration: .closed(on: .now)).preferredColorScheme(.light)
}

#Preview("The Table · accessibility 5") {
    TheTableView(calibration: .calibrating(daysRemaining: 1))
        .dynamicTypeSize(.accessibility5)
}
