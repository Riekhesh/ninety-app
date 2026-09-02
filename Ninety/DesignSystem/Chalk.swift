import SwiftUI

/// Chalk: the 2pt line the whole world is drawn in.
///
/// Panels here are squared off, not rounded. `Ninety.Radius` still governs
/// anything that *is* rounded — chips, the primary button — but a pitch is
/// marked with straight lines and corners, and softening them is the single
/// fastest way to turn Matchday back into a generic card app.
enum Chalk {
    /// Panel edges and mastheads. The token's own note: "drawn at 2px".
    static let strong = Ninety.Border.focus

    /// Dividers inside a panel.
    static let faint = Ninety.Border.hairline
}

extension View {
    /// A chalk-marked panel: strong edge, sunken ground, square corners.
    func chalkPanel(padding: CGFloat = Ninety.Space.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ninety.Colour.surfaceSunken.opacity(0.5))
            .overlay {
                Rectangle()
                    .strokeBorder(Ninety.Colour.strokeStrong, lineWidth: Chalk.strong)
            }
    }

    /// The rule under a masthead, and between a panel's sections.
    func chalkRule(_ width: CGFloat = Chalk.strong) -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(Ninety.Colour.strokeStrong)
                .frame(height: width)
        }
    }
}
