// GENERATED FILE — DO NOT EDIT.
// Source: design/tokens/ninety.tokens.json
// Regenerate: python3 design/tokens/generate.py


import SwiftUI
import UIKit

/// Ninety design system tokens.
///
/// Every colour, size, radius and duration in the app comes from here.
/// SwiftLint enforces it (`no_hardcoded_colour`, `no_magic_corner_radius`).
public enum Ninety {}

// MARK: - Colour

public extension Ninety {
    /// Semantic colours. Each resolves per colour scheme automatically.
    enum Colour {
        /// The pitch under floodlight. Deep, warm-shifted green — never neutral black.
        public static let canvas = Color(light: 0xF1F4EC, dark: 0x08210F)
        /// Cards and rows: the pitch one mow-stripe lighter.
        public static let surface = Color(light: 0xFFFFFF, dark: 0x0C2B18)
        /// Sheets and anything lifted off the pitch.
        public static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x11351E)
        /// Inset wells: chart grounds, the tab bar, input fields.
        public static let surfaceSunken = Color(light: 0xE3EADE, dark: 0x04120B)
        /// Faint chalk. Dividers inside a panel.
        public static let stroke = Color(light: 0xCBD9CD, dark: 0x2A4A35)
        /// Chalk. Panel edges and the mastheads, drawn at 2px.
        public static let strokeStrong = Color(light: 0x2E5A3C, dark: 0xB9CFC0)
        /// Chalk white, very slightly warm. All data and headlines.
        public static let textPrimary = Color(light: 0x0B2416, dark: 0xF2EFE6)
        /// Supporting copy and row subtitles.
        public static let textSecondary = Color(light: 0x3D5C48, dark: 0xB6CCBC)
        /// Condensed micro-labels — the broadcast caption voice.
        public static let textTertiary = Color(light: 0x4A6B55, dark: 0x9FBBA8)
        /// Placeholder and unavailable.
        public static let textDisabled = Color(light: 0x7A9184, dark: 0x628070)
        /// On gold: the KICK OFF and GIVE THE DECISION buttons.
        public static let textInverse = Color(light: 0xFFFFFF, dark: 0x08210F)
        /// Division gold. Tier identity, the target band, the primary action. Reserved — never decoration.
        public static let accent = Color(light: 0x8A6410, dark: 0xE8B54A)
        /// Gold, pressed.
        public static let accentPressed = Color(light: 0x6F4F0B, dark: 0xD2A139)
        /// Gold at page scale: the tinted leader row and division strip.
        public static let accentSubtle = Color(light: 0xF5EBD4, dark: 0x1A2E1A)
        /// Confirmations and sync. Never used to reward faster loss (S3).
        public static let positive = Color(light: 0x1B7A4B, dark: 0x7FD6A0)
        /// §10 interventions only — floor, rate ceiling, goal-weight refusal. Shares gold's hue deliberately: on this surface a safety notice reads as the app's own voice, not an alarm.
        public static let safety = Color(light: 0x8A6410, dark: 0xE8B54A)
        /// Destructive confirmation only. There is still no error colour for logged intake.
        public static let critical = Color(light: 0xA6321C, dark: 0xE0705A)
        /// The trend line. Primary data wears the primary ink, not the accent.
        public static let chartLine = Color(light: 0x0B2416, dark: 0xF2EFE6)
        /// The dashed four-week mark.
        public static let chartBaseline = Color(light: 0x5E7A68, dark: 0x8FA894)
        /// Goal-corridor fill — the pace you signed up for.
        public static let chartBand = Color(light: 0xE4EFD8, dark: 0x2E3A1E)
        /// Mow stripes and grid.
        public static let chartGrid = Color(light: 0xDCE7DD, dark: 0x1B3A26)
        /// Raw dailies, behind the off-by-default switch.
        public static let chartRaw = Color(light: 0x93A897, dark: 0x4A6B55)
    }
}

// MARK: - Tier

/// The five-rung ladder.
///
/// `chevrons` is the PRIMARY signal and `colour` is secondary (ADR 0012):
/// Silver and Platinum are near-identical metals, and roughly 1 in 12 men
/// have some colour vision deficiency. Both are derived from this single
/// enum so they can never disagree.
public enum Tier: Int, CaseIterable, Comparable, Sendable {
    /// 1 chevron. Starting out.
    case bronze = 1
    /// 2 chevrons.
    case silver = 2
    /// 3 chevrons. The division the mockups sit in.
    case gold = 3
    /// 4 chevrons.
    case platinum = 4
    /// 5 chevrons.
    case diamond = 5

    /// Number of chevrons in the badge. The primary tier signal.
    public var chevrons: Int { rawValue }

    public var colour: Color {
        switch self {
        case .bronze: Color(light: 0x7E4A1E, dark: 0xC07A44)
        case .silver: Color(light: 0x5C6B62, dark: 0xBFC7C2)
        case .gold: Color(light: 0x8A6410, dark: 0xE8B54A)
        case .platinum: Color(light: 0x5F7168, dark: 0xDCE6E2)
        case .diamond: Color(light: 0x1B7A70, dark: 0x8FE0D6)
        }
    }

