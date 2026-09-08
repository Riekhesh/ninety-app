import Foundation

/// The daily calorie band, and the S1 floor that is allowed to move it.
///
/// **A band, not a number.** §1.2: *"Hitting exactly 1,847 kcal is not a real
/// human goal; landing between 1,750 and 1,950 is."* The band is the unit the
/// whole app works in — adherence is the fraction of days that land inside it
/// (§2.2), and a point target would make that fraction a coin flip.
///
/// It renders as **one figure plus a tolerance**, never as two numbers joined by
/// a dash (`PRODUCT.md`). The dash form reads as a range you are meant to stay
/// between; the tolerance form reads as a target with slack, which is what it is.
struct CalorieBand: Equatable, Sendable {
    /// The figure. Rounded to ten, because a band whose centre is 1,847 has
    /// smuggled the false precision back in through the middle.
    let centre: Int

    /// Half the band's width. `±100` in the artboards.
    let tolerance: Int

    /// §10 S1. True when the floor moved the centre — the target the user asked
    /// for was below what the app will set, and it was clamped rather than
    /// refused.
    let isAtFloor: Bool

    /// The floor that applied, whether or not it bound. Carried so the copy can
    /// name the number rather than describing it.
    let floor: Int

    /// The lever that actually helps when the floor binds: the fastest rate
    /// still selectable that would not hit it. Nil when nothing slower would
    /// clear the floor either, or when the floor did not bind at all.
    ///
    /// S1 is explicit that this matters: *"the correct response is to reduce the
    /// rate, not to sit at the floor indefinitely — the floor is a hard stop,
    /// not a target."* A clamp with no way out is a dead end wearing a limit's
    /// clothes.
    let slowerRate: Double?

    var lower: Int { centre - tolerance }
    var upper: Int { centre + tolerance }
}

/// Mifflin-St Jeor, the deficit, and the floor — in that order.
///
/// The order is the whole of `test_floor_applies_after_deficit_not_before`.
/// Clamping maintenance and *then* subtracting a deficit would produce a target
/// below the floor while every intermediate value looked fine, which is the
/// version of this bug that a test written the obvious way does not catch.
enum EnergyTarget {
    /// `±100`. One value, here, because a tolerance that varies per user is a
    /// second thing to explain for no measured benefit.
    static let tolerance = 100

    /// The energy in a kilogram of body mass, as the figure everyone uses.
    ///
    /// It is an approximation of a physiological quantity that varies between
    /// people, which is exactly why the output is a band. Ninety does not claim
    /// this number is true for you; it claims it is a reasonable starting point
    /// and that the app adjusts as it sees real data.
    static let kcalPerKilogram = 7_700.0

    /// Mifflin-St Jeor: `(10 × kg) + (6.25 × cm) − (5 × age) + s`.
    ///
    /// **`unspecified` takes the male constant on purpose.** S1 sets out the
    /// principle for a sex nobody stated — *"use the higher floor when unsure;
    /// erring high is the safe direction"* — and the same principle applies one
    /// step earlier. A higher basal rate means a higher target means more food,
    /// and for a value the app is guessing at, more food is the side to be wrong
    /// on. Averaging the two constants would be more accurate on a population
    /// and less safe on the individual who declined to say.
    static func basalRate(sex: Sex, weightKg: Double, heightCm: Double, ageYears: Int) -> Double {
        let constant: Double
        switch sex {
        case .female: constant = -161
        case .male, .unspecified: constant = 5
        }
        return (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) + constant
    }

    /// Basal rate times the activity factor. What the user burns in a day doing
    /// what they already do.
    static func maintenance(for inputs: EnergyInputs) -> Double {
        basalRate(
            sex: inputs.sex,
            weightKg: inputs.weightKg,
            heightCm: inputs.heightCm,
            ageYears: inputs.ageYears
        ) * inputs.activityLevel.multiplier
    }

