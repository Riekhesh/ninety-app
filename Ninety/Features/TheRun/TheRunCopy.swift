import Foundation

/// Every string The Run renders, in one place.
///
/// Same reasoning as `SubOnCopy` and `PreSeasonCopy`: this is a *test surface*,
/// not a strings file. `SafetyCopyTests` sweeps the copy the app actually shows,
/// and a hand-copied inventory decays the first time somebody edits a view.
///
/// `design/spec/04-copy-deck.md` §5 is the source. Change it there first.
enum TheRunCopy {
    // MARK: - The headline

    /// The copy deck's §5 title, and the eyebrow on every holding note here.
    static let eyebrow = "Weight"

    static let averageLabel = "7-day average"
    static let sinceLabel = "Since"
    static let paceLabel = "Your pace"
    static let trendLabel = "7-day avg"

    /// The explainer, verbatim from the deck. It is on the screen rather than
    /// behind a disclosure because it is the answer to the only question this
    /// screen reliably produces — *why is that not the number on my scale* —
    /// and an answer nobody finds is not an answer.
    static let explainer = """
        Ninety shows a 7-day average because daily weight is mostly water, glycogen and \
        gut content. The raw line jumps around enough to make a good week look like a bad one.
        """

    // MARK: - The raw series

    static let showRawReadings = "Show daily readings"
    static let rawReadingsNote = "Daily numbers swing on water, not fat."

    // MARK: - Four weeks

    static let flatOverFourWeeks = "Steady over 4 weeks"
    static let shortWindow = "Four weeks is a short window. It moves around."

    /// `−1.2 kg vs 4 weeks ago`. A minus sign, not a hyphen: the hyphen-minus
    /// renders narrow next to the tabular figures the metric styles use, and
    /// VoiceOver reads it as a hyphen.
    static func versusFourWeeks(_ deltaKg: Double) -> String {
        "\(signed(deltaKg)) vs 4 weeks ago"
    }

