import Charts
import SwiftUI

/// The trend, drawn.
///
/// `design/spec/02-components.md` §6 is the container spec and this is the first
/// chart in the app, so it is where the rules land: `chartLine` for the primary
/// series because the data gets the primary text colour rather than the accent —
/// the accent means *interactive*, and a line you cannot tap is not — a dashed
/// `chartBaseline` for the reference, `chartRaw` dots only when asked for,
/// `chartGrid` barely there, and the endpoint emphasised because the current
/// number is what the user came for.
///
/// **The smoothed series is the only thing drawn by default.** §1.5 in one line:
/// the raw daily line is the thing the brief calls actively harmful to show, and
/// the toggle that reveals it is off every time the screen appears rather than
/// remembered — a preference that persists would make the harmful version the
/// default for anyone who ever looked at it once.
struct WeightChart: View {
    let points: [TrendPoint]
    /// The pace line, empty when there is none to draw.
    let pace: [TrendPoint]
    let showsRawReadings: Bool

    /// Grows with the type so the plot is not a fixed box that the labels
    /// overflow at accessibility sizes.
    @ScaledMetric(relativeTo: .body)
    private var plotHeight: CGFloat = 200

    var body: some View {
        Chart {
            if !pace.isEmpty {
                ForEach(pace) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Pace", point.trendKg),
                        series: .value("Series", TheRunCopy.paceLabel)
                    )
                    .foregroundStyle(Ninety.Colour.chartBaseline)
                    .lineStyle(StrokeStyle(lineWidth: Ninety.Border.focus, dash: [4, 4]))
                }
            }

            if showsRawReadings {
                ForEach(points.filter { $0.readingKg != nil }) { point in
                    PointMark(
                        x: .value("Day", point.day),
                        y: .value("Reading", point.readingKg ?? 0)
                    )
                    .foregroundStyle(Ninety.Colour.chartRaw)
                    .symbolSize(18)
                }
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Trend", point.trendKg),
                    series: .value("Series", TheRunCopy.trendLabel)
                )
                .foregroundStyle(Ninety.Colour.chartLine)
                .lineStyle(StrokeStyle(lineWidth: Ninety.Border.focus, lineCap: .round))
                .interpolationMethod(.monotone)
            }

            // The endpoint, filled. Last so nothing draws over it.
            if let last = points.last {
                PointMark(
                    x: .value("Day", last.day),
                    y: .value("Trend", last.trendKg)
                )
                .foregroundStyle(Ninety.Colour.chartLine)
                .symbolSize(60)
                .annotation(position: .top, alignment: .trailing) {
                    Text(TheRunCopy.kilograms(last.trendKg))
                        .ninetyType(.label)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Ninety.Colour.chartGrid)
                AxisValueLabel {
                    if let kg = value.as(Double.self) {
                        Text(kg.formatted(.number.precision(.fractionLength(0))))
                            .ninetyType(.label)
                            .foregroundStyle(Ninety.Colour.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            // Minimal, per the spec. Three or four dates across the plot; more
            // than that is a grid pretending to be data.
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let day = value.as(Date.self) {
                        Text(day.formatted(.dateTime.day().month(.abbreviated)))
                            .ninetyType(.label)
                            .foregroundStyle(Ninety.Colour.textTertiary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: plotHeight)
        // The chart is one element to VoiceOver, described in words, because a
        // per-point audio graph of a smoothed weight series is eighty-four
        // near-identical numbers. The figures that matter are on the screen
        // above it as text.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard let first = points.first, let last = points.last else { return TheRunCopy.noWeightHeadline }
        let direction = TheRunCopy.signed(last.trendKg - first.trendKg)
        return """
            \(TheRunCopy.averageLabel): \(TheRunCopy.kilograms(last.trendKg)). \
            \(direction) across \(points.count) days.
            """
    }
}

/// The legend, which the spec makes mandatory: *"a reference line nobody can
/// identify is decoration."*
struct WeightChartLegend: View {
    let showsPace: Bool
    let showsRawReadings: Bool

    var body: some View {
        // Wrapping rather than a fixed row: three keys in the condensed face at
        // `.accessibility5` do not fit across a phone.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Ninety.Space.md) { keys }
            VStack(alignment: .leading, spacing: Ninety.Space.xs) { keys }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var keys: some View {
        key(TheRunCopy.trendLabel, colour: Ninety.Colour.chartLine, dashed: false)
        if showsPace {
            key(TheRunCopy.paceLabel, colour: Ninety.Colour.chartBaseline, dashed: true)
        }
        if showsRawReadings {
            key(TheRunCopy.showRawReadings, colour: Ninety.Colour.chartRaw, dashed: false)
        }
    }

    private func key(_ title: String, colour: Color, dashed: Bool) -> some View {
        HStack(spacing: Ninety.Space.xs) {
            Line(dashed: dashed)
                .stroke(colour, style: StrokeStyle(lineWidth: Ninety.Border.focus, dash: dashed ? [3, 3] : []))
                .frame(width: 16, height: Ninety.Border.focus)
                .accessibilityHidden(true)
            Text(title)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    /// A horizontal rule as a `Shape`, so the dash pattern is the same one the
    /// chart draws rather than a second approximation of it.
    private struct Line: Shape {
        let dashed: Bool

        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

#if DEBUG
// A function rather than statements inside `#Preview`: its closure is a result
// builder, and an explicit `return` in one is not allowed. `SubOnSheet` records
// the same shape for the same reason.
@MainActor
private func previewChart() -> some View {
    let model = TheRunModel.preview()
    return VStack(alignment: .leading, spacing: Ninety.Space.md) {
        WeightChart(points: model.visiblePoints, pace: model.visiblePace, showsRawReadings: true)
        WeightChartLegend(showsPace: true, showsRawReadings: true)
    }
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
}

#Preview("Weight chart") {
    previewChart()
}

#Preview("Weight chart · light") {
    previewChart().preferredColorScheme(.light)
}
#endif
