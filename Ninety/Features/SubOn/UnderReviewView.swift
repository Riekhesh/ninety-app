import SwiftUI

/// Under Review — the confirm-and-correct screen.
///
/// **Mandatory, and the screen is the product decision.** §1.3: trained
/// dietitians misestimate portions by 20–30% and vision models do worse, so
/// *"owning that limitation loudly is better product design than pretending
/// otherwise"*. Every number on here is a figure and a tolerance, every item
/// carries how sure the model was, and the only way off the screen with a row
/// written is the button at the bottom.
///
/// `UnderReviewModel.confirm` is the only write path on the photo route. Nothing
/// else here can reach a repository, so *"no estimate reaches `food_logs`
/// without an explicit confirmation"* is a property of the types rather than a
/// habit of this file.
struct UnderReviewView: View {
    let model: SubOnModel
    var onRetake: () -> Void

    @State private var review: UnderReviewModel
    @State private var isAddingItem = false

    @Environment(\.dismiss)
    private var dismiss

    init(model: SubOnModel, estimate: MealEstimate, onRetake: @escaping () -> Void) {
        self.model = model
        self.onRetake = onRetake
        _review = State(initialValue: UnderReviewModel(estimate: estimate))
    }

    var body: some View {
        Screen(title: SubOnCopy.underReviewMasthead, meta: model.period.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                    warning
                    calls
                    notes
                    total
                    actions
                }
                .padding(.bottom, Ninety.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .sheet(isPresented: $isAddingItem) {
            MissedItemSheet { name, grams, kcal in
                review.add(name: name, grams: grams, kcal: kcal)
            }
        }
    }

    // MARK: - The header that does the honest work

    private var warning: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            Text(SubOnCopy.underReviewEyebrow)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)
            Text(SubOnCopy.underReviewBody)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)
            Text(SubOnCopy.underReviewBody2)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
        .chalkPanel(padding: Ninety.Space.lg)
        .accessibilityElement(children: .combine)
    }

    // MARK: - The items

    @ViewBuilder
    private var calls: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            SectionHeading(
                title: SubOnCopy.callsHeading,
                detail: SubOnCopy.found(review.items.count)
            )

            if review.isEmpty {
                Text(SubOnCopy.nothingLeftToLog)
                    .ninetyType(.subhead)
                    .foregroundStyle(Ninety.Colour.textSecondary)
            } else {
                ForEach(review.items) { item in
                    CallRow(
                        item: item,
                        nudge: { up in review.nudge(item.id, up: up) },
                        remove: { review.remove(item.id) }
                    )
                }
            }

            Button(SubOnCopy.addMissedItem) { isAddingItem = true }
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.accent)
                .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var notes: some View {
        if !review.estimate.notes.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                SectionHeading(title: SubOnCopy.modelNotesHeading)
                Text(review.estimate.notes)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xs) {
            Text(SubOnCopy.mealTotal)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)
            // The confirmed figure, with the model's own spread beside it.
            // Both, because the first is what is about to be logged and the
            // second is how much of it is a guess.
            Text(Figure.kcal(review.confirmedKcal))
                .ninetyType(.metricL)
                .foregroundStyle(Ninety.Colour.textPrimary)
            Text(SubOnCopy.estimated(Figure.range(review.estimatedTotal)))
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
        .chalkPanel(padding: Ninety.Space.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(SubOnCopy.mealTotal) \(Figure.kcal(review.confirmedKcal)) calories. "
                + SubOnCopy.estimated(Figure.range(review.estimatedTotal)) + "."
        )
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Button(SubOnCopy.confirmAction, action: confirm)
                .buttonStyle(.primary)
                .disabled(review.isEmpty || review.isConfirmed)
                .accessibilityLabel(SubOnCopy.confirmLabel(items: review.items.count))

            Button(SubOnCopy.photoRetake) {
                onRetake()
                dismiss()
            }
            .ninetyType(.callout)
            .foregroundStyle(Ninety.Colour.accent)
            .frame(minHeight: 44)

            if review.writeFailed {
                Text(SubOnCopy.writeFailed)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.safety)
            }
        }
    }

    private func confirm() {
        if review.confirm(using: model) { dismiss() }
    }
}

