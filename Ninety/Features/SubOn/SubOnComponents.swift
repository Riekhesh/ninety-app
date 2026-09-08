import SwiftUI

/// The small pieces the four routes share.
///
/// Not new components in the sense `design/spec/02-components.md` caps at seven
/// — these are compositions of the ones that exist (the chalk panel, the
/// secondary button, the chip) given names so the four routes cannot each grow
/// their own slightly different food row.

/// A number in the app's voice: grouped, and never to a decimal place.
///
/// §1.2's rule, in one place. `no_false_precision_kcal` catches the formatted
/// version of the mistake; this is how the right thing is easier to type than
/// the wrong one.
enum Figure {
    static func kcal(_ value: Double) -> String { kcal(Int(value.rounded())) }

    static func kcal(_ value: Int) -> String { value.formatted(.number.grouping(.automatic)) }

    /// A figure and its tolerance. **Never two numbers joined by a dash** —
    /// `PRODUCT.md` and the Under Review ticket both say so, because the dash
    /// form reads as a rule about where to stay and this is an estimate with
    /// slack in it.
    static func range(_ range: EstimateRange) -> String {
        range.tolerance == 0 ? kcal(range.centre) : "\(kcal(range.centre)) ±\(kcal(range.tolerance))"
    }

    static func grams(_ value: Double) -> String {
        "\(Int(value.rounded())) g"
    }
}

/// The four routes, as a row of chips.
struct RouteChips: View {
    @Binding var route: SubOnModel.Route?

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            Text(SubOnCopy.routesLabel)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)

            // A scroll view rather than a fixed row: four labels in the
            // broadcast face at `.accessibility5` do not fit across a phone,
            // and a chip that truncates its own name is worse than one the user
            // has to reach for.
            ScrollView(.horizontal) {
                HStack(spacing: Ninety.Space.sm) {
                    ForEach(SubOnModel.Route.allCases) { option in
                        chip(for: option)
                    }
                }
                .padding(.vertical, Ninety.Space.hair)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(SubOnCopy.routesLabel)
    }

    private func chip(for option: SubOnModel.Route) -> some View {
        Button {
            route = option
        } label: {
            HStack(spacing: Ninety.Space.sm) {
                Image(systemName: option.symbol)
                    .accessibilityHidden(true)
                Text(option.title)
                    .ninetyType(.label)
            }
            .foregroundStyle(Ninety.Colour.textPrimary)
            .padding(.horizontal, Ninety.Space.md)
            .frame(minHeight: 44)
            .background(Ninety.Colour.surface)
            .ninetyCorners(Ninety.Radius.sm)
            .overlay {
                RoundedRectangle(cornerRadius: Ninety.Radius.sm, style: .continuous)
                    .strokeBorder(Ninety.Colour.stroke, lineWidth: Ninety.Border.hairline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
    }
}

/// One food on the team sheet, or one search result. Tapping it logs it.
struct FoodRow: View {
    let name: String
    /// The line underneath: the portion, and how often or how recently.
    let detail: String
    let kcal: Double
    /// Shown at the leading edge on the Squad — the artboard's shirt number.
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
                if let badge {
                    Text(badge)
                        .ninetyType(.metricS)
                        .foregroundStyle(Ninety.Colour.accent)
                        .frame(minWidth: 24, alignment: .leading)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                    Text(name)
                        .ninetyType(.callout)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .ninetyType(.label)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                }

                Spacer(minLength: Ninety.Space.sm)

                Text(Figure.kcal(kcal))
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
        .accessibilityLabel("\(name). \(detail). \(Figure.kcal(kcal)) calories.")
        .accessibilityAddTraits(.isButton)
    }
}

/// HIGH / MEDIUM / LOW, as a chip.
///
/// Never colour alone. ADR 0012's rule about tiers generalises to every state
/// the app carries: the word is the signal and the tint is the second one, so a
/// colourblind user reads the same thing everybody else does.
struct ConfidenceChip: View {
    let confidence: EstimateConfidence

    var body: some View {
        Text(confidence.label)
            .ninetyType(.label)
            .foregroundStyle(tint)
            .padding(.horizontal, Ninety.Space.sm)
            .padding(.vertical, Ninety.Space.xs)
            .background(Ninety.Colour.surfaceSunken)
            .ninetyCorners(Ninety.Radius.sm)
            .overlay {
                RoundedRectangle(cornerRadius: Ninety.Radius.sm, style: .continuous)
                    .strokeBorder(tint.opacity(0.5), lineWidth: Ninety.Border.hairline)
            }
            .accessibilityLabel("Confidence \(confidence.label)")
    }

    /// `safety` for low, and deliberately not `critical`: the model being unsure
    /// is not the user having done anything wrong, and the token set has no
    /// error colour for anything on this screen.
    private var tint: Color {
        switch confidence {
        case .high: Ninety.Colour.positive
        case .medium: Ninety.Colour.textSecondary
        case .low: Ninety.Colour.safety
        }
    }
}

/// A section heading in the broadcast voice, with its caption.
struct SectionHeading: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.sm) {
            Text(title)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)
            if let detail {
                Text(detail)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The strip after a log lands: what went on, and the way to take it back.
///
/// **No animation on it beyond a fade.** `DESIGN.md` caps everything routine at
/// 0.3s, and a log arriving is the most routine thing the app does.
struct LoggedStrip: View {
    let name: String
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: Ninety.Space.md) {
            Text("\(SubOnCopy.added) · \(name)")
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textPrimary)
            Spacer(minLength: Ninety.Space.sm)
            Button(SubOnCopy.undo, action: undo)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.accent)
                .frame(minHeight: 44)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(Ninety.Colour.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(SubOnCopy.dismiss)
        }
        .padding(.horizontal, Ninety.Space.md)
        .background(Ninety.Colour.surfaceSunken)
        .ninetyCorners(Ninety.Radius.md)
    }
}
