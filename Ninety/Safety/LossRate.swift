import Foundation

/// §10 S3 · the rate-of-loss ceiling, as onboarding enforces it.
///
/// ```
/// ceiling = min(1.0 kg/week, 1% of current body weight per week)
/// ```
///
/// Two enforcement points are specified and only one of them is Phase 1. This is
/// the onboarding half: a rate above the ceiling cannot be *selected*. The other
/// half — the progress score peaking at the target rate and declining above it —
/// is Phase 2, lives in `Packages/RankingEngine`, and is the half that actually
/// matters: *"a ceiling only in onboarding is advice; a ceiling in the score is
/// an incentive."* Nothing here should be read as having satisfied S3 on its own.
enum LossRate {
    /// The three rates offered, in the copy deck's order. There is deliberately
    /// no "maximum" option: an app that offers one has told the user which
    /// answer it thinks is best.
    static let selectable: [Double] = [0.25, 0.5, 0.75]

    /// The absolute cap, which binds for anyone heavy enough that 1% of their
    /// body weight exceeds it.
    static let absoluteCeiling = 1.0

    /// The proportion of body weight per week that the ceiling tracks below
    /// the absolute cap.
    static let bodyWeightFraction = 0.01

    /// `min(1.0, 1% of body weight)`. 0.70 at 70 kg; 1.0 at 120 kg.
    static func ceiling(forBodyWeightKg kg: Double) -> Double {
        min(absoluteCeiling, kg * bodyWeightFraction)
    }

    /// The rates onboarding may show. Filtered, not disabled: a control that is
    /// visible and unusable invites the user to work out how to enable it.
    ///
    /// **Can be empty**, and that is a real answer rather than an edge case to
    /// paper over. Below 25 kg every selectable rate is above the ceiling, and
    /// the honest response is that losing weight is not what this app should be
    /// helping with — which is what the goal step says when this returns
    /// nothing. Substituting the slowest rate anyway would be the app quietly
    /// overriding its own limit.
    static func selectable(forBodyWeightKg kg: Double) -> [Double] {
        let ceiling = ceiling(forBodyWeightKg: kg)
        return selectable.filter { $0 <= ceiling }
    }

    /// Whether a chosen rate is inside the ceiling for a given weight.
    static func isWithinCeiling(_ rate: Double, forBodyWeightKg kg: Double) -> Bool {
        rate <= ceiling(forBodyWeightKg: kg)
    }

    /// The default the goal step lands on: the middle selectable rate, or the
    /// fastest available when the ceiling has taken the middle one away.
    ///
    /// Not the fastest available in general. The default is the one most users
    /// keep, so defaulting to the top of the range would make the ceiling the
    /// recommendation, which is the exact inversion S3 exists to prevent.
    static func defaultRate(forBodyWeightKg kg: Double) -> Double? {
        let available = selectable(forBodyWeightKg: kg)
        return available.contains(0.5) ? 0.5 : available.first
    }

    /// `0.5 kg/week`, formatted the way the copy deck writes it.
    static func label(for rate: Double) -> String {
        let name: String
        switch rate {
        case 0.25: name = "Steady"
        case 0.5: name = "Moderate"
        default: name = "Faster"
        }
        return "\(name) · \(formatted(rate)) kg/week"
    }

    /// Trims the trailing zero: `0.5`, not `0.50`; `0.25` stays `0.25`.
    static func formatted(_ rate: Double) -> String {
        String(format: "%g", rate)
    }
}
