import Foundation
import Testing
@testable import Ninety

/// The pace line, and the three things it is allowed to say.
///
/// The safety-relevant half is `aheadIsNeverCelebrated`: §10 S3 caps rate of
/// loss in the score, and a screen that rewards beating the cap is an incentive
/// pulling the other way. The rest is arithmetic — but the arithmetic has a
/// safety property too, which `paceNeverProjectsPastTheGoal` checks: S2 rejected
/// a goal weight below BMI 18.5, and a line that runs through the goal would be
/// tracking toward a number the gate refused.
@MainActor
@Suite("Pace against the chosen rate")
struct PaceTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static func day(_ day: Int, month: Int = 9) -> Date {
        utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: 8)) ?? .distantPast
    }

    private static func profile(
        goal: GoalType = .lose,
        rate: Double = 0.5,
        goalWeightKg: Double? = 70
    ) -> Profile {
        Profile(
            id: UUID(),
            heightCm: 178,
            sex: .male,
            goalType: goal,
            goalWeightKg: goalWeightKg,
            targetRateKgPerWeek: rate
        )
    }

    private static func trend(_ readings: [(Int, Double)]) -> WeightTrend {
        WeightTrend(readings: readings.map { WeighIn(measuredAt: day($0.0), kg: $0.1) }, calendar: utc)
    }

    /// A daily weigh-in moving at a steady rate per week, for `days` days.
    ///
    /// Daily rather than two readings at the ends, and that is not padding: the
    /// series carries the average forward through a gap, so a single reading on
    /// day 15 after one on day 1 moves the trend by one α-step and leaves it
    /// sitting on the pace line whatever that reading says. Somebody who weighs
    /// twice a month genuinely does not have a trend that can be ahead or behind
    /// anything, and the arithmetic saying so is correct rather than inconvenient.
    private static func ramp(_ kgPerWeek: Double, days: Int = 15, from start: Double = 80) -> WeightTrend {
        trend((1...days).map { ($0, start + kgPerWeek * Double($0 - 1) / 7) })
    }

    // MARK: - The line

    /// Losing points down, gaining points up, maintaining is flat. The profile
    /// stores a magnitude and a goal type; the sign is made here so that no
    /// caller has to make it differently.
    @Test("the rate takes its sign from the goal type")
    func signsTheRateFromTheGoal() {
        let start = Self.trend([(1, 80)])
        #expect(Pace.of(profile: Self.profile(goal: .lose, rate: 0.5), trend: start)?.ratePerWeekKg == -0.5)
        #expect(Pace.of(profile: Self.profile(goal: .gain, rate: 0.5), trend: start)?.ratePerWeekKg == 0.5)
        #expect(Pace.of(profile: Self.profile(goal: .maintain, rate: 0.5), trend: start)?.ratePerWeekKg == 0)
    }

    /// Daily, not weekly. The chart's axis is days, and a staircase would read
    /// as a claim that weight moves once a week.
    @Test("the line falls by the weekly rate spread across seven days")
    func interpolatesDaily() throws {
        let pace = try #require(Pace.of(profile: Self.profile(rate: 0.7), trend: Self.trend([(1, 80)])))

        #expect(abs(pace.expectedKg(on: Self.day(1), calendar: Self.utc) - 80) < 1e-9)
        #expect(abs(pace.expectedKg(on: Self.day(8), calendar: Self.utc) - 79.3) < 1e-9)
        #expect(abs(pace.expectedKg(on: Self.day(4), calendar: Self.utc) - 79.7) < 1e-9)
    }

    /// The line anchors on the smoothed first value, not the raw one, so the
    /// pace and the series start at the same number instead of a kilogram of
    /// that morning's water apart.
    @Test("the line starts where the trend starts")
    func anchorsOnTheTrend() throws {
        let trend = Self.trend([(1, 80), (2, 84)])
        let pace = try #require(Pace.of(profile: Self.profile(), trend: trend))
        #expect(pace.anchorKg == trend.earliest?.trendKg)
        #expect(pace.anchorDay == trend.earliest?.day)
    }

    /// §10 S2's goal, which is the one the BMI check accepted. A line that runs
    /// through it would have the app quietly tracking toward a weight it refused
    /// to let the user set.
    @Test("the line stops at the goal weight rather than projecting through it")
    func paceNeverProjectsPastTheGoal() throws {
        let pace = try #require(
            Pace.of(profile: Self.profile(rate: 1.0, goalWeightKg: 78), trend: Self.trend([(1, 80)]))
        )
        // Two weeks at 1 kg/week would reach 78 exactly; three would undershoot.
        #expect(abs(pace.expectedKg(on: Self.day(15), calendar: Self.utc) - 78) < 1e-9)
        #expect(pace.expectedKg(on: Self.day(29), calendar: Self.utc) == 78)
        #expect(pace.expectedKg(on: Self.day(29, month: 12), calendar: Self.utc) == 78)
    }

    @Test("a gain goal clamps from the other side")
    func clampsAGainGoalUpward() throws {
        let pace = try #require(
            Pace.of(profile: Self.profile(goal: .gain, rate: 1.0, goalWeightKg: 82), trend: Self.trend([(1, 80)]))
        )
        #expect(pace.expectedKg(on: Self.day(29), calendar: Self.utc) == 82)
    }

    /// A pace with no series under it is a target drawn on an empty chart.
    @Test("there is no pace before there is a trend")
    func needsATrendToAnchorOn() {
        #expect(Pace.of(profile: Self.profile(), trend: Self.trend([])) == nil)
    }

    // MARK: - The corridor

    /// One week of the chosen rate, floored at 0.3 kg so a maintain goal has a
    /// corridor at all. Without the floor the verdict would flip between
    /// consecutive mornings on residual noise, which is worse than no verdict.
    @Test("the corridor is a week of the rate, and never zero")
    func corridorIsAWeekOfTheRate() throws {
        let fast = try #require(Pace.of(profile: Self.profile(rate: 0.75), trend: Self.trend([(1, 80)])))
        let slow = try #require(Pace.of(profile: Self.profile(rate: 0.25), trend: Self.trend([(1, 80)])))
        let flat = try #require(
            Pace.of(profile: Self.profile(goal: .maintain, rate: 0.5), trend: Self.trend([(1, 80)]))
        )

        #expect(fast.corridorKg == 0.75)
        #expect(slow.corridorKg == 0.3, "0.25 is under the floor, so the floor holds")
        #expect(flat.corridorKg == 0.3)
    }

    // MARK: - The three standings

    @Test("inside the corridor is on pace")
    func insideTheCorridorIsOnPace() throws {
        // Exactly the chosen rate: the line is at 79.0 on the 15th, and the
        // trend arrives 0.21 kg behind it — the EWMA's lag on a ramp, which is
        // inside a 0.5 kg corridor and is the reason the corridor exists.
        let trend = Self.ramp(-0.5)
        let pace = try #require(Pace.of(profile: Self.profile(rate: 0.5), trend: trend))
        #expect(pace.standing(for: trend, calendar: Self.utc) == .onPace)
    }

    @Test("losing faster than the line is ahead; slower is behind")
    func readsBothSidesOfTheLine() throws {
        // Three times the chosen rate, and none of it at all.
        let fast = Self.ramp(-1.5)
        let slow = Self.ramp(0)

        let paceFast = try #require(Pace.of(profile: Self.profile(rate: 0.5), trend: fast))
        let paceSlow = try #require(Pace.of(profile: Self.profile(rate: 0.5), trend: slow))

        #expect(paceFast.standing(for: fast, calendar: Self.utc) == .ahead)
        #expect(paceSlow.standing(for: slow, calendar: Self.utc) == .behind)
    }

    /// The direction inverts with the goal: for somebody gaining, above the line
    /// is ahead.
    @Test("a gain goal reads the deviation the other way round")
    func invertsForAGainGoal() throws {
        let trend = Self.ramp(1.5)
        let pace = try #require(Pace.of(profile: Self.profile(goal: .gain, rate: 0.5), trend: trend))
        #expect(pace.standing(for: trend, calendar: Self.utc) == .ahead)
    }

    /// For a flat line there is no direction to be ahead in, and both drifts
    /// come back as the same case — which the copy then renders as "drifting
    /// from steady" rather than as anything about being behind.
    @Test("a maintain goal treats a drift in either direction the same way")
    func maintainHasNoDirection() throws {
        let up = Self.ramp(2)
        let down = Self.ramp(-2)
        let paceUp = try #require(Pace.of(profile: Self.profile(goal: .maintain), trend: up))
        let paceDown = try #require(Pace.of(profile: Self.profile(goal: .maintain), trend: down))

        #expect(paceUp.standing(for: up, calendar: Self.utc) == .behind)
        #expect(paceDown.standing(for: down, calendar: Self.utc) == .behind)
        #expect(TheRunCopy.pace(.behind, goalType: .maintain) == "Drifting from steady.")
        #expect(TheRunCopy.pace(.ahead, goalType: .maintain) == "Drifting from steady.")
    }

    // MARK: - What it is allowed to say

    /// §10 S3, as copy. The engine caps rate of loss; celebrating speed would
    /// fight the cap. The `ahead` note names the cap rather than praising.
    @Test("being ahead of pace is stated, never celebrated")
    func aheadIsNeverCelebrated() {
        for goal in [GoalType.lose, .gain] {
            let line = TheRunCopy.pace(.ahead, goalType: goal)
            let note = TheRunCopy.paceNote(.ahead, goalType: goal)
            let both = (line + " " + note).lowercased()

            for praise in ["great", "well done", "smashing", "amazing", "keep it up", "ahead of schedule", "!"] {
                #expect(!both.contains(praise), "\"\(both)\" celebrates beating the rate ceiling")
            }
            #expect(note.contains("rather than the fastest"), "it says why faster is not better")
        }
    }

    /// S5. Behind is a fact about a line, put in proportion — not a verdict.
    @Test("being behind pace is not framed as a failure")
    func behindIsNotPunitive() {
        for goal in GoalType.allCases {
            let both = (TheRunCopy.pace(.behind, goalType: goal) + " " + TheRunCopy.paceNote(.behind, goalType: goal))
                .lowercased()
            for phrase in SafetyCopyTests.banned {
                #expect(!both.contains(phrase), "\"\(both)\" contains \"\(phrase)\"")
            }
        }
    }

    /// The pace can only ever be one the §10 S3 filter allowed onboarding to
    /// offer, because it comes off the profile. Nothing here can make one
    /// steeper — this is the assertion that the two halves are wired together
    /// rather than merely both present.
    @Test("the pace is never steeper than the S3 ceiling for that body weight")
    func staysInsideTheRateCeiling() throws {
        for rate in LossRate.selectable(forBodyWeightKg: 80) {
            let pace = try #require(
                Pace.of(profile: Self.profile(rate: rate), trend: Self.trend([(1, 80)]))
            )
            #expect(LossRate.isWithinCeiling(abs(pace.ratePerWeekKg), forBodyWeightKg: 80))
            #expect(abs(pace.ratePerWeekKg) <= LossRate.absoluteCeiling)
        }
    }
}
