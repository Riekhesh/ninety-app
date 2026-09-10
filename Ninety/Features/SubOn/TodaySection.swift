import SwiftUI

/// What you have logged today, and the way to correct it.
///
/// **The hole this fills.** Four routes wrote rows and nothing read them back.
/// The undo strip covered only the last entry and vanished the moment anything
/// else was logged, so a Squad row tapped twice by accident was permanent — and
/// §2.3's forty-eight-hour edit window had been in the repository, tested, since
/// P1-B with no surface at all.
///
/// **Grouped by meal** (ADR 0022). Breakfast, lunch and dinner replaced First
/// Half and Second Half when Matchday's team sheet made two buckets stop being
/// enough. The slot is still derived from `logged_at` for almost every row, so
/// logging costs the same number of taps it did; what the column bought is the
/// row the derivation gets wrong — a night shift, a very late dinner — which is
/// corrected in the sheet below and stays corrected.
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
                ForEach(MealSlot.allCases) { slot in
                    meal(slot)
                }
            }
        }
        .sheet(item: $editing) { correction in
            CorrectLogSheet(model: model, log: correction.log)
        }
    }

    @ViewBuilder
    private func meal(_ slot: MealSlot) -> some View {
        let logs = model.today(in: slot)
        if !logs.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                Text(slot.title)
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

    /// Seeded from the log on appear, which for almost every row is the derived
    /// answer rather than a stored one. The picker does not distinguish them and
    /// does not need to: the repository stores a slot only where it disagrees
    /// with the derivation, so re-picking what was already showing is a no-op
    /// rather than a write (ADR 0022).
    @State private var slot: MealSlot = .breakfast

    private var isEditable: Bool { model.isEditable(log) }

    var body: some View {
        NavigationStack {
            Screen(title: SubOnCopy.editTitle, meta: log.nameSnapshot) {
                VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                    if isEditable {
                        NinetyField(label: SubOnCopy.gramsField, unit: "g", value: $gramsText)
                        NinetyField(label: SubOnCopy.kcalField, unit: "kcal", value: $kcalText)
                        mealPicker

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
            slot = model.slot(of: log)
        }
    }

    /// Which meal it was, when the clock got it wrong.
    ///
    /// A segmented picker rather than a menu: three options that always fit, and
    /// the current one is readable without opening anything — which is the point,
    /// because for almost every row the right answer is already selected and the
    /// user is here about the portion.
    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            Text(SubOnCopy.mealField)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)

            Picker(SubOnCopy.mealField, selection: $slot) {
                ForEach(MealSlot.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(SubOnCopy.mealField)

            Text(SubOnCopy.mealFieldNote)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }

    private func save() {
        guard let kcal = ManualEntryView.number(kcalText) else { return }
        let landed = model.update(
            log,
            grams: ManualEntryView.number(gramsText) ?? log.grams,
            kcal: kcal,
            mealSlot: slot
        )
        if landed { dismiss() }
    }

    private func remove() {
        if model.delete(log) { dismiss() }
    }
}
