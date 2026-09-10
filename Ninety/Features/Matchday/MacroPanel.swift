import SwiftUI

/// Protein, carbs and fat, from the day's logs.
///
/// **It says what it is a total of.** Macros live on the `foods` row a log points
/// at, and three of the four logging routes can produce a log with no such row —
/// a quick add by calories has none by construction, a photo estimate has none,
/// and a catalogue row can be deleted underneath a log that already happened. So
/// a macro total over a real day is usually a total over part of that day, and
/// this panel puts the coverage on the panel rather than in a footnote. A number
/// that silently covered three of five items would be the false-precision
/// failure the design principles rule out, made quieter.
///
/// **The split is a bar, not a chart.** Three values that always sum to the whole
/// have exactly one interesting property — their proportions — and a bar shows
/// that in the width the panel already has. The grams are underneath it as text,
/// because the proportion is the glance and the figure is the answer.
struct MacroPanel: View {
    let macros: MacroTotals

    /// Grows with the type. Everything on this screen does.
    @ScaledMetric(relativeTo: .body)
    private var barHeight: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            SectionHeading(title: MatchdayCopy.macrosHeading, detail: coverage)

            if macros.isEmpty {
                // Honest rather than zeroed. Three `0 g` figures would read as a
                // day with no protein in it, which is a claim the app cannot
                // make from the rows it holds.
                Text(MatchdayCopy.macrosEmpty)
                    .ninetyType(.callout)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Text(MatchdayCopy.macrosEmptyDetail)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            } else {
                bar
                figures
            }
        }
        .chalkPanel(padding: Ninety.Space.lg)
        .accessibilityElement(children: .contain)
    }

    /// `From 3 of 5 items`, or nothing to say when it covered all of them.
    private var coverage: String? {
        guard macros.totalLogs > 0 else { return nil }
        return macros.isComplete
            ? MatchdayCopy.macrosComplete
            : MatchdayCopy.macrosFrom(covered: macros.coveredLogs, total: macros.totalLogs)
    }

    private var bar: some View {
        GeometryReader { proxy in
            HStack(spacing: Ninety.Border.focus) {
                ForEach(Macro.allCases) { macro in
                    Rectangle()
                        .fill(tint(for: macro))
                        .frame(width: max(proxy.size.width * macros.share(of: macro), 0))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: barHeight)
        .accessibilityHidden(true)
    }

    /// The three figures, wrapping rather than truncating: three labels and
    /// three gram counts in a row do not fit across a phone at accessibility
    /// sizes, and a macro whose name is cut in half is worse than one on its own
    /// line.
    private var figures: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Ninety.Space.lg) { keys }
            VStack(alignment: .leading, spacing: Ninety.Space.sm) { keys }
        }
    }

    @ViewBuilder private var keys: some View {
        ForEach(Macro.allCases) { macro in
            HStack(spacing: Ninety.Space.sm) {
                Rectangle()
                    .fill(tint(for: macro))
                    .frame(width: barHeight, height: barHeight)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                    Text(macro.title)
                        .ninetyType(.label)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                    Text(MatchdayCopy.grams(macros.grams(of: macro)))
                        .ninetyType(.metricS)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(macro.title): \(MatchdayCopy.grams(macros.grams(of: macro)))")
        }
    }

    /// **Not three new colours.** `design/spec/02-components.md` caps the
    /// component set and the token set has one accent for a reason — gold is the
    /// division's, and spending it three ways here would cost the rank reveal its
    /// meaning. So the three read as one material at three weights, which is also
    /// what makes the bar legible in both appearances without a legend.
    private func tint(for macro: Macro) -> Color {
        switch macro {
        case .protein: Ninety.Colour.accent
        case .carbs: Ninety.Colour.textSecondary
        case .fat: Ninety.Colour.stroke
        }
    }
}
