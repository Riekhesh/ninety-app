import Foundation

/// §10 S4 · the age gate. Under 18 is a hard stop.
///
/// **No bypass, and the type says so.** `Outcome` has two cases and no third,
/// there is no parameter that relaxes the minimum, and nothing in the app calls
/// anything but `outcome(dob:on:calendar:)`. §10's reason is the honest one and
/// the copy uses it rather than dressing it as a legal technicality: *"the
/// safeguarding considerations for minors and body-image content are substantial
/// and well beyond what a solo v1 should attempt."*
///
/// The rejection screen signposts Beat's youth helpline. A user turned away
/// should not leave with nothing — see `Signposting`.
enum AgeGate {
    static let minimumAge = 18

    /// Two answers. There is no `.allowedWithConsent`, and adding one would be
    /// a change to §10 rather than a change to this file.
    enum Outcome: Equatable, Sendable, CaseIterable {
        case allowed
        case blocked
    }

    /// Whole years between two dates, **computed on the actual date.**
    ///
    /// Not `year(day) - year(dob)`: someone born on 9 September 2008 is 17 on 8
    /// September 2026 and 18 the following morning, and a year subtraction says
    /// 18 for the whole of 2026. `dateComponents` does the calendar arithmetic,
    /// including the leap-day case that hand-rolled versions get wrong.
    ///
    /// Nil only if the calendar cannot express the difference, which for two
    /// real dates it can.
    static func age(dob: Date, on day: Date, calendar: Calendar) -> Int? {
        calendar.dateComponents([.year], from: dob, to: day).year
    }

    static func outcome(dob: Date, on day: Date, calendar: Calendar) -> Outcome {
        guard let years = age(dob: dob, on: day, calendar: calendar) else { return .blocked }
        return years >= minimumAge ? .allowed : .blocked
    }
}
