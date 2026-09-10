import Foundation

/// One weigh-in, as the trend needs it: an instant and a number.
///
/// A value rather than the `@Model` because the whole of this file is pure and
/// has to stay that way. `WeightLog` is a SwiftData object whose identity means
/// nothing outside a context, and the trend is the one part of The Run that
/// Phase 2's progress score will read — `Packages/RankingEngine` cannot import
/// SwiftData (`ranking_engine_no_ui_imports`), so the shape it will eventually
/// be handed is this one and not the row.
struct WeighIn: Equatable, Sendable {
    let measuredAt: Date
    let kg: Double
}

/// One day on the trend line.
///
/// `readingKg` is nil on a day nobody stood on a scale, and that is the field
/// that makes the raw series drawable: the smoothed line is defined on every
/// day in the span, the dots are only on the days that produced one. A chart
/// that drew a dot on a carried day would be inventing a measurement.
struct TrendPoint: Identifiable, Equatable, Sendable {
    /// The start of the calendar day, in the user's own calendar.
    let day: Date
    let trendKg: Double
    let readingKg: Double?

    var id: Date { day }
}

/// The 7-day exponentially weighted moving average, and what can be said about
/// it.
///
/// §1.5, and it is the strongest wording in the brief about a display choice:
/// *"Daily weight is mostly water, glycogen and gut content. Showing it raw is
/// actively harmful: it produces a jagged line that makes a genuinely successful
/// week look like failure, and it is one of the main reasons people abandon
/// weight-loss apps in the first fortnight."*
///
/// **The series runs on calendar days, not on readings** (ADR 0020). Smoothing
/// the array of weigh-ins would make a Monday reading followed by a Friday one
/// look like two consecutive days, so somebody who weighs twice a week would get
/// a trend that reacts three times too fast — and the same person's chart would
/// change shape depending on how often they remembered, which is the one thing a
/// trend must not do. The walk here steps one day at a time across the whole
/// span and carries the average forward through the gaps, so a missed day
/// contributes no new information rather than contributing the next reading's.
///
/// The line stops at the last reading rather than running on to today. Carrying
/// a flat line to the present would draw a weight for days nobody measured, and
/// `DESIGN.md` is explicit that a number the app did not compute is not shown.
struct WeightTrend: Equatable, Sendable {
    /// §1.5's number, and the one the copy names. Changing it changes the copy.
    static let windowDays = 7

    /// The four-week comparison the copy deck and the artboard both use:
    /// `−1.2 kg vs 4 weeks ago`.
    static let baselineDays = 28

    /// `α = 2 / (N + 1)` — the span convention, which gives 0.25 for a 7-day
    /// window. Stated as the formula rather than as 0.25 so that the window and
    /// the smoothing cannot drift apart: they are the same decision.
    static var alpha: Double { 2 / (Double(windowDays) + 1) }

    /// Oldest first, one entry per calendar day across the whole span.
    let points: [TrendPoint]

    /// How many days actually produced a reading. Not `points.count`, which
    /// counts the carried days too — the distinction is the whole of the
    /// one-point and no-point states.
    let readingDays: Int

    init(readings: [WeighIn], calendar: Calendar) {
        let daily = Self.daily(readings, calendar: calendar)
        self.points = Self.walk(daily, calendar: calendar)
        self.readingDays = daily.count
    }

    /// Collapses the weigh-ins to one value per calendar day, oldest first.
    ///
    /// **The mean of the day's readings**, because two weigh-ins on one morning
    /// are two measurements of one thing rather than two things. Taking the last
    /// would let the order they were entered in move the line, and taking the
    /// lowest would be the app helping the user flatter themselves.
    private static func daily(_ readings: [WeighIn], calendar: Calendar) -> [(day: Date, kg: Double)] {
        var totals: [Date: (sum: Double, count: Int)] = [:]
        for reading in readings {
            let day = calendar.startOfDay(for: reading.measuredAt)
            let running = totals[day] ?? (0, 0)
            totals[day] = (running.sum + reading.kg, running.count + 1)
        }
        return totals
            .map { (day: $0.key, kg: $0.value.sum / Double($0.value.count)) }
            .sorted { $0.day < $1.day }
    }

