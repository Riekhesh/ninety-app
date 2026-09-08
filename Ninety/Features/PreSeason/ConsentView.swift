import SwiftUI

/// Two decisions, taken separately, on one screen.
///
/// The screen is one screen because two would be theatre — the point of the
/// Article 9 requirement is not that consent arrives on its own page, it is
/// that it is a *distinct, separately recorded action* that terms acceptance
/// does not imply and cannot carry. So each row writes its own column at its
/// own timestamp, either can be given without the other, and both are
/// reversible here rather than being a one-way gate.
///
/// `ConsentRecorder` is where that separation is enforced; this is where it is
/// visible. See ADR 0017.
struct ConsentView: View {
    let recorder: ConsentRecorder

    /// Called when both decisions are in. The shell re-reads the profile
    /// rather than trusting a flag passed up from here.
    var onContinue: () -> Void

    /// The way out for someone who does not want to consent. Signing out is a
    /// real answer to this screen and the screen has to offer one — a consent
    /// whose only alternative is force-quitting the app is not freely given.
    var onSignOut: () -> Void

    @State private var status: ConsentStatus = .none
    @State private var writeFailed = false

    var body: some View {
        Screen(title: PreSeasonCopy.consentMasthead, meta: PreSeasonCopy.consentMeta) {
            ScrollView {
                VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                    Text(PreSeasonCopy.consentTitle)
                        .ninetyType(.title2)

                    SwitchPanel(
                        heading: PreSeasonCopy.termsHeading,
                        explainer: PreSeasonCopy.termsBody,
                        action: PreSeasonCopy.termsAction,
                        isOn: status.hasTerms,
                        toggle: toggleTerms
                    )

                    SwitchPanel(
                        heading: PreSeasonCopy.healthHeading,
                        explainer: PreSeasonCopy.healthBody,
                        detail: PreSeasonCopy.healthDetail,
                        action: PreSeasonCopy.healthAction,
                        isOn: status.hasHealthConsent,
                        toggle: toggleHealthData
                    )

                    if writeFailed {
                        Text(PreSeasonCopy.consentDidNotSave)
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.safety)
                    }

                    Text(PreSeasonCopy.bothNeeded)
                        .ninetyType(.footnote)
                        .foregroundStyle(Ninety.Colour.textTertiary)

                    Button(PreSeasonCopy.kickOff, action: onContinue)
                        .buttonStyle(.primary)
                        .disabled(!status.allowsHealthProcessing)

                    Button(PreSeasonCopy.signOutInstead, action: onSignOut)
                        .ninetyType(.subhead)
                        .foregroundStyle(Ninety.Colour.textSecondary)
                }
                .padding(.bottom, Ninety.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear { status = recorder.status }
    }

    /// Two methods rather than one taking a flag, and they call two different
    /// recorder methods. The separation is meant to survive somebody editing
    /// this file in six months without reading the ADR.
    private func toggleTerms() {
        write { status.hasTerms ? try recorder.withdrawTerms() : try recorder.acceptTerms(at: .now) }
    }

    private func toggleHealthData() {
        write {
            status.hasHealthConsent
                ? try recorder.withdrawHealthConsent()
                : try recorder.consentToHealthData(at: .now)
        }
    }

    /// Reads the status back from the store rather than assuming the write
    /// landed. A consent record the app believes in and the database does not
    /// is the failure mode this whole screen exists to avoid.
    private func write(_ change: () throws -> Profile?) {
        do {
            _ = try change()
            writeFailed = false
        } catch {
            Log.auth.error("Consent did not persist: \(error.localizedDescription, privacy: .public)")
            writeFailed = true
        }
        status = recorder.status
    }
}

/// Which switch is on, for the two screens that show them.
///
/// `ConsentStatus` reports the pair as one value on purpose — the app's own
/// question is "may I process health data", which needs both — so the screens
/// that draw two switches need this to take it back apart. Internal rather than
/// private because Settings shows the same two switches as the consent screen,
/// and withdrawal has to be the same act as giving.
extension ConsentStatus {
    var hasTerms: Bool {
        switch self {
        case .complete: true
        case .partial(let terms, _): terms
        case .none: false
        }
    }

    var hasHealthConsent: Bool {
        switch self {
        case .complete: true
        case .partial(_, let healthData): healthData
        case .none: false
        }
    }
}

// See the note in SignInView: these build DEBUG-only mocks.
#if DEBUG
#Preview("Consent") {
    ConsentView(
        recorder: ConsentRecorder(profiles: MockProfileRepository(), userID: UUID()),
        onContinue: {},
        onSignOut: {}
    )
}

#Preview("Consent · accessibility 5") {
    ConsentView(
        recorder: ConsentRecorder(profiles: MockProfileRepository(), userID: UUID()),
        onContinue: {},
        onSignOut: {}
    )
    .dynamicTypeSize(.accessibility5)
}
#endif
