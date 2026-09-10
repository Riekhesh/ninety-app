import Foundation

/// Every string Matchday renders, in one place.
///
/// Same reasoning as `SubOnCopy` and `TheRunCopy`: this is a *test surface*, not
/// a strings file. `SafetyCopyTests` sweeps the copy the app actually shows, and
/// a hand-copied inventory decays the first time somebody edits a view.
///
/// `design/spec/04-copy-deck.md` §3 is the source. Change it there first.
///
/// > **Deviation from the copy deck, recorded in `DESIGN.md`.** The deck labels
/// > the headline `CALORIES REMAINING`; the build uses the artboard's `STILL TO
/// > PLAY WITH`. `DESIGN.md` settles ties the same way twice already — the
/// > world's vocabulary runs through the product everywhere it costs nothing,
/// > and the deck wins where it costs something. Under Review took HIGH /
/// > MEDIUM / LOW over CLEAR / TIGHT / UNSIGHTED because that chip tells
/// > somebody which number to go and check. This one costs nothing: the figure
/// > is a calorie count with `KCAL` beside it, and nobody has to be told what
/// > "still to play with" means.
enum MatchdayCopy {
    // MARK: - The reading

    /// The headline eyebrow, on a day with room left in the band.
    static let stillToPlayWith = "Still to play with"

    /// And on a day that has gone past it. **A fact, not a verdict** — the deck's
    /// rewrite rule in one string: `340 calories over budget` becomes `2,190 —
    /// above your band today`, because "over budget" frames food as money spent.
    static let aboveYourBandBy = "Above your band by"

    static let kcalUnit = "kcal"

    /// `1,238 in · band 1,850 ±100`. The band as a figure and a tolerance,
    /// never as two numbers joined by a dash (`DESIGN.md` § Numbers).
    static func inAndBand(logged: Double, band: CalorieBand) -> String {
        "\(Figure.kcal(logged)) in · band \(Figure.kcal(band.centre)) ±\(Figure.kcal(band.tolerance))"
    }

    /// The pitch's two ends. The middle mark is the figure itself, so it is not
    /// a string.
    static let kickOff = "Kick off"
    static let theBand = "The band"

    static let noBand = "Finish Pre-Season to see your band."
    static let noBandDetail = """
        The band comes out of your height, weight, age and the rate you chose. Pre-Season \
        collects them once and it takes about a minute.
        """

    // MARK: - Form

    static let formHeading = "Form · 7 days"

    /// `5 of 7 days`. The deck's wording, and deliberately not "2 to go", which
    /// reads as a demand, or "you missed 2", which is on the banned list.
    static func formDays(_ logged: Int) -> String { "\(logged) of \(Form.windowDays) days" }

    /// Why the ring is on the screen at all, in one sentence the user can check
    /// against the published weighting on The Table.
    static let formNote = "Consistency is weighted 0.50. It's the half of the score you control."

    static let formEmpty = "Nothing logged in the last seven days."

    /// A day in the ring, for VoiceOver. Spoken as a date and a state, because
    /// seven unlabelled segments are seven unlabelled segments to a screen
    /// reader — and "logged" / "not logged" is the whole vocabulary, with no
    /// third word for a day that was missed.
    static func formDay(_ date: Date, mark: DayMark) -> String {
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        return mark.isFilled ? "\(day): logged" : "\(day): not logged"
    }

    // MARK: - Macros

    static let macrosHeading = "Macros"

    /// `From 3 of 5 items`, and it is on the panel rather than in a footnote.
    ///
    /// Macros live on the `foods` row a log points at, and three of the four
    /// logging routes can produce a log without one — a quick-add by calories
    /// has none by construction. So this figure is honest about being a total
    /// over part of the day, which is the alternative to quietly presenting it
    /// as the whole of it.
    static func macrosFrom(covered: Int, total: Int) -> String {
        "From \(covered) of \(total) \(total == 1 ? "item" : "items")"
    }

    static let macrosComplete = "From everything logged today"

