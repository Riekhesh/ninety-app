import SwiftUI

/// Component 2 from `design/spec/02-components.md`: the text input.
///
/// **The label sits above the field, never inside it.** A placeholder doing
/// double duty as a label disappears exactly when it is needed — the moment
/// there is a value to check against it.
///
/// **There is no `critical` state on an input**, and that is the interesting
/// part of the spec. A user typing a goal weight below BMI 18.5 has not made an
/// *error*; they have hit a §10 limit. `safety` is the token that says so, and
/// the difference between the two is the difference between "you're wrong" and
/// "we won't go there".
struct NinetyField: View {
    let label: String

    /// The unit, shown as a suffix inside the field. §2's numeric rule: never a
    /// bare number.
    let unit: String?

    @Binding var value: String

    /// A §10 refusal, in the copy deck's words. Non-nil turns the border and the
    /// message `safety` — and, per the spec's Safety-blocked state, the screen's
    /// primary action stays disabled while it is showing. That second half is
    /// the caller's job, because the button is not this component's to disable.
    var safetyMessage: String?

    var keyboard: UIKeyboardType = .decimalPad

    @FocusState private var isFocused: Bool

    /// Grows with the value, so the 50pt minimum is a floor rather than a frame
    /// that clips its own text at accessibility sizes.
    @ScaledMetric(relativeTo: .body)
    private var minimumHeight: CGFloat = 50

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            Text(label)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)

            HStack(spacing: Ninety.Space.sm) {
                TextField("", text: $value)
                    .ninetyType(.metricS)
                    .keyboardType(keyboard)
                    .focused($isFocused)
                    .foregroundStyle(Ninety.Colour.textPrimary)

                if let unit {
                    Text(unit)
                        .ninetyType(.subhead)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                }
            }
            .padding(Ninety.Space.md)
            .frame(minHeight: minimumHeight)
            .background(Ninety.Colour.surfaceSunken)
            .ninetyCorners(Ninety.Radius.md)
            .overlay {
                RoundedRectangle(cornerRadius: Ninety.Radius.md, style: .continuous)
                    .strokeBorder(border, lineWidth: borderWidth)
            }

            if let safetyMessage {
                Text(safetyMessage)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.safety)
                    .accessibilityLabel("\(label). \(safetyMessage)")
            }
        }
    }

    /// Safety wins over focus: a field showing a refusal keeps showing it while
    /// the user is in it, because that is when the refusal is being answered.
    private var border: Color {
        if safetyMessage != nil { return Ninety.Colour.safety }
        return isFocused ? Ninety.Colour.accent : Ninety.Colour.strokeStrong
    }

    /// The focus ring is `Border.focus` and is never removed — the spec's one
    /// absolute about this component. A refusal draws at the same weight,
    /// because it has at least as much claim on the user's attention.
    private var borderWidth: CGFloat {
        isFocused || safetyMessage != nil ? Ninety.Border.focus : Ninety.Border.hairline
    }
}

#Preview("Field") {
    VStack(alignment: .leading, spacing: Ninety.Space.xl) {
        NinetyField(label: "Today's weight", unit: "kg", value: .constant("78.4"))
        NinetyField(
            label: "Goal weight",
            unit: "kg",
            value: .constant("48"),
            safetyMessage: """
                That goal weight is below the healthy range for your height \
                (which starts at 56.7 kg).
                """
        )
    }
    .padding(Ninety.Space.xl)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Pitch())
}

#Preview("Field · accessibility 5") {
    NinetyField(label: "Height", unit: "cm", value: .constant("175"))
        .padding(Ninety.Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Pitch())
        .dynamicTypeSize(.accessibility5)
}
