import SwiftUI

/// The day's meals, as a team sheet.
///
/// **Read-only, and that is the division of labour rather than an omission.**
/// Sub On's Today list is where a log is corrected or removed — it is the list
/// you check while you are still standing in the place you did the logging, and
/// §2.3's forty-eight-hour window is surfaced there with the copy that explains
/// it. This is the same rows doing a different job: the shape of the day, under
/// the figure the day adds up to. Two editing surfaces for one row would be two
/// places for the lock to be got wrong.
///
/// **Grouped by meal** (ADR 0022), and grouping it was the argument for the
/// column. Breakfast / lunch / dinner is a day somebody recognises; First Half
/// and Second Half told you less than the timestamps they were derived from.
struct TeamSheetPanel: View {
    let model: MatchdayModel
    let subOn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            SectionHeading(
                title: MatchdayCopy.teamSheetHeading,
                detail: model.today.isEmpty
                    ? nil
                    : MatchdayCopy.teamSheetDetail(items: model.today.count, kcal: model.loggedTodayKcal)
            )

            if model.today.isEmpty {
                HoldingNote(
                    eyebrow: MatchdayCopy.teamSheetHeading,
                    headline: MatchdayCopy.nothingLogged,
                    detail: MatchdayCopy.nothingLoggedDetail
                )
            } else {
                ForEach(MealSlot.allCases) { slot in
                    meal(slot)
                }
            }

            Button(MatchdayCopy.subOn, action: subOn)
                .buttonStyle(.primary)
                .accessibilityLabel(MatchdayCopy.subOnHint)
        }
    }

    /// One meal, with its own total. A slot with nothing in it is absent rather
    /// than drawn empty — an empty Lunch heading at four in the afternoon is the
    /// app pointing out a meal you have not logged, which is the shape of a
    /// nudge and not of a dashboard.
    @ViewBuilder
    private func meal(_ slot: MealSlot) -> some View {
        let logs = model.today(in: slot)
        if !logs.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.sm) {
                    Text(slot.title)
                        .ninetyType(.label)
                        .foregroundStyle(Ninety.Colour.accent)
                    Rectangle()
                        .fill(Ninety.Colour.stroke)
                        .frame(height: Chalk.faint)
                    Text(Figure.kcal(model.kcal(in: slot)))
                        .ninetyType(.label)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(slot.title), \(Figure.kcal(model.kcal(in: slot))) calories")
                .accessibilityAddTraits(.isHeader)

                ForEach(logs, id: \.id) { log in
                    row(log)
                }
            }
        }
    }

    private func row(_ log: FoodLog) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
            VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                Text(log.nameSnapshot)
                    .ninetyType(.callout)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Text(detail(log))
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
            Spacer(minLength: Ninety.Space.sm)
            Text(Figure.kcal(log.kcal))
                .ninetyType(.metricS)
                .foregroundStyle(Ninety.Colour.textPrimary)
        }
        .padding(.vertical, Ninety.Space.sm)
        .chalkRule(Chalk.faint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(log.nameSnapshot). \(detail(log)). \(Figure.kcal(log.kcal)) calories.")
    }

    /// `09:15 · 170 g`. No lock state and no entry method: neither is actionable
    /// from here, and a row that shows a rule it cannot let you act on is a row
    /// that raises a question it cannot answer.
    private func detail(_ log: FoodLog) -> String {
        let time = log.loggedAt.formatted(date: .omitted, time: .shortened)
        return "\(time) · \(Figure.grams(log.grams))"
    }
}

/// Where the division badge lands in Phase 2.
///
/// **Reserved and honest, with no invented tier in it.** The task's acceptance
/// criterion is explicit — no sample rank, no other user's name or number
/// anywhere in v1 — and this is the one slot on the screen where the temptation
/// to fill the layout with a plausible-looking badge is real. `HoldingNote` is
/// the type that exists to refuse it.
///
/// **Absent entirely under the opt-out** (§10 S6). The division is the
/// competitive surface, so a user who has turned competition off does not get a
/// reserved space for one — `CompetitiveFeatures.showsTierBadges` is the flag,
/// and the rest of the screen is untouched by it, which is the half of the
/// requirement that makes it an opt-out rather than a threat.
struct DivisionSlot: View {
    let calibration: CalibrationState?

    var body: some View {
        HoldingNote(
            eyebrow: MatchdayCopy.divisionHeading,
            headline: MatchdayCopy.divisionPlaceholder,
            detail: detail
        )
    }

    /// During calibration the countdown is the more useful of the two true
    /// things, and it is the same sentence The Table gives — two screens with a
    /// division-shaped hole must not imply that one of them knows more.
    private var detail: String {
        if let calibration, case .calibrating(let remaining) = calibration {
            let days = remaining == 1 ? "day" : "days"
            return """
                Ninety is learning your baseline. \(remaining) \(days) of the first week to go, \
                and no division is assigned until it closes.
                """
        }
        return MatchdayCopy.divisionDetail
    }
}
