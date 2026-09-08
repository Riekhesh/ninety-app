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
            + OnboardingCopy.all
            + SettingsCopy.all
            + SubOnCopy.all
            + Signposting.all
            + AuthFailure.allCases.compactMap(\.errorDescription)
            + AuthFailure.allCases.compactMap(\.recoveryDescription)
            // S5's structural half has copy too: the words on the states that
            // are not allowed to be punitive.
            + BandState.allCases.map(\.label)
            + BandState.allCases.compactMap(\.note)
            + LossRate.selectable.map { LossRate.label(for: $0) }
            // P1-F's own states, which are not strings in `SubOnCopy` because
            // they are built from one.
            + EstimateConfidence.allCases.map(\.label)
            + EstimateConfidence.allCases.compactMap(\.note)
            + MealEstimateError.allCases.compactMap(\.errorDescription)
            + MealEstimateError.allCases.map(\.recoveryDescription)
            + CatalogueError.allCases.compactMap(\.errorDescription)
            + [
                "Sub on", "Sub on. Log food.",
                "No day started", "No readings", "Today", "Nothing logged yet.",
                "Weight", "No weight yet.", "Division",
                "Ranking arrives in the next update.", "How it will be scored",
                "Consistency", "Adherence", "Progress",
                "Settings, support and your consent",
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

    /// §10 S5's structural half, which is the half normally missed because it
    /// is not made of words.
    ///
    /// The token set has no error colour for logged intake, and `Tone` is why:
    /// it has no `critical` case, so a screen cannot reach for one without
    /// adding a case to an enum — a diff somebody reads, rather than a colour
    /// name somebody types.
    @Test("no state a user's own logging can reach is painted as an error")
    func loggedIntakeHasNoErrorState() {
        // Three tones and no fourth. There is deliberately no assertion that
        // `critical` is absent, because there is no way to write one: the case
        // does not exist, so the check is the compiler's rather than this
        // suite's — which is the stronger version of the same guarantee.
        #expect(Tone.allCases.count == 3)
        #expect(Tone.allCases == [.neutral, .positive, .safety])

        // Landing above the band is a normal outcome of a normal day. Anything
        // else is the app editorialising about a meal.
        #expect(BandState.above.tone == .neutral)
        #expect(BandState.above.label == "Above your band")
        #expect(BandState.inBand.tone == .positive)

        // A missed day is absent, not negative: an empty segment, no cross, no
        // colour of its own.
        #expect(DayMark.allCases.count == 2)
        #expect(!DayMark.missed.isFilled)
    }

    /// §1.2 and the Under Review ticket: a range is a figure and a tolerance,
    /// never two numbers joined by a dash. It is in this suite rather than only
    /// in `MealEstimateTests` because it is a rendering rule about how a number
    /// is presented to a user, which is the same class of thing S5 is about —
    /// `120–160` reads as a rule you are failing to stay inside, and `140 ±20`
    /// reads as an estimate with slack in it.
    @Test("no number the app shows is rendered as a dashed range")
    func rangesAreNeverDashed() {
        let band = CalorieBand(
            centre: 1_850,
            tolerance: 100,
            isAtFloor: false,
            floor: 1_500,
            slowerRate: nil
        )
        let rendered = [
            Figure.range(EstimateRange(low: 290, high: 390)),
            Figure.range(EstimateRange(low: 23, high: 91)),
            OnboardingCopy.band(band),
        ]
        for copy in rendered {
            for dash in ["–", "—", " - ", " to "] {
                #expect(!copy.contains(dash), "\"\(copy)\" renders a range as a span rather than a tolerance")
            }
            #expect(copy.contains("±"))
        }
    }

    /// ADR 0018 halved the calibration window, and the number appears in copy as
    /// well as in `CalibrationWindow.days`. The two have to agree, or the app
    /// counts down from one number while promising another.
    @Test("the calibration copy says the same number of days the window is")
    func calibrationCopyMatchesTheWindow() {
        #expect(CalibrationWindow.days == 7)
        #expect(OnboardingCopy.calibrationBody.contains("7 days"))
        #expect(OnboardingCopy.calibrationTitle.contains("first week"))
        #expect(!OnboardingCopy.calibrationBody.contains("14"))
        #expect(!OnboardingCopy.calibrationTitle.contains("two weeks"))
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
