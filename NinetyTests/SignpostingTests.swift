import Foundation
import Testing
@testable import Ninety

/// §10 S7 · signposting, the half of it that is Phase 1.
///
/// **Always available in Settings** is built. The pattern-based triggers —
/// sustained loss above the S3 ceiling, sustained intake near the S1 floor,
/// repeated goal-weight refusals — are a Phase 3 gate with their own named
/// tests, and none of them exist yet. This suite covers exactly what is claimed.
@Suite("Signposting (S7)")
struct SignpostingTests {
    /// `test_signposting_always_available_in_settings`
    ///
    /// Asserted on the section list rather than on a rendered view: what makes
    /// this requirement true is that the panel is unconditional, and a section
    /// that is always in `allCases` cannot be behind a flag.
    @Test("support is a permanent section of Settings, not a conditional one")
    func signpostingAlwaysAvailableInSettings() {
        #expect(SettingsSection.allCases.contains(.support))
        #expect(!Signposting.resources.isEmpty)

        #expect(Signposting.beat.phone == "0808 801 0677")
        #expect(Signposting.beat.site == "beateatingdisorders.org.uk")
        #expect(Signposting.nationalAlliance.site == "eatingdisorderinfo.org")
    }

    /// A resource with no phone number is a real case, not a missing value —
    /// and it must not be announced as though it had one.
    @Test("a web-only resource does not advertise a phone number")
    func webOnlyResourceHasNoPhone() {
        #expect(Signposting.nationalAlliance.phone == nil)
        #expect(!Signposting.nationalAlliance.accessibilityLabel.contains("0808"))
        #expect(Signposting.beat.accessibilityLabel.contains("0808 801 0677"))
    }

    /// `test_signposting_copy_contains_no_diagnostic_language`
    ///
    /// The app does not detect eating disorders, must not imply that it can, and
    /// says only that these people help — which is true and inside what it can
    /// honestly claim.
    ///
    /// Run over `appPhrasing` rather than `all`: *"National Alliance for Eating
    /// Disorders"* is a charity's name, not Ninety asserting something about the
    /// user, and a check that cannot tell those apart would force the app to
    /// misname the organisation it is pointing at.
    @Test("nothing in the signposting copy claims to have noticed anything")
    func signpostingCopyContainsNoDiagnosticLanguage() {
        let diagnostic = [
            "disorder", "symptom", "condition", "diagnos", "we've noticed",
            "we have noticed", "you may have", "you might have", "at risk",
            "unhealthy relationship", "concerning",
        ]

        for copy in Signposting.appPhrasing {
            let lowered = copy.lowercased()
            for phrase in diagnostic {
                #expect(!lowered.contains(phrase), "\"\(copy)\" contains diagnostic language: \"\(phrase)\"")
            }
        }
    }

    /// The intro is conditional and about a feeling, not an assertion about the
    /// user. The distinction is the whole of "no diagnosis".
    @Test("the offer is conditional, and it names the limit of what Ninety is")
    func theOfferIsConditional() {
        #expect(Signposting.intro.lowercased().hasPrefix("if "))
        #expect(Signposting.disclaimer.contains("isn't a substitute"))
        #expect(Signposting.notAMedicalDevice.contains("Not a medical device"))
    }
}
