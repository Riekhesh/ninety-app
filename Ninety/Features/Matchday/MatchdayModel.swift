import Foundation
import Observation

/// Matchday, as state.
///
/// ADR 0004's shape a third time: an `@Observable` between the view and the
/// repositories. It is the widest of the three — the band, the day's logs, Form,
/// the trend, the calibration window and the opt-out all land on one screen —
/// which is the reason it reads everything in one `refresh()` and hands the
/// screen finished values rather than letting six panels each go and ask.
///
/// **Nothing here is `async`, and that is the rule rather than a coincidence**
/// (ADR 0005, and P1-I's own constraint on this epic). Matchday is the screen
/// somebody opens to log breakfast; a dashboard that waited on a drain would put
/// the network in front of the day's first tap. There is no reference to
/// `SyncService` anywhere in this file or the views under it — no count of
/// unsent rows, no "syncing" state, no spinner. `Settings → Sync` is the only
/// surface in the app that mentions the network, and it stays that way.
///
/// **Every number on the screen is one the app computed from rows it holds.**
/// Where there is nothing to compute from, the model publishes nil and the view
/// renders a sentence — never a zero, never a placeholder figure. That is
/// `DESIGN.md` § Numbers, and it is the difference between a dashboard and a
/// mock-up of one.
@MainActor
@Observable
final class MatchdayModel {
    /// How far back the trend is read. Long enough for the four-week comparison
    /// the sparkline's caption makes, with room either side.
    static let historyDays = 120

    // MARK: - What the screen shows

    /// Nil until Pre-Season has produced one. Nil renders as a sentence.
    private(set) var band: CalorieBand?

    /// Everything logged today, oldest first — the order a team sheet reads in,
    /// which is the opposite of Sub On's Today list. There the newest row is the
    /// one you are most likely to want to correct; here the day is a sequence.
    private(set) var today: [FoodLog] = []
    private(set) var loggedTodayKcal: Double = 0
    private(set) var macros = MacroTotals(proteinG: 0, carbsG: 0, fatG: 0, coveredLogs: 0, totalLogs: 0)

    private(set) var form = Form(days: [])

    /// The same `WeightTrend` The Run draws, built the same way from the same
    /// repository. The sparkline is a second *rendering*, never a second
    /// calculation — the ticket asks for that in as many words, and ADR 0020 is
    /// why it matters: a trend that smooths readings rather than calendar days
    /// is wrong in a way that only shows up on somebody else's data.
    private(set) var trend = WeightTrend(readings: [], calendar: .current)

    /// Where the calibration window stands, or nil before there is a profile.
    private(set) var calibration: CalibrationState?

    /// §10 S6. Read on every refresh, because the switch is two taps away in
    /// Settings and this screen is what it returns to.
    private(set) var features = CompetitiveFeatures(isOptedOut: false)

    // MARK: - Dependencies

    private let foods: any FoodRepositoryProtocol
    private let profiles: any ProfileRepositoryProtocol
    private let weights: any WeightRepositoryProtocol
    private let calendar: Calendar
    private let now: () -> Date

    init(
        foods: any FoodRepositoryProtocol,
        profiles: any ProfileRepositoryProtocol,
        weights: any WeightRepositoryProtocol,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.foods = foods
        self.profiles = profiles
        self.weights = weights
        self.calendar = calendar
        self.now = now
    }

    // No `refresh()` in `init`, for the reason `TheRunModel` records: this is
    // built inside a `Tab` closure, which SwiftUI re-evaluates on every render
    // of the shell, so a fetch here would be several store reads per render
    // thrown away every time. The view calls it from `onAppear`.

    // MARK: - The band

    /// What is left in the band, and it is allowed to be negative.
    ///
    /// Above the band is a fact, not an error: `BandState.above` is `.neutral`
    /// and the token set has no red for it, so this returns the number rather
    /// than clamping at zero and pretending the day is still open.
    var roomLeftKcal: Int? {
        band.map { $0.centre - Int(loggedTodayKcal.rounded()) }
    }

    var bandState: BandState? {
        band.map { BandState.of(kcal: Int(loggedTodayKcal.rounded()), band: $0) }
    }

    /// How far up the pitch today's intake has got, `0...1`, or nil with no band.
    ///
    /// The pitch runs to a whole band's width past the top of the band, so being
    /// over is somewhere the marker can actually be rather than a bar pinned at
    /// full. A day that is well past that pins at 1 and the figure above says the
    /// rest — the meter is a glance, and the number is the truth.
    var pitchProgress: Double? {
        band.map { min(max(loggedTodayKcal / Double($0.upper + $0.tolerance * 2), 0), 1) }
    }

    /// Where the band's own box sits on that pitch, as a `0...1` span.
    var bandSpan: ClosedRange<Double>? {
        band.map { band in
            let full = Double(band.upper + band.tolerance * 2)
            return (Double(band.lower) / full)...(Double(band.upper) / full)
        }
    }

    // MARK: - The weight

    var readiness: TrendReadiness { TrendReadiness.of(trend) }

    /// The headline weight: the latest point on the **smoothed** series, never
    /// the last thing the scale said (§1.5).
    var latestTrendKg: Double? { trend.latest?.trendKg }

    /// The four-week change, or nil when the series does not reach back that far.
    var changeOverFourWeeks: Double? {
        trend.change(overDays: WeightTrend.baselineDays, calendar: calendar)
    }

    /// What the sparkline draws: the same smoothed series, over four weeks.
    var sparkline: [TrendPoint] {
        trend.points(inLast: WeightTrend.baselineDays, calendar: calendar)
    }

    // MARK: - The team sheet

    func today(in slot: MealSlot) -> [FoodLog] {
        today.filter { $0.mealSlot(calendar: calendar) == slot }
    }

    func kcal(in slot: MealSlot) -> Double {
        today(in: slot).reduce(0) { $0 + $1.kcal }
    }

    /// The masthead's meta line: the date, plainly. No time-of-day greeting —
    /// the copy deck rules one out, and it ages badly.
    var todayLabel: String {
        now().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: - Reading

    func refresh() {
        let moment = now()

        today = foods.logs(on: moment, calendar: calendar)
        loggedTodayKcal = today.reduce(0) { $0 + $1.kcal }
        macros = MacroTotals.of(today)

        let profile = profiles.current()
        band = profile.flatMap {
            EnergyTarget.band(
                for: $0,
                weightKg: weights.recent(limit: 1).first?.kg,
                on: moment,
                calendar: calendar
            )
        }

        // The window, from the days anything was logged on. `recentLogs` is
        // asked for the seven days Form covers rather than for everything: the
        // only thing read off these rows is which day each landed on.
        let firstDay = calendar.startOfDay(for: moment)
        let windowStart = calendar.date(byAdding: .day, value: -(Form.windowDays - 1), to: firstDay)
        form = Form.of(
            foods.recentLogs(since: windowStart ?? moment, limit: 500).map(\.loggedAt),
            on: moment,
            calendar: calendar
        )

        let from = calendar.date(byAdding: .day, value: -Self.historyDays, to: moment) ?? .distantPast
        trend = WeightTrend(readings: weights.readings(since: from).map(\.weighIn), calendar: calendar)

        features = CompetitiveFeatures(profiles: profiles)
        calibration = CalibrationRecorder(profiles: profiles).state(on: moment, calendar: calendar)
    }
}
