// GENERATED FILE — DO NOT EDIT.
// Source: design/tokens/notch.tokens.json
// Regenerate: python3 design/tokens/generate.py


import SwiftUI
import UIKit

/// Notch design system tokens.
///
/// Every colour, size, radius and duration in the app comes from here.
/// SwiftLint enforces it (`no_hardcoded_colour`, `no_magic_corner_radius`).
public enum Notch {}

// MARK: - Colour

public extension Notch {
    /// Semantic colours. Each resolves per colour scheme automatically.
    enum Colour {
        /// App background. Warm near-black.
        public static let canvas = Color(light: 0xFBFAF7, dark: 0x0C0B0A)
        /// Cards, rows, sheets.
        public static let surface = Color(light: 0xFFFFFF, dark: 0x171614)
        /// Elevated card on a card. Elevation on dark is a lightness step plus a hairline, never a shadow — shadows do not read on near-black.
        public static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x201E1B)
        /// Inset wells: chart backgrounds, input fields.
        public static let surfaceSunken = Color(light: 0xF2F0EB, dark: 0x070606)
        /// Hairline dividers and card edges.
        public static let stroke = Color(light: 0xE5E2DB, dark: 0x2C2A26)
        /// Input borders, focus-adjacent edges.
        public static let strokeStrong = Color(light: 0xCFCBC1, dark: 0x3D3A34)
        /// Warm white. 18.4:1 on canvas.
        public static let textPrimary = Color(light: 0x17150F, dark: 0xF6F4F1)
        /// Supporting copy, units, axis labels. 7.8:1 on canvas — AA at body size.
        public static let textSecondary = Color(light: 0x5C574D, dark: 0xA8A29A)
        /// Least-emphasis labels. 5.3:1 on canvas, 4.9:1 on surface — AA at body size on both. Deliberately NOT darker: a tertiary token that fails AA gets used for real content eventually. The first draft (#837D73) passed on canvas and failed on surface at 4.43:1 — generate.py caught it.
        public static let textTertiary = Color(light: 0x767063, dark: 0x8A8479)
        /// 3.0:1 — DISABLED CONTROLS ONLY. Never for content. WCAG exempts disabled controls; nothing else may use this.
        public static let textDisabled = Color(light: 0xADA79B, dark: 0x5A554D)
        /// On accent or tier-metal fills.
        public static let textInverse = Color(light: 0xFBFAF7, dark: 0x0C0B0A)
        /// The single accent. Cool blue on warm ground — a deliberate tension. 7.7:1 on canvas. Used for interactive affordance only, never for data.
        public static let accent = Color(light: 0x3B5BDB, dark: 0x7C9EFF)
        /// Pressed state.
        public static let accentPressed = Color(light: 0x2F4BC0, dark: 0x6B8BEE)
        /// Tinted surface behind selected rows and accent chips.
        public static let accentSubtle = Color(light: 0xEDF0FD, dark: 0x181B26)
        /// Jade. 'Inside your band', 'synced'. NEVER used to reward faster weight loss (safety §10 / rate ceiling).
        public static let positive = Color(light: 0x1E8A5F, dark: 0x4FBF8B)
        /// RESERVED for §10 safety interventions: calorie floor breach, unsafe goal weight, rate-of-loss ceiling. Named 'safety', not 'warning', so its scope cannot creep.
        public static let safety = Color(light: 0xA66A00, dark: 0xE2A03F)
        /// Destructive confirmation and hard safety blocks ONLY. There is deliberately no 'error' colour for logged intake — going over your band is not an error. See docs/design/00-design-principles.md.
        public static let critical = Color(light: 0xB4341A, dark: 0xE5674E)
        /// The weight trend line (the 7-day EWMA). Primary data gets the primary text colour, not the accent.
        public static let chartLine = Color(light: 0x17150F, dark: 0xF6F4F1)
        /// The 'you, four weeks ago' reference line. Present on every chart — the thesis rendered as a gridline.
        public static let chartBaseline = Color(light: 0x9A9488, dark: 0x6E6960)
        /// Target band fill. Wide, soft, unmistakably a range.
        public static let chartBand = Color(light: 0xE6F2EB, dark: 0x1E2A24)
        /// Barely-there gridlines.
        public static let chartGrid = Color(light: 0xEFEDE7, dark: 0x221F1C)
        /// Raw daily weight dots. Faint by design, off by default (§1.5).
        public static let chartRaw = Color(light: 0xCFCBC1, dark: 0x3D3A34)
    }
}

