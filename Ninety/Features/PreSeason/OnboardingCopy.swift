import Foundation

/// Every string Pre-Season renders, in one place — same test surface as
/// `PreSeasonCopy`, kept separate only because there is a lot of it.
///
/// `design/spec/04-copy-deck.md` §1 and §2 are the source. Change it there first.
///
/// **Every §10 gate states itself here rather than hiding behind a silent
/// validation.** That is the story's acceptance criterion and it is also the
/// point: a limit the user can read is a limit they can work with, and a control
/// that refuses without saying why reads as a bug.
enum OnboardingCopy {
    static let masthead = "Pre-Season"

    /// `Step 2 of 4`. Position stated rather than a progress bar: a bar answers
    /// "how far" and not "how much longer", and four is a small enough number to
    /// just say.
    static func stepMeta(_ step: Int, of total: Int) -> String {
        "Step \(step) of \(total)"
    }

    static let next = "Next"
    static let back = "Back"
    static let didNotSave = "That didn't save. Try again."

    // MARK: - About you

    static let aboutYouTitle = "A few things the engine needs"
    static let aboutYouFootnote = """
        Used to work out a realistic starting point for you. Not shared with anyone.
        """
    static let dateOfBirth = "Date of birth"
    static let height = "Height"
    static let heightUnit = "cm"
    static let heightInvalid = "Height should be between 100 and 250 cm."
    static let sex = "Sex"
    static let activityLevel = "Activity level"

    static let sexFemale = "Female"
    static let sexMale = "Male"
    static let sexUnspecified = "Prefer not to say"
    /// S1's higher floor for an unstated sex, said out loud. The user declined a
    /// question and is told what the app does about it instead of the app
    /// quietly guessing.
    static let sexUnspecifiedNote = """
        Ninety uses the higher of the two calorie floors when you'd rather not say. Erring high is \
        the safe direction.
        """

    static let activitySedentary = "Sedentary"
    static let activitySedentaryDetail = "Desk job, little deliberate exercise"
    static let activityLight = "Light"
    static let activityLightDetail = "Walking most days, or one or two sessions a week"
    static let activityModerate = "Moderate"
    static let activityModerateDetail = "Three or four sessions a week"
    static let activityActive = "Active"
    static let activityActiveDetail = "Five or six sessions a week, or an active job"
    static let activityVeryActive = "Very active"
    static let activityVeryActiveDetail = "Training most days, or heavy physical work"

    // MARK: - Starting weight

    static let weightTitle = "Where you're starting"
    static let weightBody = """
        Ninety ranks on how much you improve against your own baseline, so it needs to know where \
        the baseline starts.
        """
    static let weightLabel = "Today's weight"
    static let weightUnit = "kg"
    static let weightInvalid = "Weight should be between 25 and 400 kg."
    static let weightFootnote = """
        This becomes the first reading on your weight trend. You can add today's again later if \
        you weigh yourself properly.
        """

    // MARK: - Goal

    static let goalTitle = "What are you aiming for?"
    static let goalTypeLabel = "Goal"
    static let goalLose = "Lose weight"
    static let goalMaintain = "Maintain"
    static let goalGain = "Gain weight"
    static let goalWeightLabel = "Goal weight"
    static let rateLabel = "How fast?"
    static let rateFootnote = """
        Ninety scores the appropriate rate highest, not the fastest one. Losing weight faster than \
        about 1% of your body weight a week doesn't score better here.
        """
    /// S3, when the ceiling has taken every selectable rate away. The honest
    /// answer is a different goal, not a slower one.
    static let noRateAvailable = """
        At your current weight there's no rate of loss Ninety will set a target for. Maintaining is \
        the option it can support.
        """

    /// §10 S2. The rejection names the lowest acceptable weight, so nobody is
    /// left guessing at this particular number.
    static func goalWeightRejected(minimumKg: Double) -> String {
        let minimum = String(format: "%.1f", minimumKg)
        return """
            That goal weight is below the healthy range for your height (which starts at \
            \(minimum) kg). Ninety can't set that as a target. You can set \(minimum) kg or above, \
            or switch to maintaining.
            """
    }

