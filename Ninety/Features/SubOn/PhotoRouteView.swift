import PhotosUI
import SwiftUI

/// Path 3 — photograph the meal.
///
/// Capture or pick, downscale, upload, ask the Edge Function, then **Under
/// Review**, which is not optional (ADR 0010). Nothing on this route writes a
/// row; the only thing that can is `UnderReviewModel.confirm`.
///
/// **Every failure here lands on the same sentence**: the other three routes
/// still work and none of them needs a signal. §1.3 frames the photo estimate as
/// a helper rather than a feature the app depends on, and a route that dead-ends
/// on a network error would be treating it as the latter.
struct PhotoRouteView: View {
    let model: SubOnModel
    let estimator: (any MealEstimating)?

    @State private var phase: Phase = .choosing
    @State private var isCapturing = false
    @State private var isChoosing = false
    @State private var pickerItem: PhotosPickerItem?

    @Environment(\.dismiss)
    private var dismiss

    private enum Phase: Equatable {
        case choosing
        case estimating
        case reviewing(MealEstimate)
        case failed(MealEstimateError)
    }

    var body: some View {
        Screen(title: SubOnCopy.photoRoute, meta: model.period.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                    switch phase {
                    case .choosing:
                        chooser
                    case .estimating:
                        // Not a spinner over an empty screen: the wait is real
                        // (the spike measured 1.9-3.1 s), so it says what is
                        // happening and what it will hand back.
                        HoldingNote(
                            eyebrow: SubOnCopy.photoRoute,
                            headline: SubOnCopy.photoWorking,
                            detail: SubOnCopy.underReviewBody
                        )
                    case .reviewing:
                        EmptyView()
                    case .failed(let error):
                        failure(error)
                    }
                }
                .padding(.bottom, Ninety.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .fullScreenCover(isPresented: $isCapturing) {
            MealCamera(
                onCapture: { image in
                    isCapturing = false
                    estimate(image)
                },
                onCancel: { isCapturing = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .navigationDestination(
            isPresented: Binding(
                get: { if case .reviewing = phase { true } else { false } },
                set: { if !$0 { phase = .choosing } }
            )
        ) {
            if case .reviewing(let estimate) = phase {
                UnderReviewView(model: model, estimate: estimate, onRetake: { phase = .choosing })
            }
        }
    }

    // MARK: - Choosing a photo

    private var chooser: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.lg) {
            Text(SubOnCopy.photoPrompt)
                .ninetyType(.title3)
                .foregroundStyle(Ninety.Colour.textPrimary)

            Text(SubOnCopy.underReviewBody)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

            if MealCamera.isAvailable {
                Button(SubOnCopy.photoTakePhoto) { isCapturing = true }
                    .buttonStyle(.primary)
            }

            // The library route is not a fallback for a missing camera — it is
            // how a meal photographed twenty minutes ago gets logged, which is
            // most of them.
            //
            // The **modifier**, not the `PhotosPicker` view, and the reason is
            // Swift 6 rather than taste: the view takes a `@ViewBuilder label:`
            // closure that is not `@MainActor`, so styling anything inside it
            // calls `ninetyType` — main-actor isolated through the `View`
            // extension it lives in — from a nonisolated context and returns a
            // non-Sendable `some View` out of it. The modifier has no label to
            // isolate, and the control in front of it is then an ordinary
            // secondary button rather than a picker wearing a hand-made one.
            Button(SubOnCopy.photoChoosePhoto) { isChoosing = true }
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .photosPicker(isPresented: $isChoosing, selection: $pickerItem, matching: .images)
    }

    private func failure(_ error: MealEstimateError) -> some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text(error.errorDescription ?? SubOnCopy.estimateUnavailable)
                .ninetyType(.title3)
                .foregroundStyle(Ninety.Colour.textPrimary)
            Text(error.recoveryDescription)
                .ninetyType(.footnote)
                // `safety`, never `critical`. The token set has no error colour
                // for a state the user did not cause, and a red banner over a
                // network blip trains people to ignore the one that matters.
                .foregroundStyle(Ninety.Colour.safety)

            Button(SubOnCopy.photoRetake) { phase = .choosing }
                .buttonStyle(.primary)

            Button(SubOnCopy.addItManually) { model.route = .manual }
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.accent)
                .frame(minHeight: 44)
        }
        .chalkPanel(padding: Ninety.Space.lg)
    }

    // MARK: - The round trip

    private func loadPicked(_ item: PhotosPickerItem) async {
        pickerItem = nil
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            phase = .failed(.malformedResponse)
            return
        }
        estimate(image)
    }

    private func estimate(_ image: UIImage) {
        guard let estimator else {
            // A build with no Supabase project in it. The same honest state the
            // sign-in screen has for the same cause.
            phase = .failed(.unavailable)
            return
        }
        guard let jpeg = MealPhoto.jpeg(from: image) else {
            phase = .failed(.malformedResponse)
            return
        }

        phase = .estimating
        Task {
            do {
                let estimate = try await estimator.estimate(jpeg: jpeg)
                // Counts and timings only. Nothing under the `data` category
                // may carry a logged value: a food name in a log line is
                // Article 9 health data written where the consent record does
                // not reach.
                let seconds = Int(estimate.latency * 1_000)
                Log.data.info(
                    """
                    meal estimate: \(estimate.items.count, privacy: .public) items \
                    in \(seconds, privacy: .public)ms
                    """
                )
                phase = .reviewing(estimate)
            } catch let error as MealEstimateError {
                phase = .failed(error)
            } catch {
                phase = .failed(.unavailable)
            }
        }
    }
}
