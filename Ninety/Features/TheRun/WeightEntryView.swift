import SwiftUI

/// Recording a weigh-in.
///
/// **This is the half of P1-G that day 0 was waiting on.** Onboarding wrote one
/// `WeightLog` and nothing in the app could write a second, so P1-J's criterion
/// — *"real food, real weight"* — had one half built and one half missing. Four
/// logging routes and no way to record tomorrow's weight is not a daily-usable
/// tracker, and the twenty-one days are the one cost no effort compresses.
///
/// A sheet rather than a screen for the same reason Sub On is one: weighing in
/// has a beginning and an end and returns you to the trend you opened it from.
struct WeightEntryView: View {
    let model: TheRunModel

    @Environment(\.dismiss)
    private var dismiss

    @State private var weightText = ""

    /// When it was measured, not when it was typed.
    ///
    /// Defaulted to now and editable, because weighing yourself at seven and
    /// remembering to record it at eleven is the normal case rather than the
    /// exception — and the series runs on calendar days, so a reading stamped
    /// with the wrong day lands in the wrong bucket. The picker cannot reach the
    /// future: a weight measured tomorrow is not a thing.
    @State private var measuredAt = Date()

    var body: some View {
        NavigationStack {
            Screen(title: TheRunCopy.entryTitle) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                        Text(TheRunCopy.entryDetail)
                            .ninetyType(.subhead)
                            .foregroundStyle(Ninety.Colour.textSecondary)

                        NinetyField(
                            label: TheRunCopy.weightField,
                            unit: "kg",
                            value: $weightText,
                            safetyMessage: refusal
                        )

                        if let last = model.mostRecent {
                            // The typo guard. §2.3 prefers flagging to
                            // rejecting, and the app has no honest basis to
                            // refuse 7.84 — but nobody types it with last
                            // week's number sitting under the field.
                            Text(TheRunCopy.lastReading(last.kg, at: last.measuredAt))
                                .ninetyType(.footnote)
                                .foregroundStyle(Ninety.Colour.textTertiary)
                        }

                        DatePicker(
                            TheRunCopy.whenField,
                            selection: $measuredAt,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .ninetyType(.callout)
                        .tint(Ninety.Colour.accent)

                        Button(TheRunCopy.saveWeight, action: save)
                            .buttonStyle(.primary)
                            .disabled(!canSave)

                        if model.writeFailed {
                            Text(TheRunCopy.writeFailed)
                                .ninetyType(.footnote)
                                .foregroundStyle(Ninety.Colour.safety)
                        }
                    }
                    .padding(.bottom, Ninety.Space.xxl)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SubOnCopy.close) { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(Ninety.Colour.accent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - What the field means

    /// Nil for empty or valid. Non-nil turns the border `safety` and — per the
    /// component spec's Safety-blocked state — keeps the primary action
    /// disabled, which is the caller's job and is `canSave` below.
    private var refusal: String? {
        guard let kg else { return nil }
        return TheRunModel.isStorable(kg) ? nil : TheRunCopy.outOfRange
    }

    /// Shares `ManualEntryView`'s parser rather than growing a second one: a
    /// decimal pad in most of Europe produces a comma, and two screens
    /// disagreeing about that is a bug that only appears abroad.
    private var kg: Double? { ManualEntryView.number(weightText) }

    private var canSave: Bool {
        guard let kg else { return false }
        return TheRunModel.isStorable(kg)
    }

    private func save() {
        guard let kg, model.record(kg: kg, at: measuredAt) else { return }
        dismiss()
    }
}

#if DEBUG
#Preview("Weigh in") {
    WeightEntryView(model: .preview())
}

#Preview("Weigh in · accessibility 5") {
    WeightEntryView(model: .preview()).dynamicTypeSize(.accessibility5)
}
#endif
