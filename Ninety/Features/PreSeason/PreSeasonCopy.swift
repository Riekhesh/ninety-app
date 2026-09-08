import Foundation

/// Every string the two Pre-Season screens render, in one place.
///
/// Not a strings file and not localisation — it is a *test surface*. S5 is
/// checked against the copy the app actually shows (`SafetyCopyTests`), and a
/// hand-copied inventory of strings is a test that decays the first time
/// somebody edits a view. Constants here mean the test reads the same value the
/// screen does, and the copy deck stays the source both are written from.
///
/// `design/spec/04-copy-deck.md` §1 is that source. Change it there first.
enum PreSeasonCopy {
    // MARK: - Sign in

    static let signInTitle = "Ninety"
    static let pitch = "Ranked on how much you improve — not on how you compare to anyone else."
    static let signInFootnote = """
        We ask for your date of birth, height and sex because the scoring engine needs them. \
        Nothing else.
        """
    static let notConfiguredHeadline = "This build isn't connected to a Ninety project yet."
    static let launchLabel = "Ninety is opening."

    // MARK: - Consent

    static let consentMasthead = "Pre-Season"
    static let consentMeta = "Consent"
    static let consentTitle = "Before Ninety holds anything"

    static let termsHeading = "Terms of use"
    static let termsBody = """
        What Ninety does, what it doesn't promise, and that it isn't a medical device \
        and makes no medical claims.
        """
    static let termsAction = "I accept the terms"

    static let healthHeading = "Health data"
    static let healthBody = """
        What you log — food, weight, and what Ninety reads from Apple Health — is special \
        category data under UK GDPR. Processing it needs your explicit consent, given \
        separately from the terms above.
        """
    /// The last sentence arrived with P1-D and is not decoration.
    ///
    /// Until Settings existed, this said what withdrawal *does* and pointedly not
    /// where to find it — copy naming a screen that does not exist is the same
    /// failure as an invented number. Both switches are now in Settings, so the
    /// sentence is true, and saying it is what makes withdrawal as easy as
    /// giving. Consent that is not is not freely given.
    static let healthDetail = """
        It stays on your phone and in Ninety's database. It isn't sold, and it isn't shared \
        with anyone. Withdrawing consent stops Ninety processing anything new; it doesn't \
        delete what's already logged, which is a separate request. Both switches are in \
        Settings whenever you want them.
        """
    static let healthAction = "I consent to Ninety processing my health data"

    static let bothNeeded = "Ninety needs both to start. Health data is what the app is made of."
    static let signOutInstead = "Sign out instead"
    static let kickOff = "Kick off"
    static let consentDidNotSave = "That didn't save. Try the switch again."

    /// Everything above, for the S5 sweep. Listed by reference rather than
    /// retyped, so a new string is one edit and not two.
    static let all: [String] = [
        signInTitle, pitch, signInFootnote, notConfiguredHeadline, launchLabel,
        consentMasthead, consentMeta, consentTitle,
        termsHeading, termsBody, termsAction,
        healthHeading, healthBody, healthDetail, healthAction,
        bothNeeded, signOutInstead, kickOff, consentDidNotSave,
    ]
}
