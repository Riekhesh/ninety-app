import Foundation

/// The whole app, as three places.
///
/// §1.6 caps Ninety at three tabs and the cap is the point: every screen the
/// product needs has to justify itself against one of these three, which is
/// what stops a tracker growing a settings-shaped fourth tab.
///
/// **Sub On is deliberately absent.** Logging a meal is an *action*, not a
/// place — it has a beginning and an end, and it returns you to where you
/// started. Apple's rule is that tabs are sections; a centre "+" tab is the
/// most common way an iOS app announces it was designed as a website. It
/// presents as a sheet from Matchday instead (ADR 0015 records the same
/// reasoning for type).
enum Destination: String, CaseIterable, Identifiable, Sendable {
    /// The daily driver: the band, the pitch, the team sheet.
    case matchday

    /// Weight and trend against the pace chosen at onboarding.
    case theRun

    /// Rank as a league table. The hero screen, from Phase 2.
    case theTable

    var id: String { rawValue }

    /// Tab label and masthead. Sentence case — `ninetyType` handles the caps,
    /// so VoiceOver still reads a word rather than spelling it out.
    var title: String {
        switch self {
        case .matchday: "Matchday"
        case .theRun: "The Run"
        case .theTable: "The Table"
        }
    }

    /// SF Symbols carry the tab bar. The authored chalk glyphs belong inside
    /// the content, where they are drawn at a size that can hold a 2pt line;
    /// a tab bar has to survive every size class, the sidebar layout and
    /// accessibility sizes, and the system set is what does that reliably.
    var symbol: String {
        switch self {
        case .matchday: "soccerball"
        case .theRun: "chart.xyaxis.line"
        case .theTable: "list.number"
        }
    }
}