    public var displayName: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        case .diamond: "Diamond"
        }
    }

    /// VoiceOver label. States the position explicitly so the ladder is
    /// legible without seeing the badge at all.
    public var accessibilityLabel: String {
        "\(displayName). Tier \(rawValue) of \(Tier.allCases.count)."
    }

    public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Typography

public extension Ninety {
    /// Type scale. Every style is bound to an iOS text style so Dynamic
    /// Type works for free — required, not optional, in a health app.
    enum TypeStyle: String, CaseIterable, Sendable {
        case display
        case title1
        case title2
        case title3
        case headline
        case body
        case callout
        case subhead
        case footnote
        case caption
        case label
        case masthead
        case button
        case metricXL
        case metricL
        case metricM
        case metricS

        /// Base point size at the Large (default) content size.
        public var size: CGFloat {
            switch self {
            case .display: 40
            case .title1: 28
            case .title2: 22
            case .title3: 20
            case .headline: 17
            case .body: 17
            case .callout: 16
            case .subhead: 15
            case .footnote: 13
            case .caption: 12
            case .label: 11
            case .masthead: 21
            case .button: 17
            case .metricXL: 56
            case .metricL: 40
            case .metricM: 28
            case .metricS: 17
            }
        }

        /// Informational only — the weight is baked into `fontName`.
        /// Do NOT apply this with `.weight()` on top of the custom face:
        /// iOS would synthesise a bolder outline over a weight the family
        /// already ships properly drawn.
        public var weight: Font.Weight {
            switch self {
            case .display: .semibold
            case .title1: .semibold
            case .title2: .semibold
            case .title3: .semibold
            case .headline: .semibold
            case .body: .regular
            case .callout: .regular
            case .subhead: .regular
            case .footnote: .regular
            case .caption: .regular
            case .label: .semibold
            case .masthead: .regular
            case .button: .regular
            case .metricXL: .semibold
            case .metricL: .semibold
            case .metricM: .semibold
            case .metricS: .semibold
            }
        }

        /// The iOS text style this scales against. Bound per style so
        /// Dynamic Type ramps sensibly rather than uniformly.
        public var textStyle: UIFont.TextStyle {
            switch self {
            case .display: .largeTitle
            case .title1: .title1
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subhead: .subheadline
            case .footnote: .footnote
            case .caption: .caption1
            case .label: .caption2
            case .masthead: .title3
            case .button: .headline
            case .metricXL: .largeTitle
            case .metricL: .title1
            case .metricM: .title2
            case .metricS: .headline
            }
        }

        /// Digits line up in columns and do not jitter as values change.
        /// Essential anywhere a number updates in place — calories
        /// remaining, the composite score, kcal on a food row.
        public var usesTabularFigures: Bool {
            switch self { case .metricXL, .metricL, .metricM, .metricS: true; default: false }
        }

        /// The bundled face, by PostScript name. The static builds
        /// have inconsistent *family* names; PostScript names are exact,
        /// and an exact name is the difference between the Matchday world
        /// and a silent fallback to San Francisco.
        public var fontName: String {
            switch self {
            case .display: "Saira-SemiBold"
            case .title1: "Saira-SemiBold"
            case .title2: "Saira-SemiBold"
            case .title3: "Saira-SemiBold"
            case .headline: "Saira-SemiBold"
            case .body: "Saira-Regular"
            case .callout: "Saira-Regular"
            case .subhead: "Saira-Regular"
            case .footnote: "Saira-Regular"
            case .caption: "Saira-Regular"
            case .label: "SairaCondensed-SemiBold"
            case .masthead: "SairaCondensed-ExtraBold"
            case .button: "SairaCondensed-ExtraBold"
            case .metricXL: "Saira-SemiBold"
            case .metricL: "Saira-SemiBold"
            case .metricM: "Saira-SemiBold"
            case .metricS: "Saira-SemiBold"
            }
        }

        /// The SwiftUI text style the face scales against.
        /// `Font.custom(_:size:relativeTo:)` is what makes a bundled face
        /// honour Dynamic Type — a plain `Font.custom(_:size:)` does not
        /// scale at all, and that failure is invisible until someone with
        /// a larger reading size opens the app (ADR 0015).
        public var scalesAgainst: Font.TextStyle {
            switch self {
            case .display: .largeTitle
            case .title1: .title
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subhead: .subheadline
            case .footnote: .footnote
            case .caption: .caption
            case .label: .caption2
            case .masthead: .title3
            case .button: .headline
            case .metricXL: .largeTitle
            case .metricL: .title
            case .metricM: .title2
            case .metricS: .headline
            }
        }

        public var font: Font {
            let base = Font.custom(fontName, size: size, relativeTo: scalesAgainst)
            return usesTabularFigures ? base.monospacedDigit() : base
        }

        public var lineHeight: CGFloat {
            switch self {
            case .display: 44
            case .title1: 34
            case .title2: 28
            case .title3: 25
            case .headline: 22
            case .body: 22
            case .callout: 21
            case .subhead: 20
            case .footnote: 18
            case .caption: 16
            case .label: 14
            case .masthead: 26
            case .button: 22
            case .metricXL: 58
            case .metricL: 44
            case .metricM: 32
            case .metricS: 22
            }
        }

