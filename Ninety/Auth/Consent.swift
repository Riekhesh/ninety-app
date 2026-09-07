import Foundation

/// Article 9 consent, recorded as two decisions rather than one.
///
/// UK GDPR treats health data as special category data: it needs *explicit*
/// consent and a documented lawful basis, and `docs/safety/safety-requirements.md`
/// makes "explicit consent for health data, separate from ToS acceptance" a
/// Phase 1 requirement rather than Phase 3 polish.
///
/// **The separation is structural, not visual.** Two checkboxes on one screen
/// wired to one boolean is the same single decision with extra steps, and it
/// fails the same way: consent that was never given independently cannot be
/// withdrawn independently, and nobody can tell afterwards which of the two the
/// user actually agreed to. So there is no API here that records both. `accept`
/// and `consent` are separate calls writing separate columns, and the only
/// thing that reads them together is `status`, which reports rather than sets.
///
/// `test_health_consent_is_separate_from_terms_acceptance` in `ConsentTests` is
/// the named test the safety requirements ask for.
@MainActor
struct ConsentRecorder {
    let profiles: any ProfileRepositoryProtocol

    /// The user this consent belongs to. Needed because a first sign-in has no
    /// profile row yet and the consent screen is where one first appears — a
    /// row whose primary key is the auth user id, which is what
    /// `profiles_insert`'s `with check (id = auth.uid())` requires.
    let userID: UUID

    /// Terms of service. Says nothing about health data and must not.
    @discardableResult
    func acceptTerms(at moment: Date) throws -> Profile {
        let profile = existingOrNew()
        profile.termsAcceptedAt = moment
        return try profiles.save(profile)
    }

    /// Article 9 explicit consent to process health data. A separate action,
    /// separately timestamped, and never implied by the line above.
    @discardableResult
    func consentToHealthData(at moment: Date) throws -> Profile {
        let profile = existingOrNew()
        profile.healthConsentAt = moment
        return try profiles.save(profile)
    }

    /// Withdrawal, which has to be as easy as giving it or the consent was not
    /// freely given — hence a method per decision here too, and a screen where
    /// both are reversible rather than a one-way gate.
    ///
    /// Clears the timestamp and nothing else. It does not delete anything —
    /// erasure is a separate right with a separate path (Phase 3), and
    /// conflating the two would mean a user who wanted to stop processing lost
    /// their history for it.
    @discardableResult
    func withdrawHealthConsent() throws -> Profile? {
        guard let profile = profiles.current() else { return nil }
        profile.healthConsentAt = nil
        return try profiles.save(profile)
    }

    @discardableResult
    func withdrawTerms() throws -> Profile? {
        guard let profile = profiles.current() else { return nil }
        profile.termsAcceptedAt = nil
        return try profiles.save(profile)
    }

    var status: ConsentStatus {
        let profile = profiles.current()
        return ConsentStatus(
            termsAcceptedAt: profile?.termsAcceptedAt,
            healthConsentAt: profile?.healthConsentAt
        )
    }

    /// The profile row, created empty on first use.
    ///
    /// Everything the §10 gates need — date of birth, height, sex, rate — is
    /// still nil at this point and is filled in by onboarding (P1-D). The row
    /// exists early because consent has to be written *somewhere* the moment it
    /// is given, and a consent record held in memory until onboarding finishes
    /// is a consent record that a force-quit loses.
    private func existingOrNew() -> Profile {
        profiles.current() ?? Profile(id: userID)
    }
}

/// Which of the two decisions have been made.
///
/// Four cases rather than a pair of booleans, so a call site that forgets one
/// of them does not compile. `partial` is a real state and not an error: a user
/// can accept the terms, close the app, and come back — the screen resumes
/// where they left it rather than asking again for what they already gave.
enum ConsentStatus: Equatable, Sendable {
    /// Neither decision made. The state a fresh sign-in lands in.
    case none

    /// One given, the other not.
    case partial(terms: Bool, healthData: Bool)

    /// Both given, and the app can start.
    case complete

    init(termsAcceptedAt: Date?, healthConsentAt: Date?) {
        switch (termsAcceptedAt, healthConsentAt) {
        case (nil, nil): self = .none
        case (.some, .some): self = .complete
        default: self = .partial(terms: termsAcceptedAt != nil, healthData: healthConsentAt != nil)
        }
    }

    /// The one thing the shell asks. Deliberately not `!= .none`: accepting the
    /// terms alone is not consent to process health data, and an app that let
    /// a `partial` through would be doing Article 9 processing on the strength
    /// of a ToS checkbox.
    var allowsHealthProcessing: Bool { self == .complete }
}
