import Foundation
import SwiftData
import Testing
@testable import Ninety

/// Article 9 consent, and the one property that makes it consent at all.
///
/// `docs/safety/safety-requirements.md` names the test this suite exists for:
/// `test_health_consent_is_separate_from_terms_acceptance`. It is
/// `healthConsentIsSeparateFromTermsAcceptance` below, and the rest of the file
/// is the ways that separation could quietly stop being true.
///
/// A real in-memory `ModelContainer` rather than the mock, because the thing
/// being asserted is that two *columns* move independently — a mock that stores
/// a struct would pass whatever the store actually did.
@MainActor
@Suite("Consent (Article 9)")
struct ConsentTests {
    private func recorder() throws -> (ConsentRecorder, UUID) {
        let container = try ModelContainer.ninety(inMemory: true)
        let user = UUID()
        let profiles = SwiftDataProfileRepository(context: ModelContext(container), userID: user)
        return (ConsentRecorder(profiles: profiles, userID: user), user)
    }

    /// `test_health_consent_is_separate_from_terms_acceptance`.
    @Test("accepting the terms consents to nothing about health data, and the reverse")
    func healthConsentIsSeparateFromTermsAcceptance() throws {
        let (consent, _) = try recorder()

        let afterTerms = try consent.acceptTerms(at: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(afterTerms.termsAcceptedAt != nil)
        #expect(afterTerms.healthConsentAt == nil, "a ToS checkbox is not explicit consent to process health data")
        #expect(consent.status.allowsHealthProcessing == false)

        let afterConsent = try consent.consentToHealthData(at: Date(timeIntervalSince1970: 1_800_000_060))
        #expect(afterConsent.healthConsentAt != nil)
        #expect(
            afterConsent.termsAcceptedAt == Date(timeIntervalSince1970: 1_800_000_000),
            "recording health consent must not re-stamp the terms"
        )
        #expect(consent.status.allowsHealthProcessing)
    }

    @Test("health data can be consented to without the terms, which is what proves they are two decisions")
    func healthConsentDoesNotRequireTermsToBeRecorded() throws {
        let (consent, _) = try recorder()

        let profile = try consent.consentToHealthData(at: .now)

        #expect(profile.healthConsentAt != nil)
        #expect(profile.termsAcceptedAt == nil)
        #expect(consent.status == .partial(terms: false, healthData: true))
        // One of the two is not both, and the app must not start on it.
        #expect(consent.status.allowsHealthProcessing == false)
    }

    @Test("the consent timestamp is persisted on the profile, not held in memory")
    func consentSurvivesTheWrite() throws {
        let container = try ModelContainer.ninety(inMemory: true)
        let context = ModelContext(container)
        let user = UUID()
        let moment = Date(timeIntervalSince1970: 1_800_000_000)

        let consent = ConsentRecorder(
            profiles: SwiftDataProfileRepository(context: context, userID: user),
            userID: user
        )
        try consent.acceptTerms(at: moment)
        try consent.consentToHealthData(at: moment)

        // Read back through a second repository over the same store, so this
        // is the store answering rather than the object still being in hand.
        let reread = SwiftDataProfileRepository(context: context, userID: user).current()
        #expect(reread?.id == user, "the row is keyed on the auth user id, which is what RLS compares against")
        #expect(reread?.termsAcceptedAt == moment)
        #expect(reread?.healthConsentAt == moment)
    }

    @Test("withdrawing one consent leaves the other exactly where it was")
    func withdrawalIsAlsoTwoDecisions() throws {
        let (consent, _) = try recorder()
        let moment = Date(timeIntervalSince1970: 1_800_000_000)

        try consent.acceptTerms(at: moment)
        try consent.consentToHealthData(at: moment)
        #expect(consent.status == .complete)

        let withdrawn = try consent.withdrawHealthConsent()
        #expect(withdrawn?.healthConsentAt == nil)
        #expect(withdrawn?.termsAcceptedAt == moment, "withdrawing health consent is not withdrawing from the terms")
        #expect(consent.status == .partial(terms: true, healthData: false))
    }

    @Test("withdrawing consent does not delete anything")
    func withdrawalIsNotErasure() throws {
        let container = try ModelContainer.ninety(inMemory: true)
        let context = ModelContext(container)
        let user = UUID()
        let repositories = Repositories.live(context: context, userID: user)
        let consent = ConsentRecorder(profiles: repositories.profile, userID: user)

        try consent.acceptTerms(at: .now)
        try consent.consentToHealthData(at: .now)
        try repositories.weight.record(kg: 78.4, at: .now, source: .manual)

        try consent.withdrawHealthConsent()

        #expect(repositories.weight.recent(limit: 7).count == 1, "erasure is a separate right with a separate path")
        #expect(repositories.profile.current() != nil)
    }

    @Test("the four consent states are the four that exist")
    func statusCoversEveryCombination() {
        let moment = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(ConsentStatus(termsAcceptedAt: nil, healthConsentAt: nil) == .none)
        #expect(ConsentStatus(termsAcceptedAt: moment, healthConsentAt: moment) == .complete)

        let termsOnly = ConsentStatus(termsAcceptedAt: moment, healthConsentAt: nil)
        let healthOnly = ConsentStatus(termsAcceptedAt: nil, healthConsentAt: moment)
        #expect(termsOnly == .partial(terms: true, healthData: false))
        #expect(healthOnly == .partial(terms: false, healthData: true))

        // Only one of the four opens the gate.
        let statuses = [
            ConsentStatus.none,
            .partial(terms: true, healthData: false),
            .partial(terms: false, healthData: true),
            .complete,
        ]
        #expect(statuses.filter(\.allowsHealthProcessing) == [.complete])
    }

    @Test("a first sign-in creates the profile row the consent is written on")
    func consentCreatesTheProfileRow() throws {
        let (consent, user) = try recorder()
        #expect(consent.status == .none)

        let profile = try consent.acceptTerms(at: .now)

        #expect(profile.id == user)
        // Everything the §10 gates need is still unanswered; that is P1-D's job.
        #expect(profile.dob == nil)
        #expect(profile.heightCm == nil)
        #expect(profile.calibrationCompletedAt == nil)
    }
}
