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
    /// Every distinct PostScript name the type scale asks for. Fewer than the
    /// number of files bundled: one face serves many styles, and a family is
    /// shipped whole so a new style can pick a weight without a new download.
    static var used: [String] {
        Set(Ninety.TypeStyle.allCases.map(\.fontName)).sorted()
    }

    /// Every face declared in `UIAppFonts`, by the name iOS will know it by.
    ///
    /// The files are named after their PostScript names — `Saira-Regular.ttf`
    /// registers as `Saira-Regular` — so dropping the extension gives the
    /// lookup name. `scripts/check_bundle.py` holds the other half of that
    /// guarantee: every declared file exists, and every shipped file is
    /// declared.
    static var declared: [String] {
        let files = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String] ?? []
        return files.map { ($0 as NSString).deletingPathExtension }.sorted()
    }

    /// Declared faces iOS could not resolve. Empty is the healthy answer.
    ///
    /// Checks everything shipped rather than only what the type scale currently
    /// uses: a face that fails to register is a broken build whether or not a
    /// style happens to reference it today, and finding out on the commit that
    /// starts using it is finding out late.
    static func missing() -> [String] {
        declared.filter { UIFont(name: $0, size: 12) == nil }
    }

    /// Called once at launch. Logs rather than traps: a wrong font is a bad
    /// build, not a reason to deny someone their food log for the day.
    static func verify() {
        let absent = missing()
        guard absent.isEmpty else {
            Log.design.error(
                """
                Faces did not register: \(absent.joined(separator: ", "), privacy: .public). \
                Text will silently fall back to San Francisco. Check UIAppFonts in Config/Info.plist \
                and that the .ttf is in the target's Copy Bundle Resources phase.
                """
            )
            return
        }
        Log.design.info(
            """
            Fonts ready: \(declared.count, privacy: .public) faces bundled, \
            \(used.count, privacy: .public) referenced by the type scale.
            """
        )
    }
}
