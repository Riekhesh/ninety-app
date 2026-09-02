import SwiftUI
import UIKit

/// Verification for the two bundled faces.
///
/// A missing or misnamed `UIAppFonts` entry has no error path on iOS: the text
/// simply renders in San Francisco and the Matchday world quietly becomes a
/// generic SwiftUI app. Nothing crashes, nothing logs, and it survives review
/// because a screenshot of the wrong font still looks like a font.
///
/// `generate.py` guarantees the token file only ever names a `.ttf` that is in
/// the repo. This is the other half — that the file the repo has actually
/// reached the bundle and registered under the name the tokens promised.
@MainActor
enum BrandFont {
    /// Every distinct PostScript name the type scale asks for.
    static var required: [String] {
        Set(Ninety.TypeStyle.allCases.map(\.fontName)).sorted()
    }

    /// Names iOS could not resolve. Empty is the healthy answer.
    static func missing() -> [String] {
        required.filter { UIFont(name: $0, size: 12) == nil }
    }

    /// Called once at launch. Logs rather than traps: a wrong font is a bad
    /// build, not a reason to deny someone their food log for the day.
    static func verify() {
        let absent = missing()
        guard absent.isEmpty else {
            Log.design.error(
                """
                Bundled faces did not register: \(absent.joined(separator: ", "), privacy: .public). \
                Text will silently fall back to San Francisco. Check UIAppFonts in Config/Info.plist \
                and that the .ttf is in the target's Copy Bundle Resources phase.
                """
            )
            return
        }
        Log.design.info("Bundled faces registered: \(required.count, privacy: .public).")
    }
}
