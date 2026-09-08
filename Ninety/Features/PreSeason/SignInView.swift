import AuthenticationServices
import SwiftUI

/// One button, and nothing else to decide.
///
/// **Sign in with Apple is the only route in** (§1.1). Not because a second
/// provider would be hard, but because Apple's rule is that an app offering any
/// third-party login must also offer this one — so every provider added later
/// is added *beside* Sign in with Apple, never instead of it. Shipping one now
/// means there is no migration, no account-linking screen, and no "you
/// previously signed in with Google" state to design. ADR 0016.
struct SignInView: View {
    let session: SessionController

    /// Apple's button is a fixed-height system control, so it gets the same
    /// scaled height the primary button uses rather than a hardcoded 50.
    @ScaledMetric(relativeTo: .headline)
    private var buttonHeight: CGFloat = 50

    /// The tallest `ASAuthorizationAppleIDButton` will draw. Apple's own
    /// constraint, and Dynamic Type is not allowed to push past it — a scaled
    /// height above this is the same unsatisfiable-constraint break at an
    /// accessibility size instead of at the default one.
    private static let appleButtonMaximumHeight: CGFloat = 64

    var body: some View {
        Screen(title: PreSeasonCopy.signInTitle) {
            VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                Text(PreSeasonCopy.pitch)
                    .ninetyType(.title3)
                    .foregroundStyle(Ninety.Colour.textSecondary)

                if session.state == .unconfigured {
                    unconfiguredNote
                } else {
                    appleButton
                    if let failure = session.failure {
                        FailureNote(failure: failure)
                    }
                }

                Text(PreSeasonCopy.signInFootnote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    /// Deliberately not restyled to match the world.
    ///
    /// The gold primary button is the app's one filled control, and this is not
    /// it: Apple's Human Interface Guidelines fix this button's appearance, and
    /// an app that draws its own "Continue with Apple" is a rejection waiting
    /// to happen. `DESIGN.md` records the deviation.
    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            session.prepare(request)
        } onCompletion: { result in
            Task { await session.finish(result) }
        }
        .signInWithAppleButtonStyle(.white)
        // Apple's button carries its own `width <= 375`. Forcing it to fill the
        // gutter breaks that constraint — UIKit recovers and still draws it
        // full width, which is why it looked right, but it logs an
        // unsatisfiable-constraints block on every launch. Capped and centred
        // instead: on the widest phone that is 375 of an available 390.
        //
        // The HEIGHT is the same class of bug and it is the visible one. This
        // was `minHeight:` with no maximum, and the button is a
        // `UIViewRepresentable` with no intrinsic height in SwiftUI's layout —
        // so it accepted every point the VStack offered it (509 on an iPhone 17)
        // and UIKit "recovered" by breaking Apple's own `height <= 64`. The
        // result is not a subtle misalignment: the sign-in screen is a white
        // slab most of the way down. An exact height, clamped to Apple's cap.
        .frame(maxWidth: 375, height: min(buttonHeight, Self.appleButtonMaximumHeight))
        .frame(maxWidth: .infinity)
        .disabled(session.isSigningIn)
    }

    /// A clone with no `Config/Local.xcconfig`. Not a state a user reaches, and
    /// it says what is missing rather than pretending the button is broken.
    private var unconfiguredNote: some View {
        HoldingNote(
            eyebrow: "Setup",
            headline: PreSeasonCopy.notConfiguredHeadline,
            detail: AuthFailure.notConfigured.recoveryDescription ?? ""
        )
    }
}

/// What a failed sign-in says, in the copy deck's words.
///
/// `safety` rather than `critical`: the token set has no error colour for a
/// state the user did not cause, and a red banner over a network blip trains
/// people to ignore the one that matters.
struct FailureNote: View {
    let failure: AuthFailure

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            if let description = failure.errorDescription {
                Text(description)
                    .ninetyType(.subhead)
                    .foregroundStyle(Ninety.Colour.safety)
            }
            if let recovery = failure.recoveryDescription {
                Text(recovery)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// The mocks are `#if DEBUG`, and `#Preview` is not: an unguarded preview
// referring to one is a release build that does not compile.
#if DEBUG
#Preview("Sign in") {
    SignInView(session: SessionController(service: MockAuthService()))
}

#Preview("Sign in · not configured") {
    SignInView(session: SessionController(service: nil))
}

#Preview("Sign in · accessibility 5") {
    SignInView(session: SessionController(service: MockAuthService()))
        .dynamicTypeSize(.accessibility5)
}
#endif
