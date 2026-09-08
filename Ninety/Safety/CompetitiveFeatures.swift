import Foundation

/// §10 S6 · one switch, and what it is and is not allowed to turn off.
///
/// The rule is easy to state and easy to erode: a visible switch disables
/// **every** competitive and social feature **without** disabling the app's core
/// usefulness. §10 is blunt about why the second half is the important one —
/// *"an opt-out that leaves a crippled app is not an opt-out, it is a threat."*
/// Someone who turns competition off and finds a hollow tracker deletes the app,
/// which is the outcome the requirement exists to prevent.
///
/// **Why this is a type rather than an `if` at each call site.** The erosion this
/// guards against is not somebody deleting the switch; it is a later epic adding
/// a surface and reading the flag one extra time. Put the whole rule in one
/// value and both halves become visible in one diff: the left column is derived
/// from the flag, and the right column is not derived from anything, so a change
/// that starts gating logging on it has to edit a line that says in English why
/// it must not.
struct CompetitiveFeatures: Equatable, Sendable {
    let isOptedOut: Bool

    init(isOptedOut: Bool) {
        self.isOptedOut = isOptedOut
    }

    @MainActor
    init(profiles: any ProfileRepositoryProtocol) {
        self.init(isOptedOut: profiles.isCompetitiveOptOutEnabled())
    }

    // MARK: - Off when the switch is on

    /// The Table. Phase 1 has no rank to show, but the tab is the competitive
    /// surface and it goes away now rather than being remembered in Phase 2.
    var showsTheTable: Bool { !isOptedOut }

    /// The weekly composite. Nothing computes one until Phase 2; the engine
    /// reads this rather than the raw flag, so the gate exists before the thing
    /// it gates.
    var computesWeeklyScore: Bool { !isOptedOut }

    var showsTierBadges: Bool { !isOptedOut }
    var sendsRankNotifications: Bool { !isOptedOut }
    var showsStreaks: Bool { !isOptedOut }

    /// Phase 4. Listed now because the table in §10 lists it, and a feature that
    /// arrives without its opt-out is how the opt-out stops being total.
    var showsFriendLeaderboards: Bool { !isOptedOut }

    // MARK: - On regardless. This is the half that makes it an opt-out.

    /// Unconditional, and the constants are the point.
    ///
    /// Each of these could be written as `true` once and shared. They are spelled
    /// out separately because §10's right-hand column is a list of promises, and
    /// a promise that is not written down individually is one that gets dropped
    /// individually. `CompetitiveOptOutTests` asserts every one of them under
    /// both states of the switch.
    var allowsFoodLogging: Bool { true }
    var allowsWeightTrend: Bool { true }
    var allowsHealthKitSync: Bool { true }
    var showsTodayDashboard: Bool { true }
    var allowsExportAndDeletion: Bool { true }

    /// The tabs the shell shows. Two taps to reach the switch is S6's other
    /// requirement, and it is satisfied by Matchday's masthead control, not by
    /// this.
    var destinations: [Destination] {
        Destination.allCases.filter { $0 != .theTable || showsTheTable }
    }
}
