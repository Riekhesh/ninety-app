import Foundation
import Testing
@testable import Ninety

/// S5, as a test rather than only as a lint rule.
///
/// SwiftLint's `no_punishment_framing` matches string literals in source. This
/// checks the strings the app actually *shows*, which is the thing S5 is about
/// — and it keeps working when copy moves into a strings file in Phase 3.
@Suite("Safety copy (S5)")
struct SafetyCopyTests {
    // Disabled for exactly these six lines, and nowhere else in the app. A test
    // that checks for banned phrases has to be able to name them; the
    // alternatives are excluding this whole file from the rule — which would
    // let a real violation in alongside the list — or splitting the strings so
    // the linter cannot see them, which is dodging a control, not satisfying it.
    //
    // Above the doc comment rather than below it: a plain comment between a doc
    // comment and its declaration orphans the doc comment.
    // swiftlint:disable no_punishment_framing

    /// The 17 phrases banned at lint-error severity, from
    /// `docs/safety/safety-requirements.md`.
    static let banned = [
        "you failed", "you lost", "lost your streak", "streak lost",
        "broke your streak", "streak broken", "you missed", "over budget",
        "exceeded your", "you blew", "ruined", "demoted", "dropped to",
        "too many calories", "bad day", "be better", "no excuses",
    ]
    // swiftlint:enable no_punishment_framing

    /// Every user-facing string the shell renders today. Grows with each epic.
    ///
    /// The tab titles are read from `Destination` rather than retyped, so a
    /// renamed tab is covered automatically instead of quietly falling out of
    /// the list — a hand-copied inventory of strings is a test that decays.
    static var shipped: [String] {
        Destination.allCases.map(\.title)
            + PreSeasonCopy.all
            + AuthFailure.allCases.compactMap(\.errorDescription)
            + AuthFailure.allCases.compactMap(\.recoveryDescription)
            + [
                "Sub On", "Sub on", "Close",
                "No day started", "No readings", "Today", "Nothing logged yet.",
                "Weight", "No weight yet.", "Division",
                "Ranking arrives in the next update.", "How it will be scored",
                "Consistency", "Adherence", "Progress", "Four routes",
                "Logging lands with P1‑F.",
            ]
    }

    /// §10's other absolute: no medical claims anywhere in copy.
    ///
    /// Not in `.swiftlint.yml`, because these are words with legitimate uses —
    /// "treat" and "cure" are only a problem in a sentence about what the app
    /// does — so the check belongs where the shipped inventory is, not on every
    /// string literal in the project.
    static let medicalClaims = [
        "clinically proven", "doctor recommended", "medically approved",
        "diagnose", "diagnosis", "cure", "prevents", "treats your",
    ]

    @Test("no shipped string frames a shortfall as a failure")
    func noPunishmentFraming() {
        for copy in Self.shipped {
            let lowered = copy.lowercased()
            for phrase in Self.banned {
                #expect(!lowered.contains(phrase), "\"\(copy)\" contains banned phrase \"\(phrase)\"")
            }
        }
    }

    @Test("the banned list is the full seventeen")
    func listIsComplete() {
        #expect(Self.banned.count == 17)
    }

    @Test("no shipped string makes a medical claim")
    func noMedicalClaims() {
        for copy in Self.shipped {
            let lowered = copy.lowercased()
            for phrase in Self.medicalClaims {
                #expect(!lowered.contains(phrase), "\"\(copy)\" makes a medical claim: \"\(phrase)\"")
            }
        }
    }

    /// The Article 9 copy has one job beyond being kind: it has to say what is
    /// being consented to. A consent screen that never names health data is not
    /// explicit consent, whatever the timestamps say.
    @Test("the consent copy names health data, the law, and the way out")
    func consentCopyIsExplicit() {
        let health = PreSeasonCopy.healthBody.lowercased()
        #expect(health.contains("health"))
        #expect(health.contains("special category"))
        #expect(health.contains("explicit consent"))
        #expect(PreSeasonCopy.healthBody.contains("separately from the terms"))
        #expect(PreSeasonCopy.healthDetail.lowercased().contains("withdraw"))
    }
}
