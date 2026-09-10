import SwiftUI

/// Form: seven days, as a ring.
///
/// **The one rule this component exists to obey is that a missed day is empty,
/// never crossed out.** §10 S5, and §1 spells out what the alternative costs: a
/// ring that marks failure is a ring people stop looking at, and then they stop
/// logging. `DayMark` has two cases and no third, so there is nothing here that
/// could draw a cross even if somebody wanted one — a missed segment is the same
/// hairline as the empty ring, which makes it a gap rather than a mark.
///
/// **No animation on the transition, of any kind.** `DESIGN.md` bans streak-loss
/// animation outright and caps everything routine at 0.3s; a segment emptying is
/// the case the ban is actually about, so it does not animate at all.
///
/// > **Deviation from the artboards.** `Main.dc.html` draws Form as seven bars
/// > in a row; the ticket calls it a ring. It is drawn here as a ring *of seven
/// > discrete segments*, which is both: the segments are the days, so a missed
/// > one is still a gap in a sequence rather than a dent in a continuous arc.
/// > A single sweeping arc would have been the wrong shape for the same reason
/// > a streak counter is — it reads as a quantity of progress that can be lost,
/// > and this is a count of days that can only be added to.
///
/// **Legible without colour.** ADR 0012's rule generalises: the figure beside the
/// ring says `5 of 7 days` in words, each segment is filled or hollow rather
/// than one colour or another, and VoiceOver reads the seven days by name.
struct FormGuide: View {
    let form: Form

    /// Grows with the type, like every other metric on the screen.
    @ScaledMetric(relativeTo: .title2)
    private var diameter: CGFloat = 92

    /// The gap between segments, in degrees. Wide enough that a hollow segment
    /// reads as a gap at a glance and narrow enough that seven of them still
    /// read as one ring.
    private static let gap = 6.0

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            SectionHeading(title: MatchdayCopy.formHeading)

            HStack(alignment: .center, spacing: Ninety.Space.lg) {
                ring
                figure
            }

            Text(MatchdayCopy.formNote)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
        .chalkPanel(padding: Ninety.Space.lg)
        .accessibilityElement(children: .contain)
    }

    private var ring: some View {
        ZStack {
            ForEach(Array(form.days.enumerated()), id: \.element.id) { index, day in
                Segment(index: index, count: max(form.days.count, 1), gap: Self.gap)
                    .stroke(
                        day.mark.colour,
                        style: StrokeStyle(lineWidth: diameter * 0.12, lineCap: .butt)
                    )
                    .accessibilityLabel(MatchdayCopy.formDay(day.date, mark: day.mark))
            }
        }
        .frame(width: diameter, height: diameter)
        // Contained rather than combined: each day is its own element, so a
        // screen reader user can walk the week rather than being handed one
        // sentence with seven clauses in it.
        .accessibilityElement(children: .contain)
    }

    private var figure: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xs) {
            Text(MatchdayCopy.formDays(form.loggedDays))
                .ninetyType(.metricM)
                .foregroundStyle(Ninety.Colour.textPrimary)

            if form.loggedDays == 0 {
                Text(MatchdayCopy.formEmpty)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// One day's arc.
    ///
    /// Drawn from the top and clockwise, so the ring reads in the order the week
    /// happened — oldest at twelve o'clock, today just before it.
    private struct Segment: Shape {
        let index: Int
        let count: Int
        let gap: Double

        func path(in rect: CGRect) -> Path {
            let slice = 360.0 / Double(count)
            let start = -90.0 + Double(index) * slice + gap / 2
            let end = start + slice - gap
            let radius = min(rect.width, rect.height) / 2 - rect.width * 0.06

            var path = Path()
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: max(radius, 1),
                startAngle: .degrees(start),
                endAngle: .degrees(end),
                clockwise: false
            )
            return path
        }
    }
}
