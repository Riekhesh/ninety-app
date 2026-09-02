import Testing
@testable import RankingEngine

@Suite("Weighting")
struct WeightingTests {
    @Test("the v1 weights sum to 1")
    func v1IsNormalised() {
        #expect(Weighting.v1.isNormalised)
    }

    @Test("consistency outweighs progress (ADR 0008)")
    func consistencyLeads() {
        #expect(Weighting.v1.consistency > Weighting.v1.progress)
        #expect(Weighting.v1.consistency == 0.50)
    }

    @Test("a weighting that does not sum to 1 is rejected")
    func unnormalisedIsCaught() {
        let bad = Weighting(consistency: 0.5, adherence: 0.5, progress: 0.5)
        #expect(!bad.isNormalised)
    }
}
