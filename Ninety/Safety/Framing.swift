import SwiftUI

/// §10 S5 · the structural half of "no punishment framing".
///
/// The verbal half is a lint rule and a copy deck: seventeen banned phrases at
/// `error` severity, plus `SafetyCopyTests` sweeping the strings the app
/// actually shows. That half is done and it is the easier half.
///
/// This is the other half, and it is the one that is normally missed, because it
/// is not made of words. §10 lists it as design rather than copy:
///
/// - **No error colour exists for logged intake.** Absent from the token set on
///   purpose — a designer reaching for "the red one" for over-band will not find
///   one.
/// - **A missed day is empty, never crossed out.**
/// - **No streak-loss animation.**
/// - **Losing a division always states the way back.**
///
/// A rule kept only in a spec is a rule the next screen forgets. These types are
/// how the rule reaches the compiler: the states a day and a band can be in are
/// enumerated here, none of them can carry `critical`, and P1-G, P1-H and Phase 2
/// render from them rather than each inventing their own.

/// How a value is coloured, for anything the user logged.
///
/// **There is no `critical` case, and that is the entire design.** `critical`
/// exists in the token set for exactly one thing — a destructive confirmation,
/// "delete your account and all of it" — and it is not reachable from here. A
/// future screen that wants to paint an over-band day red has to add a case to
/// this enum, which is a diff somebody reads, rather than typing a colour name,
/// which is not.
enum Tone: Equatable, Sendable, CaseIterable {
    /// The default. Most facts are just facts.
    case neutral

    /// Confirmations. Never used to reward faster loss (S3).
    case positive

    /// §10 interventions — the floor, the rate ceiling, the goal-weight refusal.
    /// Shares gold's hue deliberately: on this surface a safety notice reads as
    /// the app's own voice rather than as an alarm.
    case safety

    var colour: Color {
        switch self {
        case .neutral: Ninety.Colour.textPrimary
        case .positive: Ninety.Colour.positive
        case .safety: Ninety.Colour.safety
        }
    }
}

/// Where a day's intake landed against the band.
///
/// Three states, and the naming is doing work. "Above your band" is a fact;
/// "over budget" is a judgement that frames food as money already spent, and it
/// is on the banned list for that reason.
enum BandState: Equatable, Sendable, CaseIterable {
    case below
    case inBand
    case above

    /// Which side of the band a total sits on. The band's own bounds decide;
    /// nothing here rounds or nudges.
    static func of(kcal: Int, band: CalorieBand) -> BandState {
        if kcal < band.lower { return .below }
        if kcal > band.upper { return .above }
        return .inBand
    }

    /// The copy deck's wording, unchanged.
    var label: String {
        switch self {
        case .below: "Below your band"
        case .inBand: "In your band"
        case .above: "Above your band"
        }
    }

    /// **`.above` is `.neutral`, not a warning.** Landing above the band is a
    /// normal outcome of a normal day and the app has no business editorialising
    /// about it. `.below` gets `.safety` because eating well under the band is
    /// the direction §10 cares about, and it comes with the sentence explaining
    /// why rather than a colour on its own.
    var tone: Tone {
        switch self {
        case .below: .safety
        case .inBand: .positive
        case .above: .neutral
        }
    }

    /// The note that has to accompany `.below`. §10's rewrite rule: state the
    /// fact, then answer "what now?".
    var note: String? {
        switch self {
        case .below: "Eating well under your band slows progress more often than it speeds it up."
        case .inBand, .above: nil
        }
    }
}

/// One day in the Form ring (§2.2's seven discrete days).
///
/// Two cases. A missed day is **absent**, not negative: it renders as an empty
/// segment in `stroke`, with no cross, no colour and no animation on the
/// transition. §1 spells out what the alternative costs — a ring that marks
/// failure is a ring people stop looking at, and then they stop logging.
enum DayMark: Equatable, Sendable, CaseIterable {
    case logged
    case missed

    /// The only property the ring needs. There is no `isFailed`, no `isBroken`,
    /// and nothing that would let a view draw a cross.
    var isFilled: Bool { self == .logged }

    /// What a segment is painted with. `stroke` for a missed day: the same
    /// hairline as the empty ring, so a missed day is a gap rather than a mark.
    var colour: Color { isFilled ? Ninety.Colour.positive : Ninety.Colour.stroke }
}
