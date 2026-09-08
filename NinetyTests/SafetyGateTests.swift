import Foundation
import Testing
@testable import Ninety

/// §10 S1–S4, as the tests `docs/safety/safety-requirements.md` names.
///
/// The names in that file are snake_case because it is prose; the functions
/// below carry them verbatim in their doc comments so a reader can go from the
/// requirement to the assertion without guessing at a translation.
///
/// Every case here is stated in whole values rather than derived from a helper.
/// A safety test that computes its own expectation from the same code it is
/// checking passes for the wrong reason.
@Suite("Safety gates (S1–S4)")
struct SafetyGateTests {
    /// A calendar that does not move under the tests. S4 turns entirely on which
    /// day it is, so "today" is a parameter everywhere and never `Date()`.
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    // MARK: - S1 · the calorie floor

    /// A woman at a low body weight asking for a fast loss. Mifflin-St Jeor puts
    /// maintenance at ~1,487 and the deficit takes it to ~662.
    private static let lightFemaleLosingFast = EnergyInputs(
        sex: .female,
        weightKg: 55,
        heightCm: 160,
        ageYears: 30,
        activityLevel: .sedentary,
        goalType: .lose,
        targetRateKgPerWeek: 0.75
    )

    /// `test_calorie_target_never_below_floor_female`
    @Test("the band never lands below 1,200 kcal for a woman, whatever is asked")
    func calorieTargetNeverBelowFloorFemale() {
        let band = EnergyTarget.band(for: Self.lightFemaleLosingFast)

        #expect(band.centre == 1_200)
        #expect(band.isAtFloor)
        #expect(band.floor == 1_200)
    }

    /// `test_calorie_target_never_below_floor_male`
    @Test("the band never lands below 1,500 kcal for a man, whatever is asked")
    func calorieTargetNeverBelowFloorMale() {
        var inputs = Self.lightFemaleLosingFast
        inputs.sex = .male
        inputs.weightKg = 60
        inputs.heightCm = 170
        inputs.ageYears = 40
        inputs.targetRateKgPerWeek = 1.0

        let band = EnergyTarget.band(for: inputs)

        #expect(band.centre == 1_500)
        #expect(band.isAtFloor)
    }

    /// `test_unspecified_sex_uses_higher_floor`
    ///
    /// And the same principle one step earlier: the basal rate for an unstated
    /// sex uses the higher constant too, because erring high is the safe
    /// direction for a value the app is guessing at.
    @Test("an unstated sex takes the higher floor, and the higher basal constant")
    func unspecifiedSexUsesHigherFloor() {
        #expect(Sex.unspecified.calorieFloor == 1_500)
        #expect(Sex.unspecified.calorieFloor == Sex.male.calorieFloor)
        #expect(Sex.unspecified.calorieFloor > Sex.female.calorieFloor)

        let unspecified = EnergyTarget.basalRate(sex: .unspecified, weightKg: 70, heightCm: 175, ageYears: 30)
        let female = EnergyTarget.basalRate(sex: .female, weightKg: 70, heightCm: 175, ageYears: 30)
        #expect(unspecified > female, "erring high is the safe direction when the app does not know")
    }

    /// `test_floor_breach_surfaces_slower_rate_option`
    ///
    /// The floor is a hard stop, not a target. Clamping and saying nothing else
    /// leaves the user at the limit with no lever; S1 requires the lever.
    @Test("hitting the floor offers the slower rate that clears it")
    func floorBreachSurfacesSlowerRateOption() {
        let band = EnergyTarget.band(for: Self.lightFemaleLosingFast)

        #expect(band.isAtFloor)
        #expect(band.slowerRate == 0.25, "0.5 kg/week still lands under 1,200 for this user; 0.25 does not")

        let copy = OnboardingCopy.floorApplied(floor: band.floor, slowerRate: band.slowerRate)
        // Compared against the app's own grouping rather than a literal
        // "1,200": the separator is the device's, and a test that hardcodes a
        // comma fails on a phone set to a region that uses a full stop.
        #expect(copy.contains(band.floor.formatted(.number.grouping(.automatic))))
        #expect(copy.contains("slower rate"))
    }

    /// A band that did not hit the floor has nothing to offer and says nothing.
    @Test("a band that clears the floor carries no slower-rate offer")
    func noOfferWhenTheFloorDoesNotBind() {
        var inputs = Self.lightFemaleLosingFast
        inputs.weightKg = 90
        inputs.targetRateKgPerWeek = 0.5

        let band = EnergyTarget.band(for: inputs)

        #expect(!band.isAtFloor)
        #expect(band.slowerRate == nil)
    }

