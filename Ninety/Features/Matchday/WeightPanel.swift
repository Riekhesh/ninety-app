import Charts
import SwiftUI

/// The weight trend, compressed to a glance.
///
/// **One implementation of the trend, two renderings of it.** The ticket asks
/// for this in as many words — *"shares the trend calculation with The Run"* —
/// and ADR 0020 is why it is worth stating: the series smooths calendar days
/// rather than readings, and a second implementation that got that wrong would
/// be invisible on the data of anybody who weighs in daily. `WeightTrend` is the
/// one place the average is computed; this draws `[TrendPoint]` and nothing else.
///
/// **The headline is the smoothed value** (§1.5). There is no raw-readings
/// toggle here and there should not be: the toggle exists on The Run because a
/// user's own measurements are theirs to look at, and it resets to off every time
/// that screen appears. A glance panel with a way to turn the harmful version on
/// would be the same setting in a second place, which is how it stops resetting.
///
/// **Four states, and the sparse ones are designed rather than defaulted.**
/// `TrendReadiness` distinguishes no readings, one, a handful and a week, and
/// this reads it — a line drawn through two points a fortnight apart looks
/// exactly like a line drawn through twenty and says far less.
struct WeightPanel: View {
    let readiness: TrendReadiness
    let points: [TrendPoint]
    let latestKg: Double?
    let changeOverFourWeeks: Double?

    /// Grows with the type. A fixed-height plot at `.accessibility5` is a plot
    /// with the figure above it pushed off the panel.
    @ScaledMetric(relativeTo: .body)
    private var plotHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            SectionHeading(title: MatchdayCopy.weightHeading)

            switch readiness {
            case .noReadings:
                empty(MatchdayCopy.weightEmpty, MatchdayCopy.weightEmptyDetail)
            case .oneReading:
                headline
                Text(MatchdayCopy.weightOneReading)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            case .building, .ready:
                headline
                sparkline
            }
        }
        .chalkPanel(padding: Ninety.Space.lg)
        .accessibilityElement(children: .contain)
    }

    private func empty(_ headline: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xs) {
            Text(headline)
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.textPrimary)
            Text(detail)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var headline: some View {
        if let latestKg {
            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.sm) {
                Text(TheRunCopy.kilograms(latestKg))
                    .ninetyType(.metricM)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Spacer(minLength: Ninety.Space.sm)
                comparison
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The comparison slot `design/spec/02-components.md` §4 makes mandatory: a
    /// stat with nothing to compare against yet says so rather than disappearing.
    @ViewBuilder private var comparison: some View {
        if let change = changeOverFourWeeks {
            // `textSecondary` on every value, in both directions. §10 S3 caps
            // the rate of loss, so a screen that paints a fast four weeks green
            // is an incentive pulling against the cap — and there is no punitive
            // colour for the other direction either, which is S5.
            Text(TheRunCopy.signed(change))
                .ninetyType(.metricS)
                .foregroundStyle(Ninety.Colour.textSecondary)
        } else {
            Text(MatchdayCopy.weightNeedsAWeek)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }

    /// The same series The Run plots, with the axes taken off.
    ///
    /// No grid, no labels, no reference line: this is the shape of four weeks,
    /// and the figure that matters is the text above it. `chartLine` rather than
    /// the accent, for the reason the full chart uses it — the accent means
    /// interactive, and a line you cannot tap is not.
    private var sparkline: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Trend", point.trendKg)
                )
                .foregroundStyle(Ninety.Colour.chartLine)
                .lineStyle(StrokeStyle(lineWidth: Ninety.Border.focus, lineCap: .round))
                .interpolationMethod(.monotone)
            }

            if let last = points.last {
                PointMark(
                    x: .value("Day", last.day),
                    y: .value("Trend", last.trendKg)
                )
                .foregroundStyle(Ninety.Colour.accent)
                .symbolSize(40)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: plotHeight)
        // Hidden rather than described: everything this shape says is already on
        // the panel as text, and a per-point audio graph of a smoothed weight
        // series is twenty-eight near-identical numbers.
        .accessibilityHidden(true)
    }
}