        public var tracking: CGFloat {
            switch self {
            case .display: -0.5
            case .title1: -0.3
            case .title2: -0.2
            case .title3: 0
            case .headline: 0
            case .body: 0
            case .callout: 0
            case .subhead: 0
            case .footnote: 0
            case .caption: 0
            case .label: 1.6
            case .masthead: 2.5
            case .button: 2.5
            case .metricXL: -1.5
            case .metricL: -0.8
            case .metricM: -0.3
            case .metricS: 0
            }
        }

        /// Labels are set in caps; nothing else is.
        public var isUppercased: Bool {
            switch self { case .label, .masthead, .button: true; default: false }
        }
    }
}

public extension View {
    /// Apply a Ninety type style: face, Dynamic Type scaling, tracking and casing.
    ///
    /// Casing is applied here rather than in the string so the copy deck and
    /// the accessibility label both keep their sentence case — VoiceOver
    /// spells out an all-caps string letter by letter.
    func ninetyType(_ style: Ninety.TypeStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .textCase(style.isUppercased ? .uppercase : nil)
    }
}

// MARK: - Space

public extension Ninety {
    /// Spacing scale. 4-point grid.
    enum Space {

        public static let hair: CGFloat = 2

        public static let xs: CGFloat = 4

        public static let sm: CGFloat = 8

        public static let md: CGFloat = 12
        /// Default screen gutter and card padding.
        public static let lg: CGFloat = 16

        public static let xl: CGFloat = 20

        public static let xxl: CGFloat = 24

        public static let xxxl: CGFloat = 32

        public static let huge: CGFloat = 48
        /// Above the hero metric on the rank screen. Whitespace is the drama budget.
        public static let vast: CGFloat = 64
    }
}

// MARK: - Radius

public extension Ninety {
    /// Corner radii. Always paired with the continuous curve.
    enum Radius {

        public static let none: CGFloat = 0
        /// Chips, confidence pills, small controls.
        public static let sm: CGFloat = 8
        /// Inputs, food rows.
        public static let md: CGFloat = 12
        /// Cards, stat cards, chart containers.
        public static let lg: CGFloat = 16
        /// Sheets, the hero rank card.
        public static let xl: CGFloat = 24
        /// Pills and the primary button.
        public static let full: CGFloat = 999
    }
}

// MARK: - Border

public extension Ninety {
    /// Stroke widths.
    enum Border {

        public static let hairline: CGFloat = 1
        /// Keyboard/VoiceOver focus ring. Always visible, never removed.
        public static let focus: CGFloat = 2
    }
}

// MARK: - Motion

public extension Ninety {
    /// MOTION BUDGET: nothing but `.reveal` may exceed 0.3s.
    /// Always respect Reduce Motion — use `Ninety.Motion.animation(_:reduceMotion:)`.
    enum Motion {
        /// Press feedback, chip toggle.
        public static let instant: Double = 0.12
        /// Row insert, toast in.
        public static let fast: Double = 0.2
        /// Sheet present, tab change. The ceiling for everything routine.
        public static let base: Double = 0.3
        /// THE RANK REVEAL, and nothing else. This is the retention moment (§2.2) and the only place the app is allowed to be theatrical.
        public static let reveal: Double = 0.9

        public static let standardSpring: Animation = .spring(response: 0.35, dampingFraction: 0.86)
        public static let revealSpring: Animation = .spring(response: 0.62, dampingFraction: 0.70)

        /// Returns nil when Reduce Motion is on, so `withAnimation(nil)`
        /// applies the change instantly instead of animating it.
        public static func animation(
            _ animation: Animation,
            reduceMotion: Bool
        ) -> Animation? {
            reduceMotion ? nil : animation
        }
    }
}

// MARK: - Helpers

public extension View {
    /// Rounded rect with the iOS continuous curve. Using this instead of
    /// `.cornerRadius(_:)` is why `no_magic_corner_radius` can be a lint rule.
    func ninetyCorners(_ radius: CGFloat) -> some View {
        clipShape(.rect(cornerRadius: radius, style: .continuous))
    }

    /// Card surface. Dark mode gets a lightness step plus a hairline;
    /// light mode gets a shadow. Shadows do not read on near-black, so the
    /// two schemes need genuinely different treatments — this picks for you.
    func ninetyCard(radius: CGFloat = Ninety.Radius.lg) -> some View {
        modifier(NinetyCardStyle(radius: radius))
    }
}

public struct NinetyCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let radius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(Ninety.Colour.surface)
            .ninetyCorners(radius)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        Ninety.Colour.stroke,
                        lineWidth: scheme == .dark ? Ninety.Border.hairline : 0
                    )
            )
            .shadow(
                color: .black.opacity(scheme == .dark ? 0 : 0.16),
                radius: 3,
                y: 1
            )
    }
}

// MARK: - Colour scheme resolution

private extension Color {
    /// Resolve a light/dark pair at render time so a single token works in both.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