// MARK: - Tier

/// The five-rung ladder.
///
/// `notches` is the PRIMARY signal and `colour` is secondary (ADR 0012):
/// Silver and Platinum are near-identical metals, and roughly 1 in 12 men
/// have some colour vision deficiency. Both are derived from this single
/// enum so they can never disagree.
public enum Tier: Int, CaseIterable, Comparable, Sendable {
    /// 1 notch. Starting out.
    case bronze = 1
    /// 2 notches. Building habit.
    case silver = 2
    /// 3 notches. Consistent.
    case gold = 3
    /// 4 notches. Dialled in.
    case platinum = 4
    /// 5 notches. Exceptional.
    case diamond = 5

    /// Number of notches cut into the badge. The primary tier signal.
    public var notches: Int { rawValue }

    public var colour: Color {
        switch self {
        case .bronze: Color(light: 0x9A5F2E, dark: 0xC8834E)
        case .silver: Color(light: 0x6E747E, dark: 0xC3C7CE)
        case .gold: Color(light: 0xA8781A, dark: 0xE7B23C)
        case .platinum: Color(light: 0x7C8794, dark: 0xE3EAF0)
        case .diamond: Color(light: 0x1F7F96, dark: 0x8AE0F2)
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

public extension Notch {
    /// Type scale. Every style is bound to an iOS text style so Dynamic
    /// Type works for free — required, not optional, in a health app.
    enum TypeStyle: Sendable {
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
            case .metricXL: 56
            case .metricL: 40
            case .metricM: 28
            case .metricS: 17
            }
        }

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

        public var font: Font {
            let scaled = UIFontMetrics(forTextStyle: textStyle)
                .scaledValue(for: size)
            let base = Font.system(size: scaled, weight: weight, design: .default)
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
            case .label: 0.6
            case .metricXL: -1.5
            case .metricL: -0.8
            case .metricM: -0.3
            case .metricS: 0
            }
        }

        /// Labels are set in caps; nothing else is.
        public var isUppercased: Bool {
            switch self { case .label: true; default: false }
        }
    }
}

public extension View {
    /// Apply a Notch type style, including tracking and casing.
    func notchType(_ style: Notch.TypeStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

// MARK: - Space

public extension Notch {
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

public extension Notch {
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

public extension Notch {
    /// Stroke widths.
    enum Border {

        public static let hairline: CGFloat = 1
        /// Keyboard/VoiceOver focus ring. Always visible, never removed.
        public static let focus: CGFloat = 2
    }
}

// MARK: - Motion

public extension Notch {
    /// MOTION BUDGET: nothing but `.reveal` may exceed 0.3s.
    /// Always respect Reduce Motion — use `Notch.Motion.animation(_:reduceMotion:)`.
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
    func notchCorners(_ radius: CGFloat) -> some View {
        clipShape(.rect(cornerRadius: radius, style: .continuous))
    }

    /// Card surface. Dark mode gets a lightness step plus a hairline;
    /// light mode gets a shadow. Shadows do not read on near-black, so the
    /// two schemes need genuinely different treatments — this picks for you.
    func notchCard(radius: CGFloat = Notch.Radius.lg) -> some View {
        modifier(NotchCardStyle(radius: radius))
    }
}

public struct NotchCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let radius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(Notch.Colour.surface)
            .notchCorners(radius)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        Notch.Colour.stroke,
                        lineWidth: scheme == .dark ? Notch.Border.hairline : 0
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
