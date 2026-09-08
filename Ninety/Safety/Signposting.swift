import Foundation

/// §10 S7 · UK support resources, permanently available in Settings.
///
/// Two halves, and only the first is Phase 1. **Always available in Settings** is
/// built here. **Additionally surfaced** when a pattern suggests it may help —
/// sustained loss above the S3 ceiling, sustained intake near the S1 floor,
/// repeated goal-weight refusals — is a Phase 3 gate with its own named tests,
/// and none of it exists yet.
///
/// **No diagnosis, in the copy as well as in the logic.** The app does not detect
/// eating disorders, must not imply that it can, and says only *"if this is
/// feeling difficult, these people help"* — which is true, and inside what the
/// app can honestly claim. `SafetyCopyTests` checks these strings against the
/// medical-claim list along with everything else the app shows.
enum Signposting {
    /// One organisation, as it appears on screen.
    struct Resource: Identifiable, Equatable, Sendable {
        let name: String
        /// Phone number where there is one. Nil is not a lesser entry — the
        /// National Alliance is a web resource and pretending otherwise would
        /// send someone looking for a number that does not exist.
        let phone: String?
        let site: String

        var id: String { name }

        /// Read as one thing by VoiceOver: a name, then a number, then a site,
        /// announced as three separate elements is three swipes to learn one
        /// fact.
        var accessibilityLabel: String {
            [name, phone, site].compactMap { $0 }.joined(separator: ". ")
        }
    }

    static let beat = Resource(
        name: "Beat",
        phone: "0808 801 0677",
        site: "beateatingdisorders.org.uk"
    )

    static let nationalAlliance = Resource(
        name: "National Alliance for Eating Disorders",
        phone: nil,
        site: "eatingdisorderinfo.org"
    )

    static let resources: [Resource] = [beat, nationalAlliance]

    /// The copy deck's wording, unchanged. Conditional, non-accusatory, and it
    /// describes a feeling rather than asserting a condition.
    static let intro = "If your relationship with food or your body is feeling difficult, these people help:"

    /// The line that keeps the app in its lane.
    static let disclaimer = "Ninety isn't a substitute for either of them."

    /// §10's footer, everywhere it fits.
    static let notAMedicalDevice = """
        Not a medical device. Ninety makes no medical claims and is not a substitute for \
        professional advice.
        """

    /// Shown on the age-gate screen, which is the one place someone leaves the
    /// app because Ninety turned them away. S4 requires that they do not leave
    /// with nothing.
    ///
    /// The address is not in the sentence: the screen renders `beat.site`
    /// underneath it, so there is one copy of the URL in the project rather than
    /// two that can drift apart.
    static let youthHelpline = """
        If you're looking for support with eating or body image, Beat has a youth helpline.
        """

    /// **What Ninety itself says**, as opposed to what the organisations are
    /// called.
    ///
    /// The split matters for one test. S7 forbids diagnostic language, and the
    /// obvious check — sweep every signposting string for words like "disorder"
    /// — fails on *"National Alliance for Eating Disorders"* and on Beat's own
    /// domain. Those are proper nouns; a charity's name is not the app making a
    /// claim about the user. This is the set that is the app's own voice, and it
    /// is the set that check runs over.
    static let appPhrasing: [String] = [intro, disclaimer, notAMedicalDevice, youthHelpline]

    /// Everything, including the names and contact details, for the S5 and
    /// medical-claim sweeps.
    static var all: [String] {
        appPhrasing
            + resources.map(\.name)
            + resources.compactMap(\.phone)
            + resources.map(\.site)
    }
}
