#if DEBUG
import Foundation
import SwiftUI

/// Fixtures and previews for the dashboard.
///
/// `#if DEBUG`, and in one file with the previews next to the fixture that feeds
/// them — the same arrangement as `SubOnPreviews`, for the same reason: a
/// preview built on different numbers from the tests is a preview of something
/// nobody checked.
///
/// **The numbers are the artboard's**, which are `PRODUCT.md`'s: 1,238 kcal in
/// against an 1,850 ±100 band, five of seven days, 78.4 kg. The ticket asks for
/// real evidence values during development rather than round ones, and this is
/// where that promise is actually kept or broken.
extension MatchdayModel {
    /// A day mid-way through, with a week behind it.
    ///
    /// Every state the screen has is reachable from the parameters rather than
    /// from a second fixture, so the eight previews below are eight readings of
    /// one world instead of eight worlds.
    static func preview(
        loggedToday: Bool = true,
        formDays: Int = 5,
        weighInDays: Int = 56,
        hasProfile: Bool = true,
        optedOut: Bool = false,
        overTheBand: Bool = false
    ) -> MatchdayModel {
        let user = UUID()
        let calendar = Calendar.current
        // Half past three, so the day has a breakfast and a lunch on it and
        // dinner is still to come — which is the state the screen is in for most
        // of the hours anybody opens it.
        let now = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: Date()) ?? Date()

        var logs = loggedToday ? Self.today(user: user, now: now, over: overTheBand) : []
        logs += Self.week(user: user, now: now, days: formDays, calendar: calendar)

        let profile = Profile(
            id: user,
            createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            dob: calendar.date(byAdding: .year, value: -32, to: now),
            heightCm: 178,
            sex: .male,
            activityLevel: .moderate,
            goalType: .lose,
            goalWeightKg: 76,
            targetRateKgPerWeek: 0.5,
            competitiveOptOut: optedOut,
            termsAcceptedAt: now,
            healthConsentAt: now
        )

        let model = MatchdayModel(
            foods: MockFoodRepository(logs: logs, userID: user, now: now),
            profiles: MockProfileRepository(profile: hasProfile ? profile : nil),
            weights: MockWeightRepository(logs: Self.weights(user: user, now: now, days: weighInDays)),
            calendar: calendar,
            now: { now }
        )
        // Explicit, because `init` does not refresh and a preview has no shell
        // to call `onAppear` for it.
        model.refresh()
        return model
    }

    /// Today: two meals with macros behind them and one quick add without, so
    /// the macro panel shows its coverage line rather than claiming the day.
    private static func today(user: UUID, now: Date, over: Bool) -> [FoodLog] {
        let porridge = Food(
            source: .off,
            name: "Porridge & semi-skimmed",
            kcalPer100g: 128,
            proteinG: 4.4,
            carbsG: 18.0,
            fatG: 3.2
        )
        let salad = Food(
            source: .off,
            name: "Chicken salad bowl",
            kcalPer100g: 143,
            proteinG: 12.6,
            carbsG: 8.1,
            fatG: 6.4
        )
        var logs = [
            FoodLog(
                userID: user,
                loggedAt: now.addingTimeInterval(-7 * 3_600),
                grams: 250,
                entryMethod: .search,
                kcal: 320,
                nameSnapshot: porridge.name,
                food: porridge
            ),
            FoodLog(
                userID: user,
                loggedAt: now.addingTimeInterval(-6 * 3_600),
                grams: 220,
                entryMethod: .manual,
                kcal: 120,
                nameSnapshot: "Flat white"
            ),
            FoodLog(
                userID: user,
                loggedAt: now.addingTimeInterval(-2 * 3_600),
                grams: 380,
                entryMethod: .search,
                kcal: 545,
                nameSnapshot: salad.name,
                food: salad
            ),
        ]
        if over {
            logs.append(
                FoodLog(
                    userID: user,
                    loggedAt: now.addingTimeInterval(-1_800),
                    grams: 420,
                    entryMethod: .photo,
                    kcal: 1_180,
                    nameSnapshot: "Takeaway pad thai"
                )
            )
        }
        return logs
    }

    /// The days behind today, one log each, for the Form ring. Day zero is
    /// today and is covered by `today(user:now:over:)`, so this starts at one.
    private static func week(user: UUID, now: Date, days: Int, calendar: Calendar) -> [FoodLog] {
        guard days > 1 else { return [] }
        return (1..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return FoodLog(
                userID: user,
                loggedAt: day,
                grams: 250,
                entryMethod: .manual,
                kcal: 1_820,
                nameSnapshot: "The rest of that day"
            )
        }
    }

    /// A run of −0.3 kg a week with the water on top that the average takes off.
    /// The same shape `TheRunModel.preview` uses, so the two screens draw the
    /// same line — which is the point of them sharing `WeightTrend`.
    private static func weights(user: UUID, now: Date, days: Int) -> [WeightLog] {
        guard days > 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let weeks = Double(days - 1 - offset) / 7
            let noise = [0.0, 0.4, -0.3, 0.2, -0.5, 0.1, 0.3][offset % 7]
            return WeightLog(userID: user, measuredAt: day, kg: 80.6 - 0.3 * weeks + noise, source: .manual)
        }
    }
}

// A function rather than statements inside `#Preview`: its closure is a result
// builder, and an explicit `return` in one is not allowed. `SubOnSheet` and
// `WeightChart` record the same shape for the same reason.
@MainActor
private func matchday(_ model: MatchdayModel) -> some View {
    MatchdayView(model: model, subOn: {}, openSettings: {})
}

#Preview("Matchday") {
    matchday(.preview())
}

#Preview("Matchday · light") {
    matchday(.preview()).preferredColorScheme(.light)
}

#Preview("Matchday · nothing logged today") {
    matchday(.preview(loggedToday: false, formDays: 3))
}

#Preview("Matchday · above the band") {
    matchday(.preview(overTheBand: true))
}

#Preview("Matchday · first day") {
    matchday(.preview(formDays: 1, weighInDays: 1))
}

#Preview("Matchday · no band yet") {
    matchday(.preview(loggedToday: false, formDays: 0, weighInDays: 0, hasProfile: false))
}

#Preview("Matchday · competitive opt-out") {
    matchday(.preview(optedOut: true))
}

/// The capture `docs/phase-1/README.md` has been carrying since P1-A: *"Matchday
/// captured at `.xSmall` and `.accessibility5`"*. Both are here, because the
/// sizes in the tokens are the Large baseline and a layout that only works at
/// one reading size is not finished.
#Preview("Matchday · accessibility 5") {
    matchday(.preview()).dynamicTypeSize(.accessibility5)
}

#Preview("Matchday · x small") {
    matchday(.preview()).dynamicTypeSize(.xSmall)
}
#endif
