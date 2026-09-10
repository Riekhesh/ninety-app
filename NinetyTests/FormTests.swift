import Foundation
import Testing
@testable import Ninety

/// P1-H — the two pure rules behind Matchday's instruments.
///
/// `Form` and `MacroTotals` are values with no store behind them, for the reason
/// `WeightTrend` is: `Packages/RankingEngine` cannot import SwiftData, and
/// consistency at 0.50 is the component Phase 2 builds on this shape. Testing
/// them here rather than through the ViewModel is what keeps that boundary real.
@Suite("Form and macros")
@MainActor
struct FormTests {
    /// London, for the reason `SubOnTests` uses it: it has a summer offset, and
    /// that is where a date-boundary bug lives.
    static var london: Calendar { MatchdayTests.london }

    static func at(_ hour: Int, _ minute: Int = 0, day: Int, in calendar: Calendar) -> Date {
        MatchdayTests.at(hour, minute, day: day, in: calendar)
    }

    static func log(
        _ name: String,
        kcal: Double,
        grams: Double,
        at moment: Date,
        user: UUID,
        food: Food? = nil
    ) -> FoodLog {
        MatchdayTests.log(name, kcal: kcal, grams: grams, at: moment, user: user, food: food)
    }

    // MARK: - Form

    /// Seven segments on day one, not one.
    ///
    /// A ring that grew a segment a day would be a different control every
    /// morning, and — worse — it would make the empty days invisible, which is
    /// the opposite of what the ring is for. The window is the shape; how much of
    /// it is filled is the reading.
    @Test("Form is always seven days wide, even on the first one")
    func formIsAlwaysSevenWide() {
        let calendar = Self.london
        let today = Self.at(15, 30, day: 10, in: calendar)

        #expect(Form.of([], on: today, calendar: calendar).days.count == Form.windowDays)
        #expect(Form.of([today], on: today, calendar: calendar).days.count == Form.windowDays)
        #expect(Form.of([], on: today, calendar: calendar).loggedDays == 0)
    }

    /// The window runs on **calendar days**, the same as `WeightTrend` (ADR
    /// 0020) and `MealSlot` (ADR 0022).
    ///
    /// Two logs eighteen hours apart are two days when they straddle midnight
    /// and one day when they do not, and a window counting 24-hour blocks off
    /// "now" gets that backwards. It is the same class of bug as smoothing
    /// readings instead of days: invisible on the data of somebody who logs at
    /// the same time every day, wrong for everybody else.
    @Test("Form counts calendar days, not twenty-four-hour blocks")
    func formCountsCalendarDays() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)

        // 23:30 on the 9th and 00:10 on the 10th: eighty minutes apart, two days.
        let straddling = [Self.at(23, 30, day: 9, in: calendar), Self.at(0, 10, day: 10, in: calendar)]
        #expect(Form.of(straddling, on: now, calendar: calendar).loggedDays == 2)

        // 08:00 and 22:00 on the 10th: fourteen hours apart, one day.
        let sameDay = [Self.at(8, day: 10, in: calendar), Self.at(22, day: 10, in: calendar)]
        #expect(Form.of(sameDay, on: now, calendar: calendar).loggedDays == 1)
    }

    /// The window ends today and reaches back six days, so a log from a week ago
    /// is outside it. Seven days including today, not seven days before it.
    @Test("Form's window is the last seven days including today")
    func formWindowEndsToday() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)

        let sixDaysBack = Self.at(9, day: 4, in: calendar)
        let sevenDaysBack = Self.at(9, day: 3, in: calendar)

        let form = Form.of([sixDaysBack, sevenDaysBack, now], on: now, calendar: calendar)
        #expect(form.loggedDays == 2)
        #expect(form.days.first?.date == calendar.startOfDay(for: sixDaysBack))
        #expect(form.days.last?.date == calendar.startOfDay(for: now))
    }

    /// §10 S5, as a property of the type rather than of the drawing. A missed day
    /// has one representation and there is no third case for a view to reach for.
    @Test("a missed day is absent, never marked")
    func aMissedDayIsAbsent() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)
        let form = Form.of([now], on: now, calendar: calendar)

        let missed = form.days.filter { !$0.mark.isFilled }
        #expect(missed.count == Form.windowDays - 1)
        #expect(missed.allSatisfy { $0.mark == .missed })
        #expect(DayMark.allCases.count == 2)
    }

    // MARK: - Macros

    /// The coverage is the honest half, and it is what stops the panel claiming
    /// a day it only saw part of.
    @Test("the macro split says how much of the day it covers")
    func macrosReportTheirCoverage() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)
        let user = UUID()
        let porridge = Food(source: .off, name: "Porridge", kcalPer100g: 128, proteinG: 4.4, carbsG: 18, fatG: 3.2)

        let macros = MacroTotals.of([
            Self.log("Porridge", kcal: 320, grams: 250, at: now, user: user, food: porridge),
            // A quick add by calories. No food row, so no macros — and the panel
            // has to say so rather than treating it as a zero contribution.
            Self.log("Flat white", kcal: 120, grams: 220, at: now, user: user),
        ])

        #expect(macros.coveredLogs == 1)
        #expect(macros.totalLogs == 2)
        #expect(!macros.isComplete)
        // 250 g of a 4.4 g / 100 g protein figure. `PortionBasis` does the
        // scaling, and this is the assertion that it was asked to.
        #expect(macros.proteinG == 11.0)
        #expect(macros.carbsG == 45.0)
    }

    /// Zero logs, one log and twenty — the story's own acceptance criterion.
    @Test("the macro split renders sensibly at zero, one and many logs")
    func macrosHandleEveryDayLength() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)
        let user = UUID()
        let food = Food(source: .off, name: "Rice", kcalPer100g: 130, proteinG: 2.7, carbsG: 28, fatG: 0.3)

        let empty = MacroTotals.of([])
        #expect(empty.isEmpty)
        #expect(!empty.isComplete, "a day with no logs has not been fully covered, it has not been covered")
        #expect(empty.share(of: .protein) == 0, "no division by zero, and no invented split")

        let one = MacroTotals.of([Self.log("Rice", kcal: 260, grams: 200, at: now, user: user, food: food)])
        #expect(one.isComplete)
        #expect(one.share(of: .carbs) > one.share(of: .fat))

        let many = MacroTotals.of(
            (0..<20).map { _ in Self.log("Rice", kcal: 260, grams: 200, at: now, user: user, food: food) }
        )
        #expect(many.coveredLogs == 20)
        #expect(many.isComplete)
        // The shares are proportions, so twenty identical logs split the same
        // way one does — a bar that drifted as the day grew would be reading
        // absolute grams and calling them a proportion.
        #expect(abs(many.share(of: .carbs) - one.share(of: .carbs)) < 0.0001)
    }
}
