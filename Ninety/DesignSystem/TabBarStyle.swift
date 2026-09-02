import SwiftUI
import UIKit

/// Matchday's tab bar, expressed through the layer UIKit leaves open.
///
/// The bar itself stays the system tab bar. It gets scroll-to-top, the
/// minimise-on-scroll behaviour, the sidebar adaptation on iPad, VoiceOver's
/// tab semantics and every future presentation Apple adds — none of which a
/// hand-rolled bar would have, and all of which a user notices the absence of.
///
/// What is ours: the sunken ground the artboards draw it on, gold for the
/// selected tab, and the broadcast face on the labels — scaled through
/// `UIFontMetrics` so a custom face still follows the reading size.
@MainActor
enum TabBarStyle {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Ninety.Colour.surfaceSunken)
        appearance.shadowColor = UIColor(Ninety.Colour.strokeStrong)

        style(appearance.stackedLayoutAppearance)
        style(appearance.inlineLayoutAppearance)
        style(appearance.compactInlineLayoutAppearance)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private static func style(_ item: UITabBarItemAppearance) {
        item.normal.iconColor = UIColor(Ninety.Colour.textTertiary)
        item.normal.titleTextAttributes = attributes(Ninety.Colour.textTertiary)
        item.selected.iconColor = UIColor(Ninety.Colour.accent)
        item.selected.titleTextAttributes = attributes(Ninety.Colour.accent)
    }

    private static func attributes(_ colour: Color) -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor(colour),]
        let style = Ninety.TypeStyle.label
        // Falls through to the system font rather than trapping: a tab label in
        // San Francisco is a cosmetic regression, and BrandFont.verify() has
        // already logged the real cause by the time anyone sees it.
        if let face = UIFont(name: style.fontName, size: style.size) {
            result[.font] = UIFontMetrics(forTextStyle: style.textStyle).scaledFont(for: face)
        }
        return result
    }
}