    /// One step per calendar day from the first reading to the last.
    ///
    /// The seed is the first day's own value rather than zero: an EWMA seeded at
    /// zero spends its first fortnight climbing out of a hole it invented, and
    /// on a weight chart that is not a smoothing artefact, it is a line telling
    /// somebody they have gained forty kilograms.
    private static func walk(
        _ daily: [(day: Date, kg: Double)],
        calendar: Calendar
    ) -> [TrendPoint] {
        guard let first = daily.first, let last = daily.last else { return [] }

        let byDay = Dictionary(daily.map { ($0.day, $0.kg) }, uniquingKeysWith: { _, second in second })
        var points: [TrendPoint] = []
        var trend: Double?
        var day = first.day

        while day <= last.day {
            let reading = byDay[day]
            if let reading {
                // The update, and the only place the smoothing happens.
                trend = trend.map { $0 + alpha * (reading - $0) } ?? reading
            }
            // Carried, not recomputed: a day with no reading has nothing to
            // move the average with, so the average does not move.
            if let trend {
                points.append(TrendPoint(day: day, trendKg: trend, readingKg: reading))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return points
    }

    // MARK: - What can be said about it

    var latest: TrendPoint? { points.last }

    var earliest: TrendPoint? { points.first }

    /// Whole calendar days from the first reading to the last. Zero when
    /// everything arrived on one day, which is the one-point state.
    func spanDays(calendar: Calendar) -> Int {
        guard let earliest, let latest else { return 0 }
        return calendar.dateComponents([.day], from: earliest.day, to: latest.day).day ?? 0
    }

    /// The change in the **trend** over a window, or nil when the series does
    /// not reach back that far.
    ///
    /// Trend against trend, never reading against reading. Comparing today's
    /// number with the one from four weeks ago compares two days of water
    /// retention and calls the difference progress — which is the same mistake
    /// as showing the raw line, made once instead of continuously.
    ///
    /// Nil is a real answer and the screen has copy for it. A four-week figure
    /// computed from eleven days of data is a number the app did not measure.
    func change(overDays days: Int, calendar: Calendar) -> Double? {
        guard let latest else { return nil }
        guard let from = calendar.date(byAdding: .day, value: -days, to: latest.day) else { return nil }
        guard let earlier = points.first(where: { $0.day >= from }), earlier.day == from else { return nil }
        return latest.trendKg - earlier.trendKg
    }

    /// The points inside a window ending at the last reading. What the chart
    /// draws when the range selector is not on "all".
    func points(inLast days: Int, calendar: Calendar) -> [TrendPoint] {
        guard let latest else { return [] }
        guard let from = calendar.date(byAdding: .day, value: -days, to: latest.day) else { return points }
        return points.filter { $0.day >= from }
    }
}

/// How much of a trend there is to show.
///
/// Four cases and each renders deliberately — the one-point state is the
/// ticket's own requirement, and it came out of Spike A rather than out of a
/// checklist: *"bodyweight read 120.00 kg from a single same-day entry, so the
/// 30-day trend had exactly one point. Nothing was wrong — there was simply no
/// back-history."*
///
/// **None of the copy behind these speculates about why data is missing.** Phase
/// 0 established that iOS has no permission-denied branch to write: a denied
/// HealthKit read returns a result identical to "no data" and the two will never
/// be distinguishable, so a screen that says "grant access" when the answer is
/// "you have not weighed yourself" is wrong half the time and cannot know which.
enum TrendReadiness: Equatable, Sendable {
    /// Nothing at all. Onboarding writes one reading, so this is reachable only
    /// by deleting it — but it is reachable, and a blank screen is the one state
    /// with no explanation for itself.
    case noReadings

    /// Exactly one. There is a weight and there is no trend, and saying both is
    /// more useful than drawing a one-point line.
    case oneReading

    /// Between two and six. A line can be drawn and the seven-day average
    /// cannot honestly be called one yet.
    case building(days: Int)

    /// Seven or more days with a reading behind them.
    case ready

    static func of(_ trend: WeightTrend) -> TrendReadiness {
        switch trend.readingDays {
        case 0: .noReadings
        case 1: .oneReading
        case ..<WeightTrend.windowDays: .building(days: trend.readingDays)
        default: .ready
        }
    }

    /// Whether there is a second point to draw a line between.
    var drawsAChart: Bool {
        switch self {
        case .noReadings, .oneReading: false
        case .building, .ready: true
        }
    }
}