    /// `test_floor_applies_after_deficit_not_before`
    ///
    /// The bug this exists to catch: clamping maintenance and *then* subtracting
    /// the deficit produces a target below the floor while every intermediate
    /// value looks correct.
    @Test("the floor is applied to the deficit-adjusted target, not to maintenance")
    func floorAppliesAfterDeficitNotBefore() {
        let inputs = Self.lightFemaleLosingFast
        let maintenance = EnergyTarget.maintenance(for: inputs)
        let requested = maintenance + EnergyTarget.dailyEnergyOffset(for: inputs)
        let band = EnergyTarget.band(for: inputs)

        #expect(maintenance > 1_200, "the case only tests anything if maintenance clears the floor")
        #expect(requested < 1_200, "…and the deficit takes it below")
        #expect(band.centre == 1_200, "so the answer is the floor, not the deficit-adjusted number")
        #expect(band.centre != Int(maintenance.rounded()), "and not maintenance either")
    }

    /// Maintaining takes no offset at all, and gaining takes a positive one.
    @Test("the energy offset is signed by the goal, not always a deficit")
    func offsetIsSignedByGoal() {
        var inputs = Self.lightFemaleLosingFast
        inputs.targetRateKgPerWeek = 0.5

        inputs.goalType = .maintain
        #expect(EnergyTarget.dailyEnergyOffset(for: inputs) == 0)

        inputs.goalType = .gain
        #expect(EnergyTarget.dailyEnergyOffset(for: inputs) > 0)

        inputs.goalType = .lose
        #expect(EnergyTarget.dailyEnergyOffset(for: inputs) < 0)
    }

    // MARK: - S2 · goal weight against a healthy BMI

    /// `test_goal_weight_below_bmi_18_5_is_rejected`
    @Test("a goal weight below BMI 18.5 is refused, not quietly moved")
    func goalWeightBelowBMI18_5IsRejected() {
        #expect(GoalWeight.check(50, heightCm: 175) == .belowHealthyRange(minimumKg: 56.7))
    }

    /// `test_goal_weight_at_bmi_18_5_is_accepted`
    ///
    /// The boundary itself is inside the range. It also has to be *reachable*:
    /// the minimum is rounded up rather than to nearest, so the number the app
    /// tells the user they can set is a number the rule then accepts.
    @Test("the stated minimum is itself an acceptable goal weight")
    func goalWeightAtBMI18_5IsAccepted() {
        let minimum = GoalWeight.minimumAcceptableKg(heightCm: 175)

        #expect(GoalWeight.check(minimum, heightCm: 175) == .accepted)
        #expect(minimum >= 18.5 * 1.75 * 1.75, "rounded up, or the app advertises a weight it rejects")
    }

    /// `test_rejection_states_the_minimum_acceptable_weight`
    @Test("the refusal names the lowest weight the app will accept")
    func rejectionStatesTheMinimumAcceptableWeight() {
        guard case .belowHealthyRange(let minimumKg) = GoalWeight.check(50, heightCm: 175) else {
            Issue.record("50 kg at 1.75 m is below BMI 18.5 and must be refused")
            return
        }

        let copy = OnboardingCopy.goalWeightRejected(minimumKg: minimumKg)
        #expect(copy.contains("56.7"), "a refusal with no number leaves the user guessing at this one")
        #expect(copy.contains("maintaining"), "and it offers the other way out")
    }

    /// `test_no_upper_bound_on_goal_weight`
    ///
    /// Deliberately asymmetric. The harm S2 addresses runs in one direction.
    @Test("there is no upper bound on goal weight")
    func noUpperBoundOnGoalWeight() {
        #expect(GoalWeight.check(120, heightCm: 175) == .accepted)
        #expect(GoalWeight.check(300, heightCm: 175) == .accepted)
    }

    /// `test_bmi_uses_metres_not_centimetres` — the classic 10,000× bug.
    @Test("BMI is computed in metres")
    func bmiUsesMetresNotCentimetres() {
        let bmi = GoalWeight.bmi(kg: 70, heightCm: 175)

        #expect(abs(bmi - 22.86) < 0.01)
        #expect(abs(GoalWeight.minimumAcceptableKg(heightCm: 175) - 56.7) < 0.01)
    }

    // MARK: - S3 · the rate-of-loss ceiling (onboarding half)

    /// `test_rate_ceiling_is_one_percent_bodyweight_for_light_user`
    @Test("the ceiling is 1% of body weight below the absolute cap")
    func rateCeilingIsOnePercentBodyweightForLightUser() {
        #expect(abs(LossRate.ceiling(forBodyWeightKg: 70) - 0.7) < 0.0001)
        #expect(abs(LossRate.ceiling(forBodyWeightKg: 50) - 0.5) < 0.0001)
    }

    /// `test_rate_ceiling_caps_at_1kg_for_heavy_user`
    @Test("the ceiling never exceeds 1.0 kg a week")
    func rateCeilingCapsAt1kgForHeavyUser() {
        #expect(LossRate.ceiling(forBodyWeightKg: 120) == 1.0)
        #expect(LossRate.ceiling(forBodyWeightKg: 300) == 1.0)
    }