    static let macrosEmpty = "No macros on today's logs."
    static let macrosEmptyDetail = """
        Calories are what the band is made of, and every route records those. Macros come \
        from the food's own figures, so a quick add by calories has none.
        """

    /// `84 g`. One decimal is dropped here and kept on the weight, and the split
    /// is deliberate: a gram of protein is not a distinction anybody acts on,
    /// and a tenth of a kilogram on a bathroom scale is.
    static func grams(_ value: Double) -> String { "\(Int(value.rounded())) g" }

    // MARK: - Weight

    static let weightHeading = "Weight · 7-day"

    /// Reuses The Run's wording rather than restating it. The two screens show
    /// the same number off the same series and must not describe it differently.
    static let weightEmpty = TheRunCopy.noWeightHeadline
    static let weightEmptyDetail = "The trend starts from your first reading. The Run is where you add one."
    static let weightOneReading = TheRunCopy.oneReadingHeadline
    static let weightNeedsAWeek = TheRunCopy.trendNeedsAWeek

    // MARK: - The team sheet

    static let teamSheetHeading = "Team sheet"

    /// `3 on · 1,238 kcal`. "On" rather than "started", because the app's own
    /// verb for logging something is subbing it on.
    static func teamSheetDetail(items: Int, kcal: Double) -> String {
        "\(items) on · \(Figure.kcal(kcal)) \(kcalUnit)"
    }

    static let nothingLogged = "Nothing logged yet today."
    static let nothingLoggedDetail = """
        The band, the day's total and Form all read from what you log. Sub on and the \
        screen fills in behind you.
        """

    static let subOn = "Sub on"
    static let subOnHint = "Sub on. Log food."

    // MARK: - The division

    /// The same two strings The Table uses, on purpose. Two screens with a
    /// division-shaped hole in them have to give the same answer for it, or one
    /// of them is implying the other knows something.
    static let divisionHeading = "Division"
    static let divisionPlaceholder = "Ranking arrives in the next update."
    static let divisionDetail = """
        Ninety ranks on how much you improve against your own baseline, so it needs a \
        baseline first. Nothing is being scored yet.
        """

    // MARK: - Everything above, for `SafetyCopyTests`

    /// Assembled by hand, because a caseless enum's statics cannot be enumerated.
    /// The functions appear at representative arguments rather than being
    /// omitted — `formDays` and `macrosFrom` are the two that could grow a
    /// judgement about a shortfall, so they are the ones that most need sweeping.
    static var all: [String] {
        let fixed: [String] = [
            stillToPlayWith, aboveYourBandBy, kcalUnit, kickOff, theBand,
            noBand, noBandDetail,
            formHeading, formNote, formEmpty,
            macrosHeading, macrosComplete, macrosEmpty, macrosEmptyDetail,
            weightHeading, weightEmpty, weightEmptyDetail, weightOneReading, weightNeedsAWeek,
            teamSheetHeading, nothingLogged, nothingLoggedDetail, subOn, subOnHint,
            divisionHeading, divisionPlaceholder, divisionDetail,
        ]

        let band = CalorieBand(centre: 1_850, tolerance: 100, isAtFloor: false, floor: 1_500, slowerRate: nil)
        let formatted: [String] = [
            inAndBand(logged: 1_238, band: band),
            teamSheetDetail(items: 1, kcal: 120), teamSheetDetail(items: 3, kcal: 1_238),
            macrosFrom(covered: 1, total: 1), macrosFrom(covered: 3, total: 5),
            macrosFrom(covered: 0, total: 2), grams(84),
        ]

        // Every count in the window, because a string about how many days were
        // logged is the single most likely place on this screen for a shortfall
        // to acquire a judgement — and zero is the one that matters most.
        let counts: [String] = (0...Form.windowDays).map { formDays($0) }
            + DayMark.allCases.map { formDay(.distantPast, mark: $0) }
            + MealSlot.allCases.map(\.title)
            + Macro.allCases.map(\.title)

        return fixed + formatted + counts
    }
}
