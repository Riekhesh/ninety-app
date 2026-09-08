import SwiftUI

/// Path 0 — type it in.
///
/// **The route that starts the 21-day clock**, and the only one that depends on
/// nothing at all: no network, no camera, no catalogue. Everything else in P1-F
/// is a shortcut to this, which is why it is built first and why it is the one
/// every failure elsewhere falls back to.
///
/// Two shapes on one screen, and the difference is what the user knows. A food
/// with a portion and a calorie figure becomes a food they can keep; a number
/// somebody read off a menu becomes a quick add with no food behind it. The
/// artboard has both — "Quick add by calories · WHEN YOU ONLY KNOW THE NUMBER".
/// A food that arrived from somewhere, on its way to a portion.
///
/// It carries **how it was found** as well as what it is, and that is the
/// interesting field: three of the four routes end on this screen, and each one
/// owes `food_logs.entry_method` a different value. Without this the portion
/// screen would have to guess, and the entry-method breakdown — which is how
/// Phase 2 finds out which routes actually get used — would record every log as
/// manual.
struct PortionPrefill: Identifiable, Hashable {
    let id = UUID()
    let food: FoodDraft
    let entryMethod: EntryMethod

    static func == (lhs: PortionPrefill, rhs: PortionPrefill) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ManualEntryView: View {
    let model: SubOnModel

    /// A food carried in from search or a barcode scan. Nil is the typed case,
    /// which is `manual` and needs nothing at all to work.
    let prefill: PortionPrefill?

    @Environment(\.dismiss)
    private var dismiss

    @State private var name = ""
    @State private var gramsText = ""
    @State private var kcalText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var keepForNextTime = true

    var body: some View {
        Screen(title: SubOnCopy.manualTitle, meta: model.period.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                    Text(SubOnCopy.manualDetail)
                        .ninetyType(.subhead)
                        .foregroundStyle(Ninety.Colour.textSecondary)

                    NinetyField(
                        label: SubOnCopy.nameField,
                        unit: nil,
                        value: $name,
                        keyboard: .default
                    )
                    NinetyField(label: SubOnCopy.gramsField, unit: "g", value: $gramsText)
                    NinetyField(label: SubOnCopy.kcalField, unit: "kcal", value: $kcalText)

                    macros

                    Toggle(SubOnCopy.saveForNextTime, isOn: $keepForNextTime)
                        .ninetyType(.callout)
                        .tint(Ninety.Colour.accent)
                        .disabled(!canKeep)
                    Text(canKeep ? SubOnCopy.saveForNextTimeDetail : SubOnCopy.quickAddDetail)
                        .ninetyType(.footnote)
                        .foregroundStyle(Ninety.Colour.textTertiary)

                    Button(SubOnCopy.logAction, action: log)
                        .buttonStyle(.primary)
                        .disabled(!canLog)

                    if model.writeFailed {
                        Text(SubOnCopy.writeFailed)
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.safety)
                    }
                }
                .padding(.bottom, Ninety.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear(perform: applyPrefill)
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            // Stacked rather than three across. Three fields in a row at
            // `.accessibility5` is a layout nobody has drawn, and `ChoiceRow`
            // records the same decision for the same reason.
            NinetyField(label: SubOnCopy.proteinField, unit: "g", value: $proteinText)
            NinetyField(label: SubOnCopy.carbsField, unit: "g", value: $carbsText)
            NinetyField(label: SubOnCopy.fatField, unit: "g", value: $fatText)
            Text(SubOnCopy.macrosOptional)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }

    // MARK: - What the fields mean

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var grams: Double? { Self.number(gramsText) }
    private var kcal: Double? { Self.number(kcalText) }

    /// A log needs a name and a calorie figure, and nothing else. The portion is
    /// optional because a quick add genuinely does not have one — somebody
    /// reading a number off a menu knows the calories and not the grams, and
    /// refusing them is refusing the case the row exists for.
    private var canLog: Bool {
        !trimmedName.isEmpty && (kcal ?? 0) > 0
    }

    /// A food can only be *kept* if there is a portion to keep it against —
    /// `kcal_per_100g` is meaningless without one.
    private var canKeep: Bool {
        (grams ?? 0) > 0 && (kcal ?? 0) > 0
    }

    private func applyPrefill() {
        guard let prefill = prefill?.food, name.isEmpty, !prefill.name.isEmpty else { return }
        name = prefill.name
        // 100 g, because that is the unit the catalogue stores and the number
        // the user is about to correct. A guessed portion would be a number
        // nobody measured presented as a starting point.
        gramsText = "100"
        kcalText = "\(Int(prefill.kcalPer100g.rounded()))"
        proteinText = Self.text(prefill.proteinG)
        carbsText = Self.text(prefill.carbsG)
        fatText = Self.text(prefill.fatG)
    }

    private func log() {
        guard canLog, let kcal else { return }
        let portion = grams ?? 0

        var food: Food?
        if keepForNextTime, canKeep {
            food = model.saveCustomFood(
                FoodDraft(
                    id: prefill?.food.id,
                    source: .custom,
                    barcode: prefill?.food.barcode,
                    name: trimmedName,
                    brand: prefill?.food.brand,
                    kcalPer100g: (kcal / portion * 100).rounded(),
                    proteinG: Self.number(proteinText),
                    carbsG: Self.number(carbsText),
                    fatG: Self.number(fatText)
                )
            )
        }

        let logged = model.log(
            FoodLogDraft(
                food: food,
                // The schema's check is `grams > 0`, and a quick add has no
                // portion. One gram rather than a refusal: the row is about the
                // energy, and the alternative is telling somebody who knows the
                // calories that they may not log them.
                grams: max(portion, 1),
                kcal: kcal,
                name: trimmedName,
                // Whatever actually found the food. A barcode that resolved to
                // nothing and was then typed in by hand arrives here with no
                // prefill and is recorded as `manual` — the breakdown is a
                // record of what happened, not of what was attempted.
                entryMethod: prefill?.entryMethod ?? .manual,
                loggedAt: Date()
            )
        )

        if logged != nil { dismiss() }
    }

    // MARK: - Parsing

    /// Nil for anything that is not a positive number. Accepts a comma decimal
    /// separator, because a decimal pad in most of Europe produces one.
    static func number(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    private static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.rounded() == value ? "\(Int(value))" : "\(value)"
    }
}

#if DEBUG
#Preview("Manual entry") {
    NavigationStack {
        ManualEntryView(model: SubOnModel.preview, prefill: nil)
    }
}

#Preview("Manual entry · accessibility 5") {
    NavigationStack {
        ManualEntryView(model: SubOnModel.preview, prefill: nil)
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