/// One item on the sheet: what it is, how sure, and one tap either way.
private struct CallRow: View {
    let item: EstimatedItem
    let nudge: (Bool) -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
                Text(item.name)
                    .ninetyType(.callout)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Spacer(minLength: Ninety.Space.sm)
                if let confidence = item.confidence {
                    ConfidenceChip(confidence: confidence)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.sm) {
                Text(Figure.kcal(item.confirmedKcal))
                    .ninetyType(.metricM)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Text(SubOnCopy.kcalUnit)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
                Spacer(minLength: 0)
                Text(Figure.grams(item.confirmedGrams))
                    .ninetyType(.metricS)
                    .foregroundStyle(Ninety.Colour.textSecondary)
            }

            // The model's own range, kept visible after a correction rather than
            // replaced by it. It is what the user is correcting *against*, and
            // hiding it the moment they touch the control removes the only
            // reference they had.
            Text(SubOnCopy.estimated("\(Figure.range(item.kcal)) · \(Figure.grams(item.grams.midpoint))"))
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)

            if let note = item.confidence?.note {
                Text(note)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.safety)
            }

            HStack(spacing: Ninety.Space.sm) {
                stepper(up: false)
                stepper(up: true)
                Spacer(minLength: 0)
                Button(SubOnCopy.removeItem, action: remove)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
                    .frame(minHeight: 44)
            }
        }
        .chalkPanel(padding: Ninety.Space.lg)
    }

    /// **Correction is one tap**, which is the acceptance criterion. Not a
    /// sheet, not a slider, not a keyboard — a button that moves the portion by
    /// a step the user can predict.
    private func stepper(up: Bool) -> some View {
        Button {
            nudge(up)
        } label: {
            Image(systemName: up ? "plus" : "minus")
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.accent)
                .frame(minWidth: 44, minHeight: 44)
                .background(Ninety.Colour.surface)
                .ninetyCorners(Ninety.Radius.sm)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            SubOnCopy.nudgeLabel(
                up: up,
                item: item.name,
                grams: Int(UnderReviewModel.step(forGrams: item.confirmedGrams))
            )
        )
    }
}

/// "Something it missed" — the one thing the model cannot be asked for.
///
/// §1.3 names the failure mode this exists for: cooking oil, butter and hidden
/// sugar photograph as nothing at all and are frequently large. An estimate
/// screen with no way to add them would be systematically low and would have no
/// record of *why*.
private struct MissedItemSheet: View {
    var onAdd: (String, Double, Double) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State private var name = ""
    @State private var gramsText = ""
    @State private var kcalText = ""

    var body: some View {
        NavigationStack {
            Screen(title: SubOnCopy.addMissedItem) {
                VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                    NinetyField(label: SubOnCopy.nameField, unit: nil, value: $name, keyboard: .default)
                    NinetyField(label: SubOnCopy.gramsField, unit: "g", value: $gramsText)
                    NinetyField(label: SubOnCopy.kcalField, unit: "kcal", value: $kcalText)

                    Button(SubOnCopy.logAction) {
                        onAdd(
                            name,
                            ManualEntryView.number(gramsText) ?? 0,
                            ManualEntryView.number(kcalText) ?? 0
                        )
                        dismiss()
                    }
                    .buttonStyle(.primary)
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || ManualEntryView.number(kcalText) == nil
                    )
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
    }
}

#if DEBUG
#Preview("Under Review") {
    NavigationStack {
        UnderReviewView(model: SubOnModel.preview, estimate: .artboard, onRetake: {})
    }
}

#Preview("Under Review · light") {
    NavigationStack {
        UnderReviewView(model: SubOnModel.preview, estimate: .artboard, onRetake: {})
    }
    .preferredColorScheme(.light)
}

#Preview("Under Review · accessibility 5") {
    NavigationStack {
        UnderReviewView(model: SubOnModel.preview, estimate: .artboard, onRetake: {})
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