    /// The trend value with its unit. One decimal place, because a scale reports
    /// one and a smoothed average to the gram is precision nobody measured.
    ///
    /// §1.2's no-decimals rule is about **calories** and does not reach here: a
    /// tenth of a kilogram is a real distinction on a bathroom scale, and a
    /// whole-kilogram trend would hide most of a week's movement.
    static func kilograms(_ kg: Double) -> String {
        "\(kg.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    /// `+0.4` / `−1.2` / `0.0`. Signed, with the typographic minus.
    static func signed(_ kg: Double) -> String {
        let magnitude = abs(kg).formatted(.number.precision(.fractionLength(1)))
        if kg > 0 { return "+\(magnitude) kg" }
        if kg < 0 { return "\u{2212}\(magnitude) kg" }
        return "0.0 kg"
    }

    // MARK: - States

    /// The copy deck's empty state, §3. Worded to cover "you have not weighed
    /// yourself" and "Apple Health told us nothing" identically, because iOS
    /// gives the app no way to tell them apart.
    static let noWeightHeadline = "No weight yet."
    static let noWeightDetail = """
        Nothing has been recorded. Add today's weight and the trend starts from there — \
        it needs a week of readings before it is a trend.
        """

    static let oneReadingHeadline = "One reading so far."
    static let oneReadingDetail = """
        A trend needs more than one point. Weigh in again tomorrow and the line has \
        somewhere to go.
        """

    static let trendNeedsAWeek = "Trend needs a week of readings"

    /// `4 of 7 days recorded`. Not "3 to go", which reads as a demand.
    static func building(days: Int) -> String {
        "\(days) of \(WeightTrend.windowDays) days recorded"
    }

    static let buildingDetail = """
        The line is drawn from what there is. It settles once a week of readings is behind it.
        """

    // MARK: - Adding a reading

    static let addWeight = "Add today's weight"
    static let entryTitle = "Weigh in"
    static let entryDetail = """
        Whenever you weigh yourself is the right time. The same time of day each day makes \
        the average settle faster, and missing a day costs nothing.
        """
    static let weightField = "Weight"
    static let whenField = "When"
    static let saveWeight = "Save"
    static let writeFailed = "That didn't save. Try again."

    /// `Last: 78.4 kg · yesterday`. On the entry screen, under the field.
    ///
    /// It is there to catch the decimal-point typo at the moment it is made:
    /// 7.84 is inside the column's bounds and the app has no honest basis to
    /// refuse it, but nobody types it with last week's number in front of them.
    /// §2.3's own preference, applied to entry rather than to scoring — *flag,
    /// do not reject.*
    static func lastReading(_ kg: Double, at moment: Date) -> String {
        "Last: \(kilograms(kg)) · \(moment.formatted(.relative(presentation: .named)))"
    }

    /// The one refusal, and it is the database's bound rather than an opinion
    /// about bodies. Outside it the row cannot be stored at all.
    static let outOfRange = "Ninety can record a weight between 1 and 499 kg."

    static let readingsHeading = "Every reading"
    static let readingsDetail = "Swipe to remove"
    static let removeReading = "Remove"

    /// `HealthKit` on the row, `Apple Health` to the user — the framework's name
    /// is not the app's name, and the user has only ever seen the second.
    static func source(_ source: WeightSource) -> String {
        switch source {
        case .manual: "Typed in"
        case .healthkit: "Apple Health"
        }
    }

    // MARK: - Apple Health

    static let healthHeading = "Apple Health"
    static let connectHealth = "Read weight from Apple Health"
    static let healthDetail = """
        Smart scales write to Apple Health on their own. Ninety reads body weight from it \
        and writes nothing back.
        """
    static let healthUnavailable = "This device doesn't have Apple Health."

    /// After a sync. Both outcomes are stated plainly and neither claims to know
    /// why: an empty read is what iOS returns for "nothing there" and for "not
    /// allowed", and the app cannot tell which.
    static func imported(_ count: Int) -> String {
        count == 1 ? "1 new reading from Apple Health." : "\(count) new readings from Apple Health."
    }

    static let importedNothing = "Nothing new in Apple Health."

    // MARK: - Pace

    /// The rate on the profile, as the artboard writes it: `0.5 kg / week`.
    static func rate(_ kgPerWeek: Double) -> String {
        "\(LossRate.formatted(kgPerWeek)) kg / week"
    }

    static let maintaining = "Holding steady"

    /// What the trend is doing against the line.
    ///
    /// **`.ahead` is a statement, never a congratulation**, and that is §10 S3
    /// rather than a tone preference: the engine caps rate of loss, so a screen
    /// that celebrates speed is an incentive pulling against the cap. The note
    /// underneath says so in the copy deck's own words rather than leaving the
    /// user to discover it at the weekly reveal.
    ///
    /// `.behind` never frames a shortfall as a failure (S5). It states the fact
    /// and then puts it in proportion — progress is 0.25 of the score and
    /// consistency is 0.50, which is true, checkable, and the most useful thing
    /// the screen can say to somebody having a slow fortnight.
    static func pace(_ standing: PaceStanding, goalType: GoalType) -> String {
        switch (standing, goalType) {
        case (.onPace, .maintain): "Holding steady."
        case (.onPace, _): "Tracking inside your pace."
        case (.ahead, .maintain), (.behind, .maintain): "Drifting from steady."
        case (.ahead, _): "Moving faster than the pace you chose."
        case (.behind, _): "Slower than the pace you chose."
        }
    }

    static func paceNote(_ standing: PaceStanding, goalType: GoalType) -> String {
        switch (standing, goalType) {
        case (.ahead, .lose), (.ahead, .gain):
            """
            Ninety scores the appropriate rate highest rather than the fastest, so this \
            doesn't raise your rank — and it's harder to sustain.
            """
        case (.behind, .lose), (.behind, .gain):
            """
            Progress is 0.25 of the score — the run matters less than turning up. \
            Consistency is weighted double.
            """
        case (.ahead, .maintain), (.behind, .maintain):
            "Four weeks is a short window. It moves around."
        case (.onPace, _):
            "Progress is 0.25 of the score — the run matters less than turning up."
        }
    }

    static let noPace = "No pace to draw yet."
    static let noPaceDetail = """
        The line you chose in Pre-Season starts from your first reading. It appears once \
        there is a trend to draw it against.
        """

    // MARK: - The chart

    static let rangeLabel = "Range"

    /// Everything above, for `SafetyCopyTests`.
    ///
    /// Assembled by hand, because a caseless enum's statics cannot be
    /// enumerated. The functions are included at representative arguments rather
    /// than omitted: `pace` and `paceNote` are swept across every combination of
    /// standing and goal type, which is where the punishment-framing risk on
    /// this screen actually lives.
    static var all: [String] {
        // Broken into three rather than one `+` chain: the type checker charges
        // for a long homogeneous chain, and this one grows every epic.
        let fixed = [
            eyebrow, averageLabel, sinceLabel, paceLabel, trendLabel, explainer,
            showRawReadings, rawReadingsNote, flatOverFourWeeks, shortWindow,
            noWeightHeadline, noWeightDetail, oneReadingHeadline, oneReadingDetail,
            trendNeedsAWeek, buildingDetail, addWeight, entryTitle, entryDetail,
            weightField, whenField, saveWeight, writeFailed, outOfRange,
            readingsHeading, readingsDetail, removeReading,
            healthHeading, connectHealth, healthDetail, healthUnavailable,
            importedNothing, maintaining, noPace, noPaceDetail, rangeLabel,
        ]

        let formatted: [String] = WeightSource.allCases.map { source($0) }
            + TrendRange.allCases.map(\.title)
            + [
                building(days: 4), imported(1), imported(3),
                versusFourWeeks(-1.2), versusFourWeeks(0.4), kilograms(78.4),
                lastReading(78.4, at: .distantPast), rate(0.5),
            ]

        // Every combination, because this is where the punishment-framing risk
        // on the screen actually lives — nine sentences, none of which may read
        // as a verdict on the person in front of them.
        let paces: [String] = GoalType.allCases.flatMap { goal in
            PaceStanding.allCases.flatMap { standing in
                [pace(standing, goalType: goal), paceNote(standing, goalType: goal)]
            }
        }

        return fixed + formatted + paces
    }
}
