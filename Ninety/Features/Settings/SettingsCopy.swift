import Foundation

/// Every string Settings renders, in one place.
///
/// Same reasoning as `PreSeasonCopy`: this is a *test surface*, not a strings
/// file. `SafetyCopyTests` sweeps the copy the app actually shows, and a
/// hand-copied inventory decays the first time somebody edits a view.
///
/// `design/spec/04-copy-deck.md` §2 and §7 are the source. Change it there first.
enum SettingsCopy {
    static let masthead = "Settings"

    // MARK: - S6 · the competitive opt-out

    static let competitiveHeading = "Competitive features"
    static let competitiveBody = """
        Turns off tiers, ranks and scores. Logging, your weight trend and Apple Health sync all \
        keep working exactly as they do now.
        """
    static let competitiveAction = "Turn off competitive features"
    static let competitiveOffNote = """
        Competitive features are off. You can turn them back on any time — your history is kept.
        """

    // MARK: - S7 · signposting

    static let supportHeading = "Support"

    // MARK: - Consent (ADR 0017)

    static let consentHeading = "Your consent"
    static let consentBody = """
        Both decisions are yours to change. Withdrawing is the same switch that gave it, in the \
        same place.
        """
    static let withdrawalReturnsNote = """
        Ninety can't process health data without your consent, so withdrawing it brings back the \
        consent screen. Nothing already logged is deleted.
        """

    // MARK: - Account

    static let accountHeading = "Account"
    static let signOut = "Sign out"
    static let signOutNote = """
        Signs you out on this phone. What's logged stays on the device and comes back when you \
        sign in again.
        """

    /// Everything above, for the S5 sweep. Listed by reference rather than
    /// retyped, so a new string is one edit and not two.
    static let all: [String] = [
        masthead,
        competitiveHeading, competitiveBody, competitiveAction, competitiveOffNote,
        supportHeading,
        consentHeading, consentBody, withdrawalReturnsNote,
        accountHeading, signOut, signOutNote,
    ]
}

/// The order Settings is built in, as a value rather than as the order somebody
/// happened to type the panels.
///
/// **S6 requires the opt-out to be reachable in at most two taps from Matchday**
/// — the masthead control is the first, the switch is the second — and that is
/// only true while the opt-out is the panel you land on. A later epic adding a
/// section above it would break the requirement silently, in a diff that looks
/// like a reordering. `CompetitiveOptOutTests` asserts this order, so it does not.
enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    /// S6. First, and the test says so.
    case competitive
    /// S7. Permanently available, never behind a disclosure.
    case support
    /// P1-I. Where the day's logging currently is. Not a §10 obligation — it is
    /// the one surface that can tell a day spent offline from a day quietly
    /// lost, which is what the airplane-mode exit criterion is read off.
    case sync
    /// Article 9 withdrawal (ADR 0017).
    case consent
    /// Sign out. Last because it is the way out, not the point of the screen.
    case account

    var id: String { rawValue }

    /// Taps from Matchday to the opt-out switch: the masthead control, then the
    /// switch itself. Named here so the number is asserted rather than assumed.
    static let tapsToCompetitiveOptOut = 2
}
