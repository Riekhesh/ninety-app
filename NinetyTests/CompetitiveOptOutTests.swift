import Foundation
import Testing
@testable import Ninety

/// §10 S6 · the competitive opt-out, and the half of it that is easy to lose.
///
/// The requirement has two columns. The left one — tiers, ranks, scores,
/// streaks, leaderboards — is the one everybody implements. The right one is the
/// one that makes it an opt-out rather than a threat: *"someone who turns
/// competition off must still have a fully useful food and weight tracker, or
/// they will simply delete the app, which is the outcome this requirement exists
/// to prevent."*
///
/// So every test below is run against **both** states of the switch, and the
/// right-hand column is asserted to be identical in each.
@MainActor
@Suite("Competitive opt-out (S6)")
struct CompetitiveOptOutTests {
    private static let on = CompetitiveFeatures(isOptedOut: true)
    private static let off = CompetitiveFeatures(isOptedOut: false)

    /// `test_opt_out_hides_rank_tab`
    @Test("opting out removes The Table")
    func optOutHidesRankTab() {
        #expect(Self.off.showsTheTable)
        #expect(!Self.on.showsTheTable)

        #expect(Self.off.destinations == Destination.allCases)
        #expect(!Self.on.destinations.contains(.theTable))
        #expect(Self.on.destinations == [.matchday, .theRun])
    }

    /// `test_opt_out_stops_score_computation`
    ///
    /// Nothing computes a score until Phase 2. The gate exists before the thing
    /// it gates on purpose: the engine reads `computesWeeklyScore`, so the
    /// requirement is already satisfied on the day the maths arrives rather than
    /// being remembered then.
    @Test("opting out stops the weekly score being computed")
    func optOutStopsScoreComputation() {
        #expect(Self.off.computesWeeklyScore)
        #expect(!Self.on.computesWeeklyScore)

        #expect(!Self.on.showsTierBadges)
        #expect(!Self.on.showsStreaks)
        #expect(!Self.on.sendsRankNotifications)
        #expect(!Self.on.showsFriendLeaderboards)
    }

    /// `test_opt_out_preserves_food_logging`
    @Test("opting out leaves logging exactly as it was")
    func optOutPreservesFoodLogging() {
        #expect(Self.on.allowsFoodLogging)
        #expect(Self.on.allowsFoodLogging == Self.off.allowsFoodLogging)
        #expect(Self.on.showsTodayDashboard)
        #expect(Self.on.showsTodayDashboard == Self.off.showsTodayDashboard)
    }

    /// `test_opt_out_preserves_weight_trend_and_healthkit_sync`
    @Test("opting out leaves the weight trend, Apple Health and data rights alone")
    func optOutPreservesWeightTrendAndHealthKitSync() {
        #expect(Self.on.allowsWeightTrend)
        #expect(Self.on.allowsHealthKitSync)
        #expect(Self.on.allowsExportAndDeletion)

        #expect(Self.on.allowsWeightTrend == Self.off.allowsWeightTrend)
        #expect(Self.on.allowsHealthKitSync == Self.off.allowsHealthKitSync)
        #expect(Self.on.allowsExportAndDeletion == Self.off.allowsExportAndDeletion)
    }

    /// `test_opt_out_is_reachable_in_two_taps`
    ///
    /// One tap on Matchday's masthead control, one on the switch. The thing that
    /// can regress is the ordering — a later epic adding a section above the
    /// opt-out would push it below the fold without changing the tap count — so
    /// the assertion is that it is the panel you land on.
    @Test("the opt-out is two taps from Matchday, and the first panel in Settings")
    func optOutIsReachableInTwoTaps() {
        #expect(SettingsSection.tapsToCompetitiveOptOut == 2)
        #expect(SettingsSection.allCases.first == .competitive)
    }

    /// `test_opt_out_is_reversible_and_preserves_history`
    ///
    /// Reversible in both directions, and it touches nothing but the flag: no
    /// score, log or weight is deleted by turning competition off, which is what
    /// makes turning it back on a restoration rather than a fresh start.
    @Test("the switch goes both ways and keeps everything")
    func optOutIsReversibleAndPreservesHistory() throws {
        let user = UUID()
        let profile = Profile(id: user)
        let profiles = MockProfileRepository(profile: profile)
        let weights = MockWeightRepository()
        try weights.record(kg: 78.4, at: .now, source: .manual)

        #expect(!CompetitiveFeatures(profiles: profiles).isOptedOut)

        profile.competitiveOptOut = true
        try profiles.save(profile)
        #expect(CompetitiveFeatures(profiles: profiles).isOptedOut)
        #expect(weights.recent(limit: 10).count == 1, "opting out is not a deletion")

        profile.competitiveOptOut = false
        try profiles.save(profile)
        #expect(!CompetitiveFeatures(profiles: profiles).isOptedOut)
        #expect(weights.recent(limit: 10).count == 1)
    }

    /// The default is off. An app that ships opted out of its own differentiator
    /// has answered a question nobody asked.
    @Test("competition is on until somebody turns it off")
    func defaultsToCompeting() {
        #expect(!Profile(id: UUID()).competitiveOptOut)
    }
}
