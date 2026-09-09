import Foundation
import Testing
@testable import Ninety

/// The 7-day EWMA, and the three states the ticket names.
///
/// The suite is built around the one property that separates a correct trend
/// from a plausible-looking one: **it runs on calendar days, not on readings**
/// (ADR 0020). Every gap test below is the same claim from a different angle —
/// somebody who weighs twice a week and somebody who weighs daily must get the
/// same line shape from the same underlying weights.
@Suite("Weight trend")
struct WeightTrendTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static func day(_ day: Int, hour: Int = 8, month: Int = 9) -> Date {
        utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private static func trend(_ readings: [(Int, Double)]) -> WeightTrend {
        WeightTrend(
            readings: readings.map { WeighIn(measuredAt: day($0.0), kg: $0.1) },
            calendar: utc
        )
    }

    // MARK: - The smoothing itself

    /// `α = 2 / (N + 1)`. The window and the smoothing are one decision, so the
    /// constant is derived rather than typed — this is the test that says so.
    @Test("the window is seven days and alpha follows from it")
    func alphaFollowsTheWindow() {
        #expect(WeightTrend.windowDays == 7)
        #expect(abs(WeightTrend.alpha - 0.25) < 1e-12)
    }

    /// The seed is the first reading, not zero. An EWMA seeded at zero spends a
    /// fortnight climbing out of a hole it invented, and on a weight chart that
    /// reads as a forty-kilogram gain.
    @Test("the first point is the first reading, not a value smoothed toward zero")
    func seedsOnTheFirstReading() {
        let trend = Self.trend([(1, 80.0)])
        #expect(trend.points.count == 1)
        #expect(trend.points.first?.trendKg == 80.0)
        #expect(trend.readingDays == 1)
    }

    /// The update, checked by hand. 80, then 84 at α = 0.25 is
    /// `80 + 0.25 × (84 − 80) = 81`, and 81 is a long way from 84 — which is the
    /// entire point of showing this line instead of the scale's.
    @Test("each reading moves the average by alpha times the gap")
    func appliesTheUpdate() {
        let trend = Self.trend([(1, 80), (2, 84), (3, 84)])
        let values = trend.points.map(\.trendKg)
        #expect(values.count == 3)
        #expect(abs(values[0] - 80) < 1e-9)
        #expect(abs(values[1] - 81) < 1e-9)
        #expect(abs(values[2] - 81.75) < 1e-9)
    }

    /// §1.5's whole claim, as an assertion. Five days of water noise around a
    /// flat 80 kg, and the smoothed series never travels as far as the raw one.
    @Test("the smoothed series moves less than the raw readings it is built from")
    func smoothsTheNoise() {
        let raw: [(Int, Double)] = [(1, 80), (2, 81.4), (3, 79.2), (4, 80.9), (5, 79.6)]
        let trend = Self.trend(raw)
        let smoothed = trend.points.map(\.trendKg)

        let rawSwing = (raw.map(\.1).max() ?? 0) - (raw.map(\.1).min() ?? 0)
        let smoothedSwing = (smoothed.max() ?? 0) - (smoothed.min() ?? 0)
        #expect(smoothedSwing < rawSwing)
    }

    // MARK: - Gaps

    /// The ticket's third acceptance criterion, and the one a naive
    /// implementation fails silently. Monday then Friday is four days apart, and
    /// smoothing the array would treat it as one.
    @Test("a gap is carried, not collapsed")
    func carriesAcrossAGap() {
        let trend = Self.trend([(1, 80), (5, 84)])

        // Five points for five calendar days, not two for two readings.
        #expect(trend.points.count == 5)
        #expect(trend.readingDays == 2, "two days produced a reading; three were carried")

        // The middle three hold the previous value and carry no reading.
        #expect(trend.points[1].readingKg == nil)
        #expect(trend.points[2].readingKg == nil)
        #expect(trend.points[3].readingKg == nil)
        #expect(trend.points[1].trendKg == 80)
        #expect(trend.points[3].trendKg == 80)

        // And the last one is a single update from 80, not four of them.
        #expect(abs((trend.points[4].trendKg) - 81) < 1e-9)
    }

    /// The same claim from the other side: the person who skipped three days
    /// and the person who weighed the same on all of them do **not** get the
    /// same answer, because three readings carry three times the information.
    @Test("weighing every day moves the average further than weighing twice")
    func gapsCarryLessInformationThanReadings() {
        let sparse = Self.trend([(1, 80), (5, 84)])
        let daily = Self.trend([(1, 80), (2, 84), (3, 84), (4, 84), (5, 84)])

        let sparseEnd = sparse.latest?.trendKg ?? 0
        let dailyEnd = daily.latest?.trendKg ?? 0
        #expect(dailyEnd > sparseEnd)
        #expect(sparse.points.count == daily.points.count, "the same span, either way")
    }

    /// Two weigh-ins on one morning are two measurements of one thing.
    @Test("a day with two readings contributes their mean, once")
    func collapsesADayToItsMean() {
        let trend = WeightTrend(
            readings: [
                WeighIn(measuredAt: Self.day(1, hour: 7), kg: 80),
                WeighIn(measuredAt: Self.day(1, hour: 21), kg: 82),
            ],
            calendar: Self.utc
        )
        #expect(trend.points.count == 1)
        #expect(trend.readingDays == 1)
        #expect(trend.points.first?.trendKg == 81)
    }

