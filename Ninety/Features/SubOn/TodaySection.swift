import SwiftUI

/// What you have logged today, and the way to correct it.
///
/// **The hole this fills.** Four routes wrote rows and nothing read them back.
/// The undo strip covered only the last entry and vanished the moment anything
/// else was logged, so a Squad row tapped twice by accident was permanent — and
/// §2.3's forty-eight-hour edit window had been in the repository, tested, since
/// P1-B with no surface at all.
///
/// **Grouped by half rather than by meal.** First Half and Second Half are pure
/// functions of `logged_at` in the user's own calendar, so this costs no column
/// and no migration. It is most of what a lunch-and-dinner breakdown would give
/// you; whether Ninety ever grows real meal slots is a product decision with a
/// migration behind it, and this is deliberately not a down-payment on one.
struct TodaySection: View {
    let model: SubOnModel

    @State private var editing: Correction?

    /// A log on its way to the correction sheet.
    ///
    /// `FoodLog` is a `@Model`, so its `Identifiable` conformance keys on
    /// `persistentModelID` — a value that only means anything once the object is
    /// in a context, and the preview mocks never insert theirs. Everything here
    /// keys on the row's own `id` instead, which is the same UUID Postgres uses
    /// and is set the moment the object exists.
    private struct Correction: Identifiable {
        let log: FoodLog
        var id: UUID { log.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            SectionHeading(title: SubOnCopy.todayHeading, detail: SubOnCopy.todayDetail)

            if model.today.isEmpty {
                // The copy deck's Today wording, and a `HoldingNote` rather than
                // an empty box: never a skeleton where the answer is "there is
                // nothing yet".
                HoldingNote(
                    eyebrow: SubOnCopy.todayHeading,
                    headline: SubOnCopy.nothingLoggedYet,
                    detail: SubOnCopy.nothingLoggedDetail
                )
            } else {
                ForEach(MealPeriod.allCases) { period in
                    half(period)
                }
            }
        }
        .sheet(item: $editing) { correction in
            CorrectLogSheet(model: model, log: correction.log)
        }
    }

    @ViewBuilder
    private func half(_ period: MealPeriod) -> some View {
        let logs = model.today(in: period)
        if !logs.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                Text(period.title)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(logs, id: \.id) { log in
                    LoggedRow(
                        log: log,
                        isEditable: model.isEditable(log),
                        edit: { editing = Correction(log: log) }
                    )
                }
            }
        }
    }
}

/// One thing eaten. Tapping it opens the correction sheet.
private struct LoggedRow: View {
    let log: FoodLog
    let isEditable: Bool
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
                VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                    Text(log.nameSnapshot)
                        .ninetyType(.callout)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .ninetyType(.label)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                }
                Spacer(minLength: Ninety.Space.sm)
                Text(Figure.kcal(log.kcal))
                    .ninetyType(.metricS)
                    .foregroundStyle(Ninety.Colour.textPrimary)
            }
            .padding(Ninety.Space.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Ninety.Colour.surface)
            .ninetyCorners(Ninety.Radius.md)
            .overlay {
                RoundedRectangle(cornerRadius: Ninety.Radius.md, style: .continuous)
                    .strokeBorder(Ninety.Colour.stroke, lineWidth: Ninety.Border.hairline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(log.nameSnapshot). \(detail). \(Figure.kcal(log.kcal)) calories.")
        .accessibilityHint(isEditable ? SubOnCopy.todayDetail : SubOnCopy.lockedNote)
    }

    /// "18:40 · 170 g", plus the lock once the window has closed. The locked
    /// state is a word rather than a greyed-out row: a control that is disabled
    /// with no explanation is the thing §2.3's copy exists to avoid.
    private var detail: String {
        let time = log.loggedAt.formatted(date: .omitted, time: .shortened)
        let portion = "\(time) · \(Figure.grams(log.grams))"
        return isEditable ? portion : "\(portion) · \(SubOnCopy.lockedRow)"
    }
}

/// Change a portion, or take the log back out.
private struct CorrectLogSheet: View {
    let model: SubOnModel
    let log: FoodLog

    @Environment(\.dismiss)
    private var dismiss

    @State private var gramsText = ""
    @State private var kcalText = ""

    private var isEditable: Bool { model.isEditable(log) }

    var body: some View {
        NavigationStack {
            Screen(title: SubOnCopy.editTitle, meta: log.nameSnapshot) {
                VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                    if isEditable {
                        NinetyField(label: SubOnCopy.gramsField, unit: "g", value: $gramsText)
                        NinetyField(label: SubOnCopy.kcalField, unit: "kcal", value: $kcalText)

                        Button(SubOnCopy.saveEdit, action: save)
                            .buttonStyle(.primary)
                            .disabled(ManualEntryView.number(kcalText) == nil)
                    } else {
                        // §2.3, stated rather than implied. A rule somebody can
                        // see the point of is one they accept; a mysteriously
                        // disabled field is not.
                        HoldingNote(
                            eyebrow: SubOnCopy.lockedRow,
                            headline: SubOnCopy.lockedNote,
                            detail: """
                                \(Figure.grams(log.grams)) · \(Figure.kcal(log.kcal)) kcal, \
                                logged \(log.loggedAt.formatted(.relative(presentation: .named))).
                                """
                        )
                    }

                    Button(SubOnCopy.removeItem, action: remove)
                        .ninetyType(.callout)
                        // `safety`, not `critical`. Removing a log you did not
                        // mean to make is housekeeping, not a destructive act
                        // the app should be dramatic about.
                        .foregroundStyle(Ninety.Colour.safety)
                        .frame(minHeight: 44)
                        .disabled(!isEditable)

                    if model.writeFailed {
                        Text(SubOnCopy.writeFailed)
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.safety)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SubOnCopy.close) { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(Ninety.Colour.accent)
        .presentationDetents([.medium])
        .onAppear {
            gramsText = "\(Int(log.grams.rounded()))"
            kcalText = "\(Int(log.kcal.rounded()))"
        }
    }

    private func save() {
        guard let kcal = ManualEntryView.number(kcalText) else { return }
        if model.update(log, grams: ManualEntryView.number(gramsText) ?? log.grams, kcal: kcal) {
            dismiss()
        }
    }

    private func remove() {
        if model.delete(log) { dismiss() }
    }
}
