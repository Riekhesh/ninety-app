import SwiftUI

/// The four Pre-Season steps.
///
/// Split from `OnboardingView` because the flow and the fields are two different
/// things to read: the shell is about order and navigation, and these are about
/// what each screen asks and which §10 gate it states. Nothing here holds state
/// — every value lives on `OnboardingModel`, which is where the gates that
/// depend on each other can see each other.

// MARK: - 1 · About you

/// Date of birth, height, sex, activity level.
///
/// The date picker is **not** bounded to eighteen-and-over. It could be, and
/// that would make S4 unreachable from the interface — a gate nobody can hit is
/// a gate nobody can be told about, and §10 asks for a stop with an explanation
/// and a helpline, not a control that quietly refuses to move.
struct AboutYouStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xl) {
            Text(OnboardingCopy.aboutYouTitle)
                .ninetyType(.title2)

            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                Text(OnboardingCopy.dateOfBirth)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)

                DatePicker(
                    OnboardingCopy.dateOfBirth,
                    selection: $model.dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Ninety.Colour.accent)
            }

            NinetyField(
                label: OnboardingCopy.height,
                unit: OnboardingCopy.heightUnit,
                value: $model.heightText,
                safetyMessage: model.heightMessage,
                keyboard: .numberPad
            )

            ChoiceRow(
                label: OnboardingCopy.sex,
                options: [
                    .init(Sex.female, title: OnboardingCopy.sexFemale),
                    .init(Sex.male, title: OnboardingCopy.sexMale),
                    .init(Sex.unspecified, title: OnboardingCopy.sexUnspecified),
                ],
                selection: $model.sex
            )

            if model.sex == .unspecified {
                Text(OnboardingCopy.sexUnspecifiedNote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }

            ChoiceRow(
                label: OnboardingCopy.activityLevel,
                options: ActivityLevel.allCases.map {
                    ChoiceRow<ActivityLevel>.Option($0, title: $0.title, detail: $0.detail)
                },
                selection: $model.activityLevel
            )

            Text(OnboardingCopy.aboutYouFootnote)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }
}

// MARK: - 2 · Starting weight

/// One reading, which is both the baseline and the first point on the trend.
struct StartingWeightStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xl) {
            Text(OnboardingCopy.weightTitle)
                .ninetyType(.title2)

            Text(OnboardingCopy.weightBody)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

            NinetyField(
                label: OnboardingCopy.weightLabel,
                unit: OnboardingCopy.weightUnit,
                value: $model.weightText,
                safetyMessage: model.weightMessage
            )

            Text(OnboardingCopy.weightFootnote)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }
}

// MARK: - 3 · Goal

/// Where S2 and S3 both live.
///
/// **S2 rejects and says the number.** A goal weight below BMI 18.5 is refused
/// rather than clamped, and the refusal carries the lowest acceptable weight so
/// nobody is left guessing at it.
///
/// **S3 filters rather than disables.** Rates above the user's ceiling are not
/// shown at all, and the footnote says the ceiling exists before the user has a
/// chance to wonder why the list is short.
struct GoalStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xl) {
            Text(OnboardingCopy.goalTitle)
                .ninetyType(.title2)

            ChoiceRow(
                label: OnboardingCopy.goalTypeLabel,
                options: [
                    .init(GoalType.lose, title: OnboardingCopy.goalLose),
                    .init(GoalType.maintain, title: OnboardingCopy.goalMaintain),
                    .init(GoalType.gain, title: OnboardingCopy.goalGain),
                ],
                selection: $model.goalType
            )

            if model.goalType != .maintain {
                NinetyField(
                    label: OnboardingCopy.goalWeightLabel,
                    unit: OnboardingCopy.weightUnit,
                    value: $model.goalWeightText,
                    safetyMessage: model.goalWeightMessage
                )
            }

            if model.goalType == .lose {
                ChoiceRow(
                    label: OnboardingCopy.rateLabel,
                    options: model.availableRates.map {
                        ChoiceRow<Double>.Option($0, title: LossRate.label(for: $0))
                    },
                    selection: $model.targetRate,
                    emptyNote: OnboardingCopy.noRateAvailable
                )

                Text(OnboardingCopy.rateFootnote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
        .onAppear { model.normaliseRate() }
        .onChange(of: model.goalType) { model.normaliseRate() }
        .onChange(of: model.weightText) { model.normaliseRate() }
    }
}

// MARK: - 4 · Your band, and why there is no division yet

/// The band, the S1 note if the floor bound, and the calibration explainer.
///
/// Two things on one screen because they are one answer to the same question —
/// *what does Ninety do with all that?* — and because this is the screen whose
/// primary action finishes the flow. `OnboardingModel.advance()` records why the
/// goal is written here rather than a step earlier.
struct BandStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xl) {
            Text(OnboardingCopy.bandTitle)
                .ninetyType(.title2)

            if let band = model.band {
                VStack(alignment: .leading, spacing: Ninety.Space.md) {
                    Text(OnboardingCopy.band(band))
                        .ninetyType(.metricL)
                        .foregroundStyle(Ninety.Colour.accent)

                    Text(OnboardingCopy.bandBody)
                        .ninetyType(.subhead)
                        .foregroundStyle(Ninety.Colour.textSecondary)

                    if band.isAtFloor {
                        Text(OnboardingCopy.floorApplied(floor: band.floor, slowerRate: band.slowerRate))
                            .ninetyType(.footnote)
                            .foregroundStyle(Ninety.Colour.safety)
                    }
                }
                .chalkPanel(padding: Ninety.Space.lg)
                .accessibilityElement(children: .combine)
            }

            Text(OnboardingCopy.bandFootnote)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)

            VStack(alignment: .leading, spacing: Ninety.Space.md) {
                Text(OnboardingCopy.calibrationTitle)
                    .ninetyType(.title3)

                Text(OnboardingCopy.calibrationBody)
                    .ninetyType(.subhead)
                    .foregroundStyle(Ninety.Colour.textSecondary)

                Text(OnboardingCopy.calibrationBody2)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
            .chalkPanel(padding: Ninety.Space.lg)
        }
    }
}

// MARK: - Domain values, as the copy deck words them

/// The words on the options.
///
/// Here rather than on the enums in `Domain.swift`: those types are the schema's
/// vocabulary and cross the wire to Postgres, and giving them display strings
/// would put user-facing copy — which S5 lints — inside the data layer.
extension ActivityLevel {
    var title: String {
        switch self {
        case .sedentary: OnboardingCopy.activitySedentary
        case .light: OnboardingCopy.activityLight
        case .moderate: OnboardingCopy.activityModerate
        case .active: OnboardingCopy.activityActive
        case .veryActive: OnboardingCopy.activityVeryActive
        }
    }

    /// Without these the five levels are five words nobody can choose between.
    var detail: String {
        switch self {
        case .sedentary: OnboardingCopy.activitySedentaryDetail
        case .light: OnboardingCopy.activityLightDetail
        case .moderate: OnboardingCopy.activityModerateDetail
        case .active: OnboardingCopy.activityActiveDetail
        case .veryActive: OnboardingCopy.activityVeryActiveDetail
        }
    }
}
