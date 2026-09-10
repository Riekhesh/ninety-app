import Foundation

/// Seven days, and whether each of them was logged.
///
/// **Form is the redesign's name for consistency**, and consistency is 0.50 of
/// the eventual composite (§2.2) — so this is the surface the whole thesis leans
/// on, and it is the one place in Phase 1 where the app says anything at all
/// about showing up. That is why it is a pure value with its own tests rather
/// than a `filter` inside a view: `Packages/RankingEngine` cannot import
/// SwiftData, so the shape Phase 2's consistency component will eventually be
/// handed is this one — an array of marks over calendar days — and not the rows.
///
/// **A day is logged or it is absent. There is no third state.** `DayMark` has
/// exactly two cases and no `isFailed`, which is §10 S5's structural half: a
/// ring that marks failure is a ring people stop looking at, and then they stop
/// logging. Nothing here counts a streak, and nothing here can tell you how many
/// days in a row you have managed — a run of six followed by a gap and a seventh
/// renders identically to any other five-of-seven, because the score it stands
/// for is a count and not a chain.
///
/// **Calendar days, in the user's own calendar.** Same rule as `WeightTrend` and
/// `MealSlot`, for the same reason: a window measured in 24-hour blocks off a
/// fixed offset would let a flight west add a day and a flight east remove one.
struct Form: Equatable, Sendable {
    /// §2.2's window. Seven, and the same seven the copy names.
    static let windowDays = 7

    /// Oldest first, one entry per day, always `windowDays` long. Always full
    /// length even on day one — the empty days are the shape of the thing, and a
    /// ring that grew from one segment to seven over a week would be a different
    /// control every morning.
    let days: [Day]

    /// One day in the window.
    struct Day: Identifiable, Equatable, Sendable {
        /// The start of the day, in the user's calendar.
        let date: Date
        let mark: DayMark

        var id: Date { date }
    }

    /// How many of the seven have something logged against them.
    var loggedDays: Int { days.count(where: { $0.mark.isFilled }) }

    /// The window that ends today, from the days anything was logged on.
    ///
    /// Takes moments rather than logs so it stays free of SwiftData, and takes
    /// the day *and* the calendar rather than reading either, so a test can put
    /// the window anywhere without moving the machine's clock.
    static func of(_ moments: [Date], on day: Date, calendar: Calendar) -> Form {
        let logged = Set(moments.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: day)

        let days = (0..<windowDays).reversed().compactMap { offset -> Day? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return Day(date: date, mark: logged.contains(date) ? .logged : .missed)
        }
        return Form(days: days)
    }
}

/// What the day's logs add up to, per macro, and how much of the day that covers.
///
/// **The coverage is the honest half and it is not optional.** A `FoodLog` keeps
/// its own calories and its own name snapshot, but its macros live on the `Food`
/// row it points at — and three of the four logging routes can produce a log
/// with no food row at all: a quick-add by calories has none by construction, a
/// photo estimate has none, and a catalogue row can be deleted underneath a log
/// that already happened. So a macro total over a real day is almost always a
/// total over *part* of that day, and a panel that showed `84 g` without saying
/// what it was 84 g of would be inventing the rest.
///
/// The band is made of calories and every route produces those, which is why the
/// headline on Matchday is a calorie figure and this is an instrument underneath
/// it rather than the other way round.
struct MacroTotals: Equatable, Sendable {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double

    /// How many of the day's logs carried a food row to read macros off.
    let coveredLogs: Int
    let totalLogs: Int

    var isEmpty: Bool { coveredLogs == 0 }

    /// True when every log on the day contributed. The panel says so rather than
    /// leaving the reader to compare two numbers.
    var isComplete: Bool { totalLogs > 0 && coveredLogs == totalLogs }

    var totalGrams: Double { proteinG + carbsG + fatG }

    /// Each macro's share of the three, `0...1`. Zero when there is nothing to
    /// divide, rather than a division by zero.
    func share(of macro: Macro) -> Double {
        guard totalGrams > 0 else { return 0 }
        return grams(of: macro) / totalGrams
    }

    func grams(of macro: Macro) -> Double {
        switch macro {
        case .protein: proteinG
        case .carbs: carbsG
        case .fat: fatG
        }
    }

    /// The day's totals, scaled by portion.
    ///
    /// **`PortionBasis` does the arithmetic, not this.** The bug that type
    /// exists to prevent — a screen doing its own per-100 g maths and getting
    /// the portion the wrong way round — is exactly the bug a second
    /// implementation here would reintroduce, on a panel nobody would check
    /// against a label.
    static func of(_ logs: [FoodLog]) -> MacroTotals {
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var covered = 0

        for log in logs {
            guard let food = log.food, food.proteinG != nil || food.carbsG != nil || food.fatG != nil else {
                continue
            }
            let scaled = PortionBasis(
                kcalPer100g: food.kcalPer100g,
                proteinPer100g: food.proteinG,
                carbsPer100g: food.carbsG,
                fatPer100g: food.fatG
            )
            .scaled(toGrams: log.grams)

            protein += scaled.proteinG ?? 0
            carbs += scaled.carbsG ?? 0
            fat += scaled.fatG ?? 0
            covered += 1
        }

        return MacroTotals(
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            coveredLogs: covered,
            totalLogs: logs.count
        )
    }
}

/// The three, in the order they are read.
enum Macro: String, CaseIterable, Identifiable, Sendable {
    case protein, carbs, fat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }
}
