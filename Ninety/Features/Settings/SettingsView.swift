import SwiftUI

/// The screen P1-C left a hole where.
///
/// Four things land here together because they are the same obligation seen
/// from four directions, and each of them was unreachable until this screen
/// existed:
///
/// - **S6's competitive opt-out**, which §10 requires within two taps of
///   Matchday. It is the first panel, and `SettingsSection` asserts that.
/// - **S7's signposting**, which §10 requires to be *permanently* available.
/// - **Withdrawing Article 9 consent** (ADR 0017). Consent that cannot be
///   withdrawn as easily as it was given was not freely given, and until now the
///   only place either switch existed was the gate screen you never see again.
/// - **Signing out**, which was in the same position: offered once, on the
///   consent screen, as the honest alternative to consenting. Everywhere else,
///   signing out meant deleting the app.
///
/// Presented as a sheet rather than as a fourth tab. §1.6 caps Ninety at three
/// tabs and the cap is the point — *"what stops a tracker growing a
/// settings-shaped fourth tab"*.
struct SettingsView: View {
    let recorder: ConsentRecorder
    let profiles: any ProfileRepositoryProtocol

    /// Called after either consent switch moves. The shell re-reads the profile
    /// and, if health consent is gone, puts the consent gate back up — the app
    /// has no lawful basis to keep showing a tracker after that.
    var onConsentChanged: () -> Void

    /// Called after the opt-out moves, so the shell can drop or restore The
    /// Table without waiting for the sheet to be dismissed.
    var onCompetitiveChanged: () -> Void

    var onSignOut: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State private var status: ConsentStatus = .none
    @State private var isOptedOut = false
    @State private var writeFailed = false

    var body: some View {
        Screen(title: SettingsCopy.masthead) {
            ScrollView {
                VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                    ForEach(SettingsSection.allCases) { section in
                        panel(for: section)
                    }

                    if writeFailed {
                        Text(PreSeasonCopy.consentDidNotSave)
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.safety)
                    }

                    Text(Signposting.notAMedicalDevice)
                        .ninetyType(.footnote)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                }
                .padding(.bottom, Ninety.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear(perform: read)
    }

    @ViewBuilder
    private func panel(for section: SettingsSection) -> some View {
        switch section {
        case .competitive: competitive
        case .support: support
        case .consent: consent
        case .account: account
        }
    }

    // MARK: - S6

    /// The switch reads "turn off", so it is **on when competition is off**.
    ///
    /// A switch labelled by its action rather than by its state is normally a
    /// mistake, and here it is the honest option: the stored column is
    /// `competitive_opt_out`, the §10 requirement is an opt-*out*, and a control
    /// labelled "Competitive features" that is on by default would be the app
    /// asking a question nobody wanted asked. The note below states the
    /// resulting state in words, which is what a screen reader announces after
    /// the toggle either way.
    private var competitive: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            SwitchPanel(
                heading: SettingsCopy.competitiveHeading,
                explainer: SettingsCopy.competitiveBody,
                action: SettingsCopy.competitiveAction,
                isOn: isOptedOut,
                toggle: toggleCompetitive
            )

            if isOptedOut {
                Text(SettingsCopy.competitiveOffNote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    // MARK: - S7

    /// Always here, never behind a disclosure, and never conditional on
    /// anything the app thinks it has noticed. The Phase 3 half of S7 surfaces
    /// this elsewhere when a pattern suggests it may help; this half is the one
    /// that has to be true on every launch.
    private var support: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text(SettingsCopy.supportHeading)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)

            Text(Signposting.intro)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

            ForEach(Signposting.resources) { resource in
                VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                    Text(resource.name)
                        .ninetyType(.callout)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                    if let phone = resource.phone {
                        Text(phone)
                            .ninetyType(.metricS)
                            .foregroundStyle(Ninety.Colour.textPrimary)
                    }
                    Text(resource.site)
                        .ninetyType(.footnote)
                        .foregroundStyle(Ninety.Colour.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(resource.accessibilityLabel)
            }

            Text(Signposting.disclaimer)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
        .chalkPanel(padding: Ninety.Space.lg)
    }

    // MARK: - Consent

    private var consent: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text(SettingsCopy.consentHeading)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)

            Text(SettingsCopy.consentBody)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

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

            Text(SettingsCopy.withdrawalReturnsNote)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }

    // MARK: - Account

    private var account: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text(SettingsCopy.accountHeading)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)

            Text(SettingsCopy.signOutNote)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

            Button(SettingsCopy.signOut) {
                dismiss()
                onSignOut()
            }
            .ninetyType(.callout)
            .foregroundStyle(Ninety.Colour.accent)
        }
        .chalkPanel(padding: Ninety.Space.lg)
    }

    // MARK: - Writes

    private func read() {
        status = recorder.status
        isOptedOut = profiles.isCompetitiveOptOutEnabled()
    }

    /// Reversible, and it keeps everything. §10's own words: history is
    /// preserved and the switch works in both directions. Nothing here deletes a
    /// score, a log or a weight — the opt-out hides competitive surfaces and
    /// stops the engine running, and that is the whole of it.
    private func toggleCompetitive() {
        guard let profile = profiles.current() else { return }
        profile.competitiveOptOut.toggle()
        write { try profiles.save(profile) }
        onCompetitiveChanged()
    }

    private func toggleTerms() {
        write { status.hasTerms ? try recorder.withdrawTerms() : try recorder.acceptTerms(at: .now) }
        onConsentChanged()
    }

    /// Withdrawing health consent puts the gate back up.
    ///
    /// The sheet dismisses itself first: leaving Settings open over a consent
    /// screen would let the user keep using a surface the app has just lost the
    /// lawful basis for, which is the exact thing the withdrawal was for.
    private func toggleHealthData() {
        write {
            status.hasHealthConsent
                ? try recorder.withdrawHealthConsent()
                : try recorder.consentToHealthData(at: .now)
        }
        if !status.allowsHealthProcessing { dismiss() }
        onConsentChanged()
    }

    /// Reads the result back from the store rather than assuming the write
    /// landed — the same rule the consent screen follows, and for the same
    /// reason: a consent record the app believes in and the database does not is
    /// the failure this whole area exists to avoid.
    private func write(_ change: () throws -> Profile?) {
        do {
            _ = try change()
            writeFailed = false
        } catch {
            Log.data.error("Settings write did not persist: \(error.localizedDescription, privacy: .public)")
            writeFailed = true
        }
        read()
    }
}

// See the note in SignInView: these build DEBUG-only mocks.
#if DEBUG
@MainActor
private func previewSettings(optedOut: Bool) -> SettingsView {
    let user = UUID()
    let profiles = MockProfileRepository(
        profile: Profile(
            id: user,
            competitiveOptOut: optedOut,
            termsAcceptedAt: .now,
            healthConsentAt: .now
        )
    )
    return SettingsView(
        recorder: ConsentRecorder(profiles: profiles, userID: user),
        profiles: profiles,
        onConsentChanged: {},
        onCompetitiveChanged: {},
        onSignOut: {}
    )
}

#Preview("Settings") {
    previewSettings(optedOut: false)
}

#Preview("Settings · opted out") {
    previewSettings(optedOut: true)
}

#Preview("Settings · accessibility 5") {
    previewSettings(optedOut: false).dynamicTypeSize(.accessibility5)
}
#endif
