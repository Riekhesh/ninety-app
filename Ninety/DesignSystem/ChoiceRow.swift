import SwiftUI

/// A choice between a handful of named options — the Secondary button variant
/// from `design/spec/02-components.md` §1, stacked.
///
/// **Not an eighth component**, and the spec's cap is worth honouring rather
/// than working around: this is the Secondary button doing what a Secondary
/// button does, with a selected state added. Pre-Season is four of these (sex,
/// activity level, goal, rate) and nothing else in the app needs one.
///
/// **Stacked full-width rather than a wrapping row of chips.** A flow layout
/// that reflows five activity levels at `.accessibility5` is a custom `Layout`
/// and a set of edge cases; a column is neither, reads the same at every type
/// size, and gives each option a target far above 44pt. The artboards show chips
/// because the artboards are at the Large baseline — `DESIGN.md` records that
/// their sizes are a baseline and not the layout.
struct ChoiceRow<Value: Hashable>: View {
    /// One option: the value it selects and the words on it.
    struct Option: Identifiable {
        let value: Value
        let title: String
        /// The line under the title, where an option needs one — the activity
        /// levels are meaningless without it.
        let detail: String?

        var id: Value { value }

        init(_ value: Value, title: String, detail: String? = nil) {
            self.value = value
            self.title = title
            self.detail = detail
        }
    }

    let label: String
    let options: [Option]
    @Binding var selection: Value

    /// Shown instead of the options when there are none.
    ///
    /// Not a theoretical state: S3 filters the rate options against the user's
    /// ceiling, and below about 25 kg every one of them is above it. An empty
    /// control that says why is honest; silently offering the slowest rate
    /// anyway would be the app overriding its own safety limit.
    var emptyNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            Text(label)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)

            if options.isEmpty, let emptyNote {
                Text(emptyNote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.safety)
            }

            ForEach(options) { option in
                button(for: option)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func button(for option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            selection = option.value
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
                VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                    Text(option.title)
                        .ninetyType(.callout)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                    if let detail = option.detail {
                        Text(detail)
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.textTertiary)
                    }
                }
                Spacer(minLength: Ninety.Space.sm)
                // The tick is the selection signal; the gold edge is the
                // second one. ADR 0012's rule generalises — a state carried
                // by colour alone is a state a colourblind user cannot read.
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Ninety.Colour.accent : Ninety.Colour.stroke)
                    .accessibilityHidden(true)
            }
            .padding(Ninety.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Ninety.Colour.accentSubtle : Ninety.Colour.surface)
            .ninetyCorners(Ninety.Radius.md)
            .overlay {
                RoundedRectangle(cornerRadius: Ninety.Radius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? Ninety.Colour.accent : Ninety.Colour.stroke,
                        lineWidth: isSelected ? Ninety.Border.focus : Ninety.Border.hairline
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Choice row") {
    ChoiceRow(
        label: "Activity level",
        options: [
            .init(ActivityLevel.sedentary, title: "Sedentary", detail: "Desk job, little exercise"),
            .init(ActivityLevel.light, title: "Light", detail: "Some walking, one or two sessions a week"),
            .init(ActivityLevel.moderate, title: "Moderate", detail: "Three or four sessions a week"),
        ],
        selection: .constant(ActivityLevel.light)
    )
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
}

#Preview("Choice row · accessibility 5") {
    ChoiceRow(
        label: "How fast?",
        options: [
            .init(0.25, title: "Steady · 0.25 kg/week"),
            .init(0.5, title: "Moderate · 0.5 kg/week"),
        ],
        selection: .constant(0.5)
    )
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
    .dynamicTypeSize(.accessibility5)
}
