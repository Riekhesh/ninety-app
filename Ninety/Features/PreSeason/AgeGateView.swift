import SwiftUI

/// §10 S4 · the hard stop.
///
/// **There is no way through this screen**, and that is the requirement: no
/// "continue anyway", no parental-consent path, no second attempt at the date of
/// birth. The date is already on the profile, so relaunching or signing back in
/// lands here again — the block is a fact about the account rather than a screen
/// that can be backed out of.
///
/// §10's reason is the honest one and the copy uses it rather than dressing it as
/// a legal technicality: *"the safeguarding considerations for minors and
/// body-image content are substantial and well beyond what a solo v1 should
/// attempt."*
///
/// **It signposts.** S4 is explicit: a user turned away should not leave with
/// nothing, so Beat's youth helpline is on the screen that turns them away.
struct AgeGateView: View {
    /// The only action, and it is not a bypass. iOS apps cannot close
    /// themselves, so the copy deck's `Close` would have been a button that does
    /// nothing.
    var onSignOut: () -> Void

    var body: some View {
        Screen(title: OnboardingCopy.masthead) {
            VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                Text(OnboardingCopy.ageGateTitle)
                    .ninetyType(.title2)

                Text(OnboardingCopy.ageGateBody)
                    .ninetyType(.subhead)
                    .foregroundStyle(Ninety.Colour.textSecondary)

                VStack(alignment: .leading, spacing: Ninety.Space.md) {
                    Text(Signposting.youthHelpline)
                        .ninetyType(.subhead)
                        .foregroundStyle(Ninety.Colour.textPrimary)

                    if let phone = Signposting.beat.phone {
                        Text(phone)
                            .ninetyType(.metricS)
                            .foregroundStyle(Ninety.Colour.textPrimary)
                    }

                    Text(Signposting.beat.site)
                        .ninetyType(.footnote)
                        .foregroundStyle(Ninety.Colour.textSecondary)
                }
                .chalkPanel(padding: Ninety.Space.lg)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Signposting.youthHelpline) \(Signposting.beat.accessibilityLabel)")

                Button(OnboardingCopy.ageGateAction, action: onSignOut)
                    .ninetyType(.subhead)
                    .foregroundStyle(Ninety.Colour.textSecondary)

                Text(Signposting.notAMedicalDevice)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }
}

#Preview("Age gate") {
    AgeGateView(onSignOut: {})
}

#Preview("Age gate · accessibility 5") {
    AgeGateView(onSignOut: {}).dynamicTypeSize(.accessibility5)
}
