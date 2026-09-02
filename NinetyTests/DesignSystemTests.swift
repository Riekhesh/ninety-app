import Testing
import UIKit
@testable import Ninety

/// The design system's claims, as assertions.
///
/// Every one of these is a thing that fails *silently* on iOS: a missing font
/// falls back to San Francisco, a non-scaling font just looks small, and a
/// hard-coded colour looks right until someone opens the app in light mode.
@MainActor
@Suite("Design system")
struct DesignSystemTests {
    @Test("every bundled face the type scale asks for is registered")
    func facesRegister() {
        #expect(BrandFont.missing().isEmpty, "unregistered: \(BrandFont.missing())")
    }

    @Test("every type style scales with Dynamic Type")
    func typeScales() {
        let small = UITraitCollection(preferredContentSizeCategory: .small)
        let huge = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

        for style in Ninety.TypeStyle.allCases {
            let metrics = UIFontMetrics(forTextStyle: style.textStyle)
            let atSmall = metrics.scaledValue(for: style.size, compatibleWith: small)
            let atHuge = metrics.scaledValue(for: style.size, compatibleWith: huge)
            #expect(atHuge > atSmall, "\(style.rawValue) does not respond to the reading size")
        }
    }

    @Test("the metric styles use a face that actually has tabular figures")
    func metricsAreTabular() {
        for style in Ninety.TypeStyle.allCases where style.usesTabularFigures {
            #expect(
                style.fontName.hasPrefix("Saira-"),
                "\(style.rawValue) is on \(style.fontName), which is condensed and has no tnum"
            )
        }
    }

    @Test("the app is three tabs, and Sub On is not one of them")
    func threeTabs() {
        #expect(Destination.allCases.count == 3)
        #expect(!Destination.allCases.contains { $0.title.lowercased().contains("sub on") })
    }
}
