import Foundation
import Testing
@testable import Ninety

/// P1-H — the Matchday dashboard: the band, Form, the macro split, the weight
/// panel and the team sheet.
///
/// The rules worth testing on this screen are the ones that are invisible when
/// they are right and expensive when they are wrong: a Form window that counts
/// 24-hour blocks instead of calendar days, a macro total that quietly covers
/// half the day, a band figure that clamps at zero, and a division slot that
/// survives the §10 opt-out.
@Suite("Matchday")
@MainActor
struct MatchdayTests {
    /// London, for the reason `SubOnTests` uses it: it has a summer offset, and
    /// that is where a date-boundary bug lives.
    static var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }

    static func at(_ hour: Int, _ minute: Int = 0, day: Int, in calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    /// A profile whose band works out to something a person could eat, so a test
    /// about the band is not also a test about `EnergyTarget`.
    static func profile(id: UUID, on day: Date, calendar: Calendar) -> Profile {
        Profile(
            id: id,
            createdAt: calendar.date(byAdding: .day, value: -3, to: day) ?? day,
            dob: calendar.date(byAdding: .year, value: -32, to: day),
            heightCm: 178,
            sex: .male,
            activityLevel: .moderate,
            goalType: .lose,
            goalWeightKg: 76,
            targetRateKgPerWeek: 0.5,
            termsAcceptedAt: day,
            healthConsentAt: day
        )
    }

    static func harness(
        logs: [FoodLog] = [],
        weights: [WeightLog] = [],
        profile: Profile?,
        now: Date,
        calendar: Calendar
    ) -> MatchdayModel {
        let model = MatchdayModel(
            foods: MockFoodRepository(logs: logs, userID: profile?.id ?? UUID(), now: now),
            profiles: MockProfileRepository(profile: profile),
            weights: MockWeightRepository(logs: weights),
            calendar: calendar,
            now: { now }
        )
        model.refresh()
        return model
    }

    static func log(
        _ name: String,
        kcal: Double,
        grams: Double = 200,
        at moment: Date,
        user: UUID,
        food: Food? = nil
    ) -> FoodLog {
        FoodLog(
            userID: user,
            loggedAt: moment,
            grams: grams,
            entryMethod: food == nil ? .manual : .search,
            kcal: kcal,
            nameSnapshot: name,
            food: food
        )
    }

    // MARK: - The band

    /// The figure is what is left, and a day past the band keeps counting.
    ///
    /// Clamping at zero would say the same thing about 1,900 kcal and 3,400,
    /// and §10 S5 is explicit that being above the band is a fact rather than an
    /// error — the app has no business hiding the size of it.
    @Test("the room left goes negative rather than clamping")
    func roomLeftGoesNegative() throws {
        let calendar = Self.london
        let now = Self.at(20, day: 10, in: calendar)
        let user = UUID()
        let profile = Self.profile(id: user, on: now, calendar: calendar)

        let model = Self.harness(
            logs: [Self.log("A very large dinner", kcal: 4_000, at: now, user: user)],
            weights: [WeightLog(userID: user, measuredAt: now, kg: 84, source: .manual)],
            profile: profile,
            now: now,
            calendar: calendar
        )

        let room = try #require(model.roomLeftKcal)
        #expect(room < 0)
        #expect(model.bandState == .above)
        // And the tone is neutral, because the token set has no error colour for
        // a state the user's own logging can reach.
        #expect(model.bandState?.tone == .neutral)
    }

    /// A number the app did not compute is not shown at all (`DESIGN.md`).
    @Test("with no profile there is no band, and no zero standing in for one")
    func noProfileMeansNoBand() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)

        let model = Self.harness(profile: nil, now: now, calendar: calendar)
        #expect(model.band == nil)
        #expect(model.roomLeftKcal == nil)
        #expect(model.bandState == nil)
        #expect(model.pitchProgress == nil)
        #expect(model.bandSpan == nil)
    }

    /// The pitch runs past the band, so a day over it has somewhere to be.
    @Test("the pitch leaves room beyond the band rather than saturating at it")
    func pitchRunsPastTheBand() throws {
        let calendar = Self.london
        let now = Self.at(20, day: 10, in: calendar)
        let user = UUID()

        let model = Self.harness(
            logs: [Self.log("Dinner", kcal: 2_000, at: now, user: user)],
            weights: [WeightLog(userID: user, measuredAt: now, kg: 84, source: .manual)],
            profile: Self.profile(id: user, on: now, calendar: calendar),
            now: now,
            calendar: calendar
        )

        let span = try #require(model.bandSpan)
        // The band's box sits inside the pitch with room after it, which is the
        // whole reason a day above the band is legible on the meter.
        #expect(span.upperBound < 1)
        #expect(span.lowerBound > 0)

        let progress = try #require(model.pitchProgress)
        #expect(progress <= 1)
    }

    // MARK: - The team sheet

    /// The dashboard groups by meal, and it is the same rule Sub On's list uses
    /// — one implementation on `FoodLog`, read through the model's calendar.
    @Test("the team sheet groups the day into its three meals")
    func teamSheetGroupsByMeal() {
        let calendar = Self.london
        let now = Self.at(20, day: 10, in: calendar)
        let user = UUID()

        let model = Self.harness(
            logs: [
                Self.log("Porridge", kcal: 320, at: Self.at(8, day: 10, in: calendar), user: user),
                Self.log("Chicken salad", kcal: 545, at: Self.at(13, day: 10, in: calendar), user: user),
                Self.log("Salmon and rice", kcal: 640, at: Self.at(19, day: 10, in: calendar), user: user),
            ],
            profile: Self.profile(id: user, on: now, calendar: calendar),
            now: now,
            calendar: calendar
        )

        #expect(model.today(in: .breakfast).map(\.nameSnapshot) == ["Porridge"])
        #expect(model.today(in: .lunch).map(\.nameSnapshot) == ["Chicken salad"])
        #expect(model.today(in: .dinner).map(\.nameSnapshot) == ["Salmon and rice"])
        #expect(model.kcal(in: .dinner) == 640)
        #expect(model.loggedTodayKcal == 1_505)
    }

    /// A corrected slot moves the row on Matchday too, because both screens read
    /// `FoodLog.mealSlot(calendar:)` rather than each deriving their own.
    @Test("a corrected meal slot moves the row on the dashboard")
    func correctedSlotMovesTheRow() {
        let calendar = Self.london
        let now = Self.at(20, day: 10, in: calendar)
        let user = UUID()
        let nightShift = Self.log("Eggs on toast", kcal: 420, at: Self.at(19, day: 10, in: calendar), user: user)
        nightShift.storedMealSlot = .breakfast

        let model = Self.harness(
            logs: [nightShift],
            profile: Self.profile(id: user, on: now, calendar: calendar),
            now: now,
            calendar: calendar
        )

        #expect(model.today(in: .breakfast).map(\.nameSnapshot) == ["Eggs on toast"])
        #expect(model.today(in: .dinner).isEmpty)
    }

    // MARK: - The weight panel

    /// One implementation of the trend, two renderings — the story's own
    /// criterion. Both screens are handed the same `WeightTrend` from the same
    /// repository, so the figure at the top of Matchday is the figure at the top
    /// of The Run.
    @Test("the sparkline and The Run report the same trend value")
    func theTwoScreensAgreeAboutTheTrend() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)
        let user = UUID()
        let readings = (0..<14).compactMap { offset -> WeightLog? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return WeightLog(userID: user, measuredAt: day, kg: 80.6 - 0.05 * Double(13 - offset), source: .manual)
        }

        let matchday = Self.harness(
            weights: readings,
            profile: Self.profile(id: user, on: now, calendar: calendar),
            now: now,
            calendar: calendar
        )
        let theRun = TheRunModel(
            weights: MockWeightRepository(logs: readings),
            profiles: MockProfileRepository(profile: Self.profile(id: user, on: now, calendar: calendar)),
            calendar: calendar,
            now: { now }
        )
        theRun.refresh()

        #expect(matchday.latestTrendKg == theRun.latestTrendKg)
        #expect(matchday.readiness == theRun.readiness)
    }

    /// The one-point state, which came out of Spike A on a real device: a single
    /// same-day entry is a weight with no trend, and saying both is more useful
    /// than drawing a one-point line.
    @Test("the weight panel degrades to the one-reading state")
    func weightDegradesToOnePoint() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)
        let user = UUID()

        let model = Self.harness(
            weights: [WeightLog(userID: user, measuredAt: now, kg: 80.6, source: .manual)],
            profile: Self.profile(id: user, on: now, calendar: calendar),
            now: now,
            calendar: calendar
        )

        #expect(model.readiness == .oneReading)
        #expect(model.latestTrendKg == 80.6)
        // Four weeks of change from one reading is a number nobody measured.
        #expect(model.changeOverFourWeeks == nil)

        let empty = Self.harness(profile: nil, now: now, calendar: calendar)
        #expect(empty.readiness == .noReadings)
        #expect(empty.latestTrendKg == nil)
        #expect(empty.sparkline.isEmpty)
    }

    // MARK: - §10 S6

    /// The opt-out takes the division away and leaves the rest exactly as it
    /// was. That second half is what makes it an opt-out rather than a threat,
    /// and it is the half that erodes — so it is asserted here on the dashboard
    /// as well as in `CompetitiveOptOutTests`.
    @Test("the opt-out removes the division slot and nothing else")
    func optOutRemovesOnlyTheDivision() {
        let calendar = Self.london
        let now = Self.at(15, 30, day: 10, in: calendar)
        let user = UUID()
        // `Profile` is a `@Model`, so this is a reference and the flag is set on
        // it rather than on a copy.
        let profile = Self.profile(id: user, on: now, calendar: calendar)
        profile.competitiveOptOut = true

        let model = Self.harness(
            logs: [Self.log("Porridge", kcal: 320, at: Self.at(8, day: 10, in: calendar), user: user)],
            weights: [WeightLog(userID: user, measuredAt: now, kg: 84, source: .manual)],
            profile: profile,
            now: now,
            calendar: calendar
        )

        #expect(!model.features.showsTierBadges)
        // Everything else on the screen is untouched.
        #expect(model.features.showsTodayDashboard)
        #expect(model.band != nil)
        #expect(model.loggedTodayKcal == 320)
        #expect(model.form.loggedDays == 1)
        #expect(model.readiness == .oneReading)
    }
}