    // MARK: - Your band

    static let bandTitle = "Your daily band"
    static let bandBody = """
        A band, not a number. Hitting exactly 1,847 isn't a real goal — landing in this range is.
        """
    static let bandFootnote = """
        Worked out from your height, weight, age and activity using the Mifflin-St Jeor equation. \
        It's an estimate, and Ninety adjusts as it sees your real data.
        """

    /// §10 S1, when the floor moved the band. States the number, the reason, and
    /// then the lever that helps — a clamp with no way out is a dead end.
    static func floorApplied(floor: Int, slowerRate: Double?) -> String {
        let base = """
            Ninety won't set a target below \(formatted(floor)) kcal a day. Below that it's hard to \
            get enough nutrients, and it usually needs medical supervision.
            """
        let atTheFloor = " Your band is set at the floor."
        guard let slowerRate else {
            return base + atTheFloor + " Maintaining is the option that fits your numbers."
        }
        return base + atTheFloor + " A slower rate — \(LossRate.formatted(slowerRate)) kg a week — widens it."
    }

    /// `1,850 ±100 kcal`. **Never two numbers joined by a dash**: `PRODUCT.md` is
    /// explicit, and the dash form reads as a range to stay between rather than
    /// as a target with slack.
    static func band(_ band: CalorieBand) -> String {
        "\(formatted(band.centre)) ±\(band.tolerance) kcal"
    }

    // MARK: - Calibration (ADR 0018)

    static let calibrationTitle = "The first week is calibration"
    static let calibrationBody = """
        Ninety watches your first 7 days to learn your baseline. You won't get a division until it \
        closes — a rank based on two days of data would be meaningless.
        """
    /// The honest version of anti-sandbagging (§2.3): rather than hiding the
    /// defence, tell people the incentive runs the other way.
    static let calibrationBody2 = """
        Log as normally as you can. An unusually light week makes every week after it look worse by \
        comparison.
        """
    static let kickOff = "Kick off"

    // MARK: - Age gate (§10 S4)

    static let ageGateTitle = "Ninety is 18+"
    static let ageGateBody = """
        Ninety isn't built for under-18s yet. Body-image and nutrition content for younger users \
        needs safeguards we haven't built, and we'd rather say so than get it wrong.
        """
    /// The one action on the screen, and it is not a way through. iOS apps
    /// cannot close themselves, so the copy deck's `Close` would have been a
    /// button that does nothing — worse than no button. Signing out is the only
    /// honest thing left to offer, and it is not a bypass: the date of birth is
    /// on the profile, so signing back in lands here again.
    static let ageGateAction = PreSeasonCopy.signOutInstead

    /// Every string above, for the S5 sweep.
    static let all: [String] = [
        masthead, next, back, didNotSave,
        aboutYouTitle, aboutYouFootnote, dateOfBirth, height, heightUnit, heightInvalid,
        sex, activityLevel,
        sexFemale, sexMale, sexUnspecified, sexUnspecifiedNote,
        activitySedentary, activitySedentaryDetail, activityLight, activityLightDetail,
        activityModerate, activityModerateDetail, activityActive, activityActiveDetail,
        activityVeryActive, activityVeryActiveDetail,
        weightTitle, weightBody, weightLabel, weightUnit, weightInvalid, weightFootnote,
        goalTitle, goalTypeLabel, goalLose, goalMaintain, goalGain, goalWeightLabel,
        rateLabel, rateFootnote, noRateAvailable,
        bandTitle, bandBody, bandFootnote,
        calibrationTitle, calibrationBody, calibrationBody2, kickOff,
        ageGateTitle, ageGateBody, ageGateAction,
        stepMeta(1, of: 4),
        goalWeightRejected(minimumKg: 56.7),
        floorApplied(floor: 1_200, slowerRate: 0.25),
        floorApplied(floor: 1_500, slowerRate: nil),
    ]

    /// Grouped digits, which is how every number in the app is written.
    private static func formatted(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}
