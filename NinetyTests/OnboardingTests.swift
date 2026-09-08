import Foundation
import Testing
@testable import Ninety

/// Pre-Season: the flow, and the gates it wires in as it goes.
///
/// The §10 rules themselves are asserted in `SafetyGateTests` against their own
/// types. This suite is about the *flow* — that quitting halfway loses nothing,
/// that the age gate is reached rather than merely computable, and that what
/// reaches the store is what the gates allow rather than what was typed.
@MainActor
@Suite("Pre-Season onboarding")
struct OnboardingTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8)) ?? .distantPast

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private struct Fixture {
        let model: OnboardingModel
        let profiles: MockProfileRepository
        let weights: MockWeightRepository
        let userID: UUID
    }

    private func makeFixture(profile: Profile? = nil, weights existing: [WeightLog] = []) -> Fixture {
        let user = profile?.id ?? UUID()
        let profiles = MockProfileRepository(profile: profile)
        let weights = MockWeightRepository(logs: existing)
        return Fixture(
            model: OnboardingModel(
                profiles: profiles,
                weights: weights,
                userID: user,
                calendar: Self.calendar,
                now: { Self.today }
            ),
            profiles: profiles,
            weights: weights,
            userID: user
        )
    }

    /// Walks an adult through to the goal step.
    private func adult() -> Fixture {
        let fixture = makeFixture()
        fixture.model.dateOfBirth = Self.date(1990, 4, 12)
        fixture.model.heightText = "175"
        fixture.model.sex = .female
        fixture.model.activityLevel = .light
        fixture.model.advance()
        fixture.model.weightText = "78.4"
        fixture.model.advance()
        return fixture
    }

    // MARK: - Every field persists

    @Test("each step writes what it collected before the next one appears")
    func everyFieldPersists() {
        let fixture = adult()
        fixture.model.goalWeightText = "70"
        fixture.model.targetRate = 0.5
        fixture.model.advance()
        fixture.model.advance()

        let profile = fixture.profiles.current()
        #expect(profile?.dob == Self.date(1990, 4, 12))
        #expect(profile?.heightCm == 175)
        #expect(profile?.sex == .female)
        #expect(profile?.activityLevel == .light)
        #expect(profile?.goalType == .lose)
        #expect(profile?.goalWeightKg == 70)
        #expect(profile?.targetRateKgPerWeek == 0.5)
        #expect(fixture.weights.recent(limit: 5).first?.kg == 78.4)
        #expect(fixture.model.isFinished)
    }

    // MARK: - Resumable

    @Test("quitting mid-flow resumes at the first thing still missing")
    func resumesWhereItWasLeft() {
        let user = UUID()
        let started = Profile(id: user, dob: Self.date(1990, 4, 12), heightCm: 175)

        // Nothing but the first step done: the weight is what is missing.
        let atWeight = makeFixture(profile: started)
        #expect(atWeight.model.step == .startingWeight)
        #expect(atWeight.model.heightText == "175", "and what was entered comes back with it")

        // With a reading recorded, the goal is next.
        let weighed = makeFixture(
            profile: started,
            weights: [WeightLog(userID: user, measuredAt: Self.today, kg: 78.4)]
        )
        #expect(weighed.model.step == .goal)
        #expect(weighed.model.weightText == "78.4")

        // And with a goal weight on the row, the flow is finished.
        started.goalWeightKg = 70
        let done = makeFixture(
            profile: started,
            weights: [WeightLog(userID: user, measuredAt: Self.today, kg: 78.4)]
        )
        #expect(done.model.step == .band)
        #expect(OnboardingModel.isComplete(profiles: done.profiles, weights: done.weights))
    }

    @Test("a fresh install starts at the first step and is not complete")
    func freshInstallStartsAtTheTop() {
        let fixture = makeFixture()

        #expect(fixture.model.step == .aboutYou)
        #expect(!OnboardingModel.isComplete(profiles: fixture.profiles, weights: fixture.weights))
    }

    /// Completion is two questions, because the answers live in two tables. A
    /// profile with every value and no weight reading has no baseline, and the
    /// band cannot be computed from it.
    @Test("a profile with no weight reading is not complete")
    func completionNeedsAWeightReading() {
        let user = UUID()
        let profile = Profile(id: user, dob: Self.date(1990, 4, 12), heightCm: 175, goalWeightKg: 70)
        let fixture = makeFixture(profile: profile)

        #expect(profile.hasCompletedPreSeason)
        #expect(!OnboardingModel.isComplete(profiles: fixture.profiles, weights: fixture.weights))
    }

    @Test("stepping back and forth does not fill the trend with duplicate weigh-ins")
    func weightIsRecordedOnce() {
        let fixture = adult()

        fixture.model.back()
        fixture.model.advance()
        fixture.model.back()
        fixture.model.advance()

        #expect(fixture.weights.recent(limit: 10).count == 1)
    }

    // MARK: - S4, reached rather than merely computable

    @Test("an under-18 date of birth reaches the age gate, and is written down")
    func underageEntryHitsTheGate() {
        let fixture = makeFixture()
        fixture.model.dateOfBirth = Self.date(2012, 1, 1)
        fixture.model.heightText = "160"

        #expect(fixture.model.canAdvance, "the button is enabled; the stop is a screen with an explanation")

        fixture.model.advance()

        #expect(fixture.model.isBlockedByAge)
        #expect(fixture.model.step == .aboutYou, "and there is no step past it")
        #expect(fixture.profiles.current()?.dob == Self.date(2012, 1, 1), "written, so the block survives a relaunch")
    }

    @Test("a profile already carrying an under-18 date of birth is blocked before a screen draws")
    func storedUnderageProfileIsBlockedOnLaunch() {
        let profile = Profile(id: UUID(), dob: Self.date(2012, 1, 1), heightCm: 160)

        #expect(makeFixture(profile: profile).model.isBlockedByAge)
    }

    // MARK: - S2 and S3, as the flow applies them

    @Test("the goal step will not advance while S2 is refusing the goal weight")
    func goalWeightRefusalBlocksTheStep() {
        let fixture = adult()
        fixture.model.goalWeightText = "50"

        #expect(fixture.model.goalWeightMessage != nil)
        #expect(!fixture.model.canAdvance)

        fixture.model.goalWeightText = "70"
        #expect(fixture.model.goalWeightMessage == nil)
        #expect(fixture.model.canAdvance)
    }

    @Test("the rates offered are the ones inside the S3 ceiling for the weight entered")
    func ratesAreFilteredByWeight() {
        let fixture = adult()

        #expect(fixture.model.availableRates == [0.25, 0.5, 0.75], "78.4 kg has a ceiling of 0.784")

        fixture.model.weightText = "60"
        #expect(fixture.model.availableRates == [0.25, 0.5], "0.6 kg/week is the ceiling at 60 kg")
    }

    /// The ceiling moves with body weight, so editing the weight can strand an
    /// already-chosen rate above it. The flow picks a legal one rather than
    /// leaving the user with an illegal selection and a disabled button.
    @Test("a rate stranded above the ceiling by an edited weight is brought back inside it")
    func rateIsNormalisedWhenTheCeilingMoves() {
        let fixture = adult()
        fixture.model.targetRate = 0.75
        fixture.model.weightText = "60"

        fixture.model.normaliseRate()

        #expect(fixture.model.targetRate == 0.5)
        #expect(LossRate.isWithinCeiling(fixture.model.targetRate, forBodyWeightKg: 60))
    }

    /// S3 again, on the value that actually reaches the store. A safety rule
    /// enforced only by a picker disappears the moment the picker changes.
    @Test("the persisted rate is clamped to the ceiling, whatever the picker held")
    func persistedRateIsClamped() {
        let fixture = adult()
        fixture.model.weightText = "60"
        fixture.model.goalWeightText = "58"
        fixture.model.targetRate = 0.75
        fixture.model.advance()
        fixture.model.advance()

        let stored = fixture.profiles.current()?.targetRateKgPerWeek ?? .infinity
        #expect(stored <= LossRate.ceiling(forBodyWeightKg: 60))
        #expect(abs(stored - 0.6) < 0.0001)
    }

    @Test("maintaining stores the weight you are at, and no rate of change")
    func maintainingStoresTheCurrentWeight() {
        let fixture = adult()
        fixture.model.goalType = .maintain
        fixture.model.advance()
        fixture.model.advance()

        #expect(fixture.profiles.current()?.goalType == .maintain)
        #expect(fixture.profiles.current()?.goalWeightKg == 78.4)
        #expect(fixture.profiles.current()?.targetRateKgPerWeek == 0)
        #expect(fixture.model.isFinished)
    }

    // MARK: - The band

    @Test("the band is computed from what was entered, and is a figure plus a tolerance")
    func bandIsComputedAndRenderedAsATolerance() {
        let fixture = adult()
        fixture.model.goalWeightText = "70"
        fixture.model.advance()

        guard let band = fixture.model.band else {
            Issue.record("everything the equation needs was entered, so there should be a band")
            return
        }

        #expect(band.tolerance == 100)
        #expect(!band.isAtFloor)
        #expect(band.centre > band.floor)

        let rendered = OnboardingCopy.band(band)
        #expect(rendered.contains("±"))
        #expect(!rendered.contains("–"), "PRODUCT.md: a figure plus a tolerance, never two numbers and a dash")
        #expect(rendered.hasSuffix("kcal"))
    }

    /// Both separators, because the field uses a decimal keypad and the keypad's
    /// separator is whichever one the device's region uses.
    @Test("a comma decimal separator parses")
    func commaDecimalSeparatorParses() {
        #expect(OnboardingModel.number(from: "78,4") == 78.4)
        #expect(OnboardingModel.number(from: "78.4") == 78.4)
        #expect(OnboardingModel.number(from: " ") == nil)
        #expect(OnboardingModel.number(from: "") == nil)
    }
}
