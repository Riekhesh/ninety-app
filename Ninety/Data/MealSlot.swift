import Foundation

/// Which meal a log belongs to, and how the app works one out.
///
/// **Real slots, replacing First Half / Second Half** (ADR 0022). The halves
/// were the right answer while the only surface reading them was Sub On's Today
/// list, and they were explicitly *"not a down-payment"* on this. Matchday's
/// team sheet is where they stopped being enough: a dashboard that groups a
/// whole day into two buckets tells you less than the timestamps it was built
/// from, and *"Second Half · 778"* answers no question anybody has at breakfast.
///
/// **Derived by default, stored only when it is wrong.** `food_logs.meal_slot`
/// is nullable and null means *"read it off `logged_at`"*, which is what keeps
/// this from costing the clock a keystroke: no route asks the question, every
/// log gets an answer, and backdating still works because the derivation runs on
/// the log's own moment rather than on now. The column exists for the case the
/// derivation cannot get right — a night shift, a very late dinner, a breakfast
/// eaten at four in the afternoon — where the user corrects it and the answer
/// sticks. A slot that could only ever be derived would be a relabelling of the
/// halves into thirds; a slot that always had to be chosen would put a picker in
/// front of every meal.
///
/// **The boundaries are read in the user's own calendar**, for the reason
/// `MealPeriod` was: an hour taken off a fixed UTC offset puts a late London
/// dinner into the following morning for half the year. A log at 00:10 is
/// breakfast of the day it lands on, which is the same day
/// `SwiftDataFoodRepository.logs(on:calendar:)` counts it against — both read the
/// day from the same calendar, so the team sheet and the total can never
/// disagree about which day a meal was.
extension MealSlot: Identifiable {
    var id: String { rawValue }

    /// Sentence case. `ninetyType(.label)` applies the caps, so VoiceOver still
    /// reads a word rather than spelling one out.
    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        }
    }

    /// The two changeovers, named because they appear in the tests as well as
    /// here and a literal 11 in two places is a rule that can drift.
    ///
    /// Eleven and four. Not because they are true of everybody — they are not,
    /// which is the whole reason the column exists — but because they are the
    /// boundaries that are wrong least often, and being wrong here costs one tap
    /// on a row that is already tappable.
    static let lunchFromHour = 11
    static let dinnerFromHour = 16

    /// Which slot a moment falls in, in the given calendar.
    ///
    /// The calendar is a parameter for the reason the ranking engine may not
    /// read the clock: a rule that consults ambient state cannot be tested
    /// against a timezone other than the machine running the test.
    static func of(_ moment: Date, calendar: Calendar) -> MealSlot {
        switch calendar.component(.hour, from: moment) {
        case ..<lunchFromHour: .breakfast
        case ..<dinnerFromHour: .lunch
        default: .dinner
        }
    }
}
