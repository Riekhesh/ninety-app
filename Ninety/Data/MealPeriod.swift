import Foundation

/// Which half of the day a meal was eaten in.
///
/// The artboards label Sub On with the half you are logging into — `SECOND
/// HALF` in `design/redesign/SubOn.dc.html` — and the language runs through the
/// product rather than sitting on it (`DESIGN.md`). This is that label, as a
/// value.
///
/// **Derived, never stored.** There is no `meal_period` column on `food_logs`
/// and there is not going to be one: the half is a pure function of `logged_at`
/// and the user's calendar, so a column would be a second copy of a value that
/// can be computed, and the two would eventually disagree. Deriving it also
/// means no migration and no line in `check_schema_parity.py`.
///
/// **The changeover is midday in the user's own calendar, and that is the whole
/// of the date-boundary criterion.** A log at 23:30 is the Second Half of that
/// day; a log at 00:10 is the First Half of the next one — the same day
/// `SwiftDataFoodRepository.logs(on:calendar:)` would count it against, because
/// both read the day from the same calendar. Reading the hour off a fixed UTC
/// offset instead would put a late dinner in London into the following
/// morning's First Half for half the year, which is the bug this is written to
/// make impossible rather than unlikely.
enum MealPeriod: String, CaseIterable, Identifiable, Sendable {
    case firstHalf
    case secondHalf

    var id: String { rawValue }

    /// Sentence case. `ninetyType(.label)` applies the caps, so VoiceOver still
    /// reads a phrase rather than spelling one out.
    var title: String {
        switch self {
        case .firstHalf: "First Half"
        case .secondHalf: "Second Half"
        }
    }

    /// Midday. One number, named, because it appears in the tests as well as
    /// here and a literal 12 in two places is a rule that can drift.
    static let changeoverHour = 12

    /// Which half a moment falls in, in the given calendar.
    ///
    /// The calendar is a parameter for the reason the ranking engine may not
    /// read the clock: a rule that consults ambient state cannot be tested
    /// against a timezone other than the machine running the test.
    static func of(_ moment: Date, calendar: Calendar) -> MealPeriod {
        calendar.component(.hour, from: moment) < changeoverHour ? .firstHalf : .secondHalf
    }
}
