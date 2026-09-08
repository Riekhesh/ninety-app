import Foundation

/// §10 S2 · goal weight validated against a healthy BMI.
///
/// ```
/// BMI = kg / (m × m)
/// minimum acceptable goal weight = 18.5 × height_m²
/// ```
///
/// **Reject, do not clamp** — the opposite of S1, and deliberately so. A calorie
/// target the user never typed can be moved silently because it was the app's
/// number to begin with. A goal weight is the user's own statement of what they
/// are aiming at, and substituting a different one would make the whole app
/// dishonest about what it is tracking toward.
///
/// **Deliberately asymmetric.** There is no upper bound. Someone aiming to gain
/// to a BMI of 27 is not doing something this app should block; the harm S2
/// addresses runs in one direction only, and a symmetric rule would be the app
/// having opinions about bodies rather than holding a safety limit.
enum GoalWeight {
    /// The bottom of the healthy BMI range in the public guidance S2 is drawn
    /// from. Unreviewed by a clinician — see the warning in
    /// `docs/safety/safety-requirements.md`.
    static let minimumBMI = 18.5

    /// The lightest goal the app will accept for a height, in kilograms.
    ///
    /// **Rounded up**, not to nearest. The number this returns is shown to the
    /// user as the value they *can* set, so rounding 56.66 down to 56.6 would
    /// advertise a weight the rule then rejects — a limit that contradicts its
    /// own error message. One decimal place, because a goal weight stated to the
    /// gram is false precision about an estimate.
    static func minimumAcceptableKg(heightCm: Double) -> Double {
        let metres = heightCm / 100
        let exact = minimumBMI * metres * metres
        return (exact * 10).rounded(.up) / 10
    }

    /// BMI for a weight and a height. In metres — the 10,000× bug this exists to
    /// make impossible is what `test_bmi_uses_metres_not_centimetres` names.
    static func bmi(kg: Double, heightCm: Double) -> Double {
        let metres = heightCm / 100
        return kg / (metres * metres)
    }

    /// What the app does with a proposed goal weight.
    ///
    /// Two cases, and there is no third: no override, no "set it anyway", no
    /// confirm-twice path. A rule with an escape hatch is a suggestion.
    enum Verdict: Equatable, Sendable {
        case accepted

        /// Rejected, carrying the number the user needs in order to answer.
        /// Handing back a refusal without the minimum leaves them guessing, and
        /// guessing at this particular number is not a neutral activity.
        case belowHealthyRange(minimumKg: Double)
    }

    static func check(_ kg: Double, heightCm: Double) -> Verdict {
        let minimum = minimumAcceptableKg(heightCm: heightCm)
        return kg >= minimum ? .accepted : .belowHealthyRange(minimumKg: minimum)
    }
}
