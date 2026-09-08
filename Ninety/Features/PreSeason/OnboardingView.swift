import SwiftUI

/// Pre-Season: four screens that collect only what the scoring engine needs.
///
/// §1.2's list and nothing beyond it — date of birth, height, sex, activity
/// level, a starting weight, a goal and a rate. Every field here is one the
/// engine or a §10 gate reads; there is no "tell us about yourself" step,
/// because a field nobody computes with is a field that has to appear on an
/// Article 9 export for no reason.
///
/// The §10 gates are wired in as the flow is built rather than reviewed over it
/// afterwards: S4 is the screen this one swaps itself for, S2 and S3 live on the
/// goal step, and S1 is stated on the band. Each arrives with its named tests
/// already written in `docs/safety/safety-requirements.md`.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel

    /// The shell re-reads the store rather than trusting a flag passed up from
    /// here — the same rule the consent gate follows.
    var onFinished: () -> Void

    /// S4's only exit, and the way out of a flow somebody does not want to
    /// finish.
    var onSignOut: () -> Void

    var body: some View {
        Group {
            if model.isBlockedByAge {
                AgeGateView(onSignOut: onSignOut)
            } else {
                flow
            }
        }
        .onChange(of: model.isFinished) {
            if model.isFinished { onFinished() }
        }
    }

    private var flow: some View {
        Screen(
            title: OnboardingCopy.masthead,
            meta: OnboardingCopy.stepMeta(model.step.rawValue, of: OnboardingModel.Step.allCases.count)
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                    step
                    if model.writeFailed {
                        Text(OnboardingCopy.didNotSave)
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.safety)
                    }
                    actions
                }
                .padding(.bottom, Ninety.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder private var step: some View {
        switch model.step {
        case .aboutYou: AboutYouStep(model: model)
        case .startingWeight: StartingWeightStep(model: model)
        case .goal: GoalStep(model: model)
        case .band: BandStep(model: model)
        }
    }

    /// One primary action per screen, and Back is a plain button rather than a
    /// second filled one — gold belongs to the division, and spending it twice
    /// on the same screen costs the weekly reveal the contrast it depends on.
    private var actions: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Button(model.step == .band ? OnboardingCopy.kickOff : OnboardingCopy.next) {
                model.advance()
            }
            .buttonStyle(.primary)
            .disabled(!model.canAdvance)

            if model.step != .aboutYou {
                Button(OnboardingCopy.back) { model.back() }
                    .ninetyType(.subhead)
                    .foregroundStyle(Ninety.Colour.textSecondary)
            }
        }
    }
}

// See the note in SignInView: these build DEBUG-only mocks.
#if DEBUG
@MainActor
private func previewModel(step: OnboardingModel.Step) -> OnboardingModel {
    let user = UUID()
    let profile = Profile(id: user, termsAcceptedAt: .now, healthConsentAt: .now)
    let profiles = MockProfileRepository(profile: profile)
    let weights = MockWeightRepository()
    let model = OnboardingModel(profiles: profiles, weights: weights, userID: user)

    // Walked forward rather than constructed at a step: the flow's own
    // transitions are what a preview should be showing.
    model.heightText = "175"
    model.sex = .female
    if step != .aboutYou { model.advance() }
    model.weightText = "78.4"
    if step == .goal || step == .band { model.advance() }
    model.goalWeightText = "70"
    if step == .band { model.advance() }
    return model
}

#Preview("Pre-Season · about you") {
    OnboardingView(model: previewModel(step: .aboutYou), onFinished: {}, onSignOut: {})
}

#Preview("Pre-Season · goal") {
    OnboardingView(model: previewModel(step: .goal), onFinished: {}, onSignOut: {})
}

#Preview("Pre-Season · band") {
    OnboardingView(model: previewModel(step: .band), onFinished: {}, onSignOut: {})
}

#Preview("Pre-Season · band · accessibility 5") {
    OnboardingView(model: previewModel(step: .band), onFinished: {}, onSignOut: {})
        .dynamicTypeSize(.accessibility5)
}
#endif