    /// Order of entry must not change the line. Somebody backfilling yesterday
    /// after today gets the same chart as somebody who logged in order.
    @Test("the line does not depend on the order the readings arrive in")
    func isOrderIndependent() {
        let inOrder = Self.trend([(1, 80), (2, 81), (3, 79)])
        let shuffled = Self.trend([(3, 79), (1, 80), (2, 81)])
        #expect(inOrder.points.map(\.trendKg) == shuffled.points.map(\.trendKg))
    }

    /// The line stops where the data does. Running it on to today would draw a
    /// weight for days nobody measured.
    @Test("the series ends at the last reading rather than at today")
    func stopsAtTheLastReading() {
        let trend = Self.trend([(1, 80), (3, 80)])
        #expect(trend.latest?.day == Self.utc.startOfDay(for: Self.day(3)))
    }

    // MARK: - The four-week comparison

    @Test("the four-week change compares trend against trend")
    func comparesTrendAgainstTrend() {
        // Twenty-nine consecutive days losing 0.1 kg each.
        let readings = (1...29).map { (day: Int) in (day, 82.8 - 0.1 * Double(day)) }
        let trend = WeightTrend(
            readings: readings.map { WeighIn(measuredAt: Self.day($0.0, month: 8), kg: $0.1) },
            calendar: Self.utc
        )
        let change = trend.change(overDays: WeightTrend.baselineDays, calendar: Self.utc)
        #expect(change != nil)

        // The raw change over the same span is exactly −2.8. The trend's is
        // smaller, and that is the lag rather than an error: an average that
        // followed a ramp with no lag would not be an average. The steady-state
        // offset for a linear ramp is `slope × (1 − α) / α` — 0.3 kg here — so
        // the figure lands just inside −2.5.
        let raw = -2.8
        #expect((change ?? 0) > raw, "the trend lags the ramp rather than tracking it exactly")
        #expect((change ?? 0) < raw + 0.4, "and it lags by about the 0.3 kg the maths predicts")
    }

    /// Nil rather than a number computed from a shorter span. `DESIGN.md`: a
    /// number the app did not compute is not shown at all.
    @Test("a series shorter than the window has no four-week figure")
    func refusesAFigureItCannotCompute() {
        let trend = Self.trend([(1, 80), (11, 79)])
        #expect(trend.change(overDays: WeightTrend.baselineDays, calendar: Self.utc) == nil)
        #expect(trend.change(overDays: 10, calendar: Self.utc) != nil, "ten days of span answers a ten-day question")
    }

    @Test("the window selector returns only the days inside it")
    func windowsTheSeries() {
        let trend = WeightTrend(
            readings: (1...30).map { WeighIn(measuredAt: Self.day($0, month: 8), kg: 80) },
            calendar: Self.utc
        )
        #expect(trend.points(inLast: 7, calendar: Self.utc).count == 8, "seven days back, inclusive of both ends")
        #expect(trend.points(inLast: 400, calendar: Self.utc).count == trend.points.count)
    }

    // MARK: - The designed states

    /// The ticket: *"Zero points, one point and two points each render
    /// deliberately."* Spike A measured the one-point case on a real device.
    @Test("zero, one, a handful and a full week are four distinct states")
    func readinessHasFourStates() {
        #expect(TrendReadiness.of(Self.trend([])) == .noReadings)
        #expect(TrendReadiness.of(Self.trend([(1, 80)])) == .oneReading)
        #expect(TrendReadiness.of(Self.trend([(1, 80), (2, 80)])) == .building(days: 2))

        let sixDays = (1...6).map { ($0, 80.0) }
        #expect(TrendReadiness.of(Self.trend(sixDays)) == .building(days: 6))

        let week = (1...7).map { ($0, 80.0) }
        #expect(TrendReadiness.of(Self.trend(week)) == .ready)
    }

    /// Readiness counts *reading days*, not points. A user who weighed twice
    /// three weeks apart has two readings and twenty-two points, and has not
    /// got a seven-day average.
    @Test("readiness counts days that produced a reading, not days on the chart")
    func readinessCountsReadingsNotPoints() {
        let trend = Self.trend([(1, 80), (22, 79)])
        #expect(trend.points.count == 22)
        #expect(TrendReadiness.of(trend) == .building(days: 2))
    }

    @Test("nothing at all renders as nothing at all")
    func handlesAnEmptySeries() {
        let trend = Self.trend([])
        #expect(trend.points.isEmpty)
        #expect(trend.latest == nil)
        #expect(trend.spanDays(calendar: Self.utc) == 0)
        #expect(trend.change(overDays: 28, calendar: Self.utc) == nil)
        #expect(!TrendReadiness.noReadings.drawsAChart)
        #expect(!TrendReadiness.oneReading.drawsAChart)
        #expect(TrendReadiness.building(days: 3).drawsAChart)
    }

    /// A timezone change during the window. Somebody who flies to New York on
    /// day three must not gain or lose a day off the chart.
    @Test("the series is built in the calendar it is handed")
    func respectsTheCalendar() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt

        // 03:00 UTC on the 2nd is 22:00 on the 1st in New York, so these are
        // two days in UTC and one day in New York.
        let readings = [
            WeighIn(measuredAt: Self.day(1, hour: 12), kg: 80),
            WeighIn(measuredAt: Self.day(2, hour: 3), kg: 82),
        ]
        #expect(WeightTrend(readings: readings, calendar: Self.utc).readingDays == 2)
        #expect(WeightTrend(readings: readings, calendar: newYork).readingDays == 1)
    }
}