    /// The daily gap a weekly rate of change implies.
    ///
    /// Zero for maintain, and it is a *surplus* rather than a deficit for gain —
    /// which is why this returns a signed number and the caller adds it.
    static func dailyEnergyOffset(for inputs: EnergyInputs) -> Double {
        let daily = inputs.targetRateKgPerWeek * kcalPerKilogram / 7
        switch inputs.goalType {
        case .lose: return -daily
        case .maintain: return 0
        case .gain: return daily
        }
    }

    /// The band, with S1 applied last.
    static func band(for inputs: EnergyInputs) -> CalorieBand {
        let floor = inputs.sex.calorieFloor
        let requested = maintenance(for: inputs) + dailyEnergyOffset(for: inputs)
        let clamped = max(requested, Double(floor))
        let isAtFloor = requested < Double(floor)

        return CalorieBand(
            centre: roundedToTen(clamped),
            tolerance: tolerance,
            isAtFloor: isAtFloor,
            floor: floor,
            slowerRate: isAtFloor ? fastestRateClearingTheFloor(for: inputs) : nil
        )
    }

    /// The band for a profile and a weight reading, or nil if Pre-Season has not
    /// collected enough to compute one.
    ///
    /// Nil rather than a default: a band computed from a guessed height is a
    /// number nobody measured, and inventing one is the single thing the design
    /// principles rule out outright.
    static func band(
        for profile: Profile,
        weightKg: Double?,
        on day: Date,
        calendar: Calendar
    ) -> CalorieBand? {
        guard
            let inputs = EnergyInputs(profile: profile, weightKg: weightKg, on: day, calendar: calendar)
        else { return nil }
        return band(for: inputs)
    }

    /// The fastest selectable rate whose band would clear the floor.
    ///
    /// Searched from the slowest up, so the answer is the *largest* rate that
    /// works rather than the first one tried. Returns nil when even the slowest
    /// selectable rate hits the floor — at which point the honest lever is a
    /// different goal, not a different rate, and the copy says so.
    private static func fastestRateClearingTheFloor(for inputs: EnergyInputs) -> Double? {
        LossRate.selectable
            .filter { $0 < inputs.targetRateKgPerWeek }
            .sorted()
            .last { rate in
                var slower = inputs
                slower.targetRateKgPerWeek = rate
                return maintenance(for: slower) + dailyEnergyOffset(for: slower) >= Double(inputs.sex.calorieFloor)
            }
    }

    private static func roundedToTen(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }
}

/// Everything the band needs, as values rather than as a `Profile`.
///
/// A struct instead of a model reference so the S1 tests can state a case in one
/// line and so the arithmetic can be exercised without a store. `Profile` gets an
/// initialiser below rather than the arithmetic getting a SwiftData dependency.
struct EnergyInputs: Equatable, Sendable {
    var sex: Sex
    var weightKg: Double
    var heightCm: Double
    var ageYears: Int
    var activityLevel: ActivityLevel
    var goalType: GoalType
    var targetRateKgPerWeek: Double

    init(
        sex: Sex,
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        activityLevel: ActivityLevel,
        goalType: GoalType,
        targetRateKgPerWeek: Double
    ) {
        self.sex = sex
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.ageYears = ageYears
        self.activityLevel = activityLevel
        self.goalType = goalType
        self.targetRateKgPerWeek = targetRateKgPerWeek
    }

    /// Nil unless the profile carries every value the equation needs *and* a
    /// weight reading exists. All four are collected in Pre-Season, so nil means
    /// onboarding has not finished rather than that something went wrong.
    init?(profile: Profile, weightKg: Double?, on day: Date, calendar: Calendar) {
        guard
            let dob = profile.dob,
            let heightCm = profile.heightCm,
            let weightKg,
            let ageYears = calendar.dateComponents([.year], from: dob, to: day).year
        else { return nil }

        self.init(
            sex: profile.sex,
            weightKg: weightKg,
            heightCm: heightCm,
            ageYears: ageYears,
            activityLevel: profile.activityLevel,
            goalType: profile.goalType,
            targetRateKgPerWeek: profile.targetRateKgPerWeek
        )
    }
}