    /// `test_onboarding_hides_rates_above_ceiling`
    ///
    /// Hidden rather than disabled: a control you can see and cannot use is an
    /// invitation to work out how to enable it.
    @Test("rates above the ceiling are not offered at all")
    func onboardingHidesRatesAboveCeiling() {
        #expect(LossRate.selectable(forBodyWeightKg: 70) == [0.25, 0.5])
        #expect(LossRate.selectable(forBodyWeightKg: 80) == [0.25, 0.5, 0.75])
        #expect(LossRate.selectable(forBodyWeightKg: 40) == [0.25])
    }

    /// Below about 25 kg every selectable rate is above the ceiling. Returning
    /// the slowest one anyway would be the app overriding its own limit.
    @Test("when no rate clears the ceiling, none is offered and none is invented")
    func noRateIsInventedBelowTheCeiling() {
        #expect(LossRate.selectable(forBodyWeightKg: 20).isEmpty)
        #expect(LossRate.defaultRate(forBodyWeightKg: 20) == nil)
    }

    /// The default is the middle option, never the fastest available — a default
    /// at the top of the range makes the ceiling the recommendation.
    @Test("the default rate is not the fastest one on offer")
    func defaultRateIsNotTheCeiling() {
        #expect(LossRate.defaultRate(forBodyWeightKg: 80) == 0.5)
        #expect(LossRate.defaultRate(forBodyWeightKg: 70) == 0.5)
        #expect(LossRate.defaultRate(forBodyWeightKg: 40) == 0.25)
    }

    // MARK: - S4 · the age gate

    private static let today = day(2026, 9, 8)

    /// `test_under_18_is_blocked`
    @Test("under 18 is blocked")
    func under18IsBlocked() {
        #expect(AgeGate.outcome(dob: Self.day(2010, 1, 1), on: Self.today, calendar: Self.calendar) == .blocked)
    }

    /// `test_exactly_18_today_is_allowed`
    @Test("the eighteenth birthday itself is allowed")
    func exactly18TodayIsAllowed() {
        #expect(AgeGate.outcome(dob: Self.day(2008, 9, 8), on: Self.today, calendar: Self.calendar) == .allowed)
    }

    /// `test_17_years_364_days_is_blocked`
    ///
    /// The case a year subtraction gets wrong: same birth year as an adult, one
    /// day short of the birthday.
    @Test("one day before the eighteenth birthday is blocked")
    func seventeenYears364DaysIsBlocked() {
        #expect(AgeGate.outcome(dob: Self.day(2008, 9, 9), on: Self.today, calendar: Self.calendar) == .blocked)
    }

    /// A leap-day birth, because February 29th is where hand-rolled age
    /// arithmetic goes wrong and the calendar's does not.
    @Test("a leap-day birthday turns 18 on the calendar's own answer")
    func leapDayBirthdayIsHandledByTheCalendar() {
        let dob = Self.day(2008, 2, 29)

        #expect(AgeGate.outcome(dob: dob, on: Self.day(2026, 2, 28), calendar: Self.calendar) == .blocked)
        #expect(AgeGate.outcome(dob: dob, on: Self.day(2026, 3, 1), calendar: Self.calendar) == .allowed)
    }

    /// `test_no_bypass_path_exists_from_the_age_gate`
    ///
    /// Asserted on the type rather than on a screen: there are two outcomes and
    /// no third, no parameter relaxes the minimum, and the gate is recomputed
    /// from the stored date of birth on every launch — so signing out and back
    /// in lands in the same place.
    @Test("the age gate has two answers and no way through")
    func noBypassPathExistsFromTheAgeGate() {
        #expect(AgeGate.Outcome.allCases.count == 2)
        #expect(AgeGate.minimumAge == 18)

        let profile = Profile(id: UUID(), dob: Self.day(2012, 5, 5))
        #expect(!profile.isAdult(on: Self.today, calendar: Self.calendar))
        #expect(!profile.isAdult(on: Self.day(2029, 5, 4), calendar: Self.calendar))
        #expect(profile.isAdult(on: Self.day(2030, 5, 5), calendar: Self.calendar))
    }

    /// `test_age_gate_screen_includes_support_signposting`
    ///
    /// A user turned away should not leave with nothing.
    @Test("the age gate screen signposts Beat's youth helpline")
    func ageGateScreenIncludesSupportSignposting() {
        #expect(Signposting.beat.site == "beateatingdisorders.org.uk")
        #expect(Signposting.youthHelpline.contains("Beat"))
        #expect(Signposting.youthHelpline.lowercased().contains("helpline"))
        #expect(OnboardingCopy.ageGateAction == PreSeasonCopy.signOutInstead)
    }
}
