import Foundation

/// The line the user signed up for, and where they are against it.
///
/// The rate comes off the profile, which means it has already been through
/// §10 S3: `LossRate.selectable(forBodyWeightKg:)` filtered the options
/// onboarding could offer to those at or below `min(1.0 kg/week, 1% of body
/// weight)`, so there is no arithmetic here that can produce a pace steeper than
/// the ceiling. This type draws that decision; it does not re-make it.
///
/// **Being ahead of it is stated, never celebrated.** The ticket says so and
/// `PRODUCT.md` says why: the engine caps rate of loss for safety, and a screen
/// that congratulates speed is an incentive pulling against the cap. So there is
/// no `positive` tone on `.ahead`, no green, and no exclamation — it is a fact
/// about a line, in the same voice as the other two.
struct Pace: Equatable, Sendable {
    /// Signed kilograms per week: negative to lose, positive to gain, zero to
    /// maintain. The profile stores the magnitude and the goal type separately,
    /// and combining them here is what stops every caller doing it differently.
    let ratePerWeekKg: Double

    /// Where the line starts: the first day of the trend and its value.
    ///
    /// The trend rather than the raw first reading, so the line and the series
    /// begin at the same number. Anchoring on a raw reading would start the pace
    /// a kilogram away from the line it is meant to be compared with, on nothing
    /// but that morning's water.
    let anchorDay: Date
    let anchorKg: Double

    /// §10 S2's validated goal. The line stops here rather than running through
    /// it — a pace that projects past the goal weight is the app quietly
    /// tracking toward a number the BMI check would have refused.
    let goalKg: Double?

    let goalType: GoalType

    /// Half the corridor's width, in kilograms.
    ///
    /// **One week of the chosen rate, and never less than 0.3 kg.** The first
    /// half is the sentence a human can hold — you are within a week of the line
    /// — and the second is what stops a `maintain` goal, whose rate is zero,
    /// having a corridor of zero width. A 7-day EWMA still carries a few hundred
    /// grams of residual noise, so a corridor narrower than that would flip the
    /// verdict between "ahead" and "behind" on consecutive mornings, which is
    /// worse than not offering a verdict.
    ///
    /// Not a safety number: it decides a sentence, not a target, and nothing
    /// downstream reads it. `docs/safety/` does not carry it for that reason.
    var corridorKg: Double { max(abs(ratePerWeekKg), 0.3) }

    /// The pace for a profile, against a trend that has somewhere to start.
    ///
    /// Nil when there is no trend to anchor on. A pace line with no series under
    /// it is a target drawn on an empty chart, which tells the user what they
    /// signed up for and nothing about how it is going.
    static func of(profile: Profile, trend: WeightTrend) -> Pace? {
        guard let anchor = trend.earliest else { return nil }
        let magnitude = profile.targetRateKgPerWeek
        let signed: Double
        switch profile.goalType {
        case .lose: signed = -magnitude
        case .gain: signed = magnitude
        case .maintain: signed = 0
        }
        return Pace(
            ratePerWeekKg: signed,
            anchorDay: anchor.day,
            anchorKg: anchor.trendKg,
            goalKg: profile.goalWeightKg,
            goalType: profile.goalType
        )
    }

    /// Where the line sits on a given day, clamped at the goal.
    ///
    /// Days rather than weeks, divided rather than stepped, because the line is
    /// drawn on a daily axis and a staircase would read as a claim that weight
    /// moves once a week.
    func expectedKg(on day: Date, calendar: Calendar) -> Double {
        let days = calendar.dateComponents([.day], from: anchorDay, to: day).day ?? 0
        let projected = anchorKg + ratePerWeekKg * Double(days) / 7
        guard let goalKg else { return projected }
        switch goalType {
        case .lose: return max(projected, goalKg)
        case .gain: return min(projected, goalKg)
        case .maintain: return projected
        }
    }

    /// The line as points, one per day of a series, for the chart.
    func line(over points: [TrendPoint], calendar: Calendar) -> [TrendPoint] {
        points.map {
            TrendPoint(day: $0.day, trendKg: expectedKg(on: $0.day, calendar: calendar), readingKg: nil)
        }
    }

    /// How far the trend is from the line on its latest day. Signed in
    /// kilograms: negative is lighter than the line, positive is heavier.
    func deviationKg(for trend: WeightTrend, calendar: Calendar) -> Double? {
        guard let latest = trend.latest else { return nil }
        return latest.trendKg - expectedKg(on: latest.day, calendar: calendar)
    }

    /// Which of the three things is true today.
    ///
    /// **`maintain` uses `.behind` for a drift in either direction**, because
    /// there is no direction to be ahead in when the line is flat — and the word
    /// never reaches the user: `TheRunCopy.pace(_:goalType:)` takes the goal type
    /// as well, and a maintaining user reads "drifting from steady" rather than
    /// anything about being behind.
    func standing(for trend: WeightTrend, calendar: Calendar) -> PaceStanding? {
        guard let deviation = deviationKg(for: trend, calendar: calendar) else { return nil }
        guard abs(deviation) > corridorKg else { return .onPace }
        switch goalType {
        case .lose: return deviation < 0 ? .ahead : .behind
        case .gain: return deviation > 0 ? .ahead : .behind
        case .maintain: return .behind
        }
    }
}

/// Where the trend sits against the line. Three cases, none of them a verdict on
/// the person.
enum PaceStanding: Equatable, Sendable, CaseIterable {
    /// Inside the corridor.
    case onPace

    /// Moving faster than the rate that was chosen. Stated flatly — §10 S3's
    /// whole point is that faster is not better here, so this case gets no
    /// celebration and no `positive` tone.
    case ahead

    /// Slower than the chosen rate, moving the other way, or — for a maintain
    /// goal — drifting off a flat line.
    case behind
}
