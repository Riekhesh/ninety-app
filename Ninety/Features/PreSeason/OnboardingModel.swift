import Foundation
import Observation

/// Pre-Season, as state rather than as four screens with their own ideas.
///
/// ADR 0004's shape: an `@Observable` object between the views and the
/// repositories. It exists for three reasons that a set of `@State` variables
/// would each get wrong in a different way.
///
/// **The §10 gates are decisions, not validations.** S1's floor, S2's refusal
/// and S3's ceiling all interact — the rates offered depend on the weight
/// entered, and whether the floor binds depends on the rate chosen — so they
/// have to be computed from one place that holds all of it. Spread across the
/// views they would be four rules that agree until somebody edits a screen.
///
/// **It is resumable, because quitting mid-flow is normal.** Each step writes
/// what it collected before the next one appears, and the flow resumes from the
/// first thing the profile is missing. A user who is interrupted at the weight
/// step comes back to the weight step with their date of birth already in.
///
/// **The clock is injected.** S4 turns on what day it is, and a test that cannot
/// say "today is the day before their eighteenth birthday" cannot check the one
/// case S4 is about.
@MainActor
@Observable
final class OnboardingModel {
    /// Four steps. The band and the calibration explainer share the last one
    /// deliberately — see `advance()`.
    enum Step: Int, CaseIterable, Identifiable, Sendable {
        case aboutYou = 1
        case startingWeight
        case goal
        case band

        var id: Int { rawValue }
    }

    // MARK: - What the user entered

    var dateOfBirth: Date
    var heightText: String
    var sex: Sex
    var activityLevel: ActivityLevel
    var weightText: String
    var goalType: GoalType
    var goalWeightText: String
    var targetRate: Double

    // MARK: - Where they are

    private(set) var step: Step

    /// §10 S4. Set the moment a date of birth under eighteen is entered, and
    /// never cleared — the shell swaps the whole flow for the age-gate screen,
    /// and there is no path from there back into onboarding.
    private(set) var isBlockedByAge = false

    /// True once everything the engine needs is written. The shell reads it and
    /// moves on to the tabs.
    private(set) var isFinished = false

    /// A write that did not land. Shown rather than swallowed: a step that says
    /// it saved and did not is how a user loses their date of birth twice.
    private(set) var writeFailed = false

    private let profiles: any ProfileRepositoryProtocol
    private let weights: any WeightRepositoryProtocol
    private let userID: UUID
    private let calendar: Calendar
    private let now: () -> Date

    init(
        profiles: any ProfileRepositoryProtocol,
        weights: any WeightRepositoryProtocol,
        userID: UUID,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.profiles = profiles
        self.weights = weights
        self.userID = userID
        self.calendar = calendar
        self.now = now

        let profile = profiles.current()
        let latestWeight = weights.recent(limit: 1).first

        // A default that is a plausible adult rather than today. A picker
        // opening on today's date starts the user eighteen years of scrolling
        // away from any answer they might give.
        dateOfBirth = profile?.dob ?? calendar.date(byAdding: .year, value: -30, to: now()) ?? now()
        heightText = profile?.heightCm.map { Self.text(from: $0) } ?? ""
        sex = profile?.sex ?? .unspecified
        activityLevel = profile?.activityLevel ?? .sedentary
        weightText = latestWeight.map { Self.text(from: $0.kg) } ?? ""
        goalType = profile?.goalType ?? .lose
        goalWeightText = profile?.goalWeightKg.map { Self.text(from: $0) } ?? ""
        targetRate = profile?.targetRateKgPerWeek ?? 0.5

        step = Self.resumePoint(profile: profile, hasWeight: latestWeight != nil)

        // A profile already carrying an under-age date of birth is blocked
        // before a screen draws. The gate is not a thing you pass once: it is
        // evaluated from the stored date every time, which is what makes
        // signing out and back in not a way around it.
        if let dob = profile?.dob, AgeGate.outcome(dob: dob, on: now(), calendar: calendar) == .blocked {
            isBlockedByAge = true
        }
    }

    /// The first step whose answer is missing. Not the furthest step reached —
    /// nothing records that, and nothing should: the values are the state.
    private static func resumePoint(profile: Profile?, hasWeight: Bool) -> Step {
        guard let profile, profile.dob != nil, profile.heightCm != nil else { return .aboutYou }
        guard hasWeight else { return .startingWeight }
        return profile.goalWeightKg == nil ? .goal : .band
    }

    // MARK: - Derived values the screens read

    var heightCm: Double? { Self.number(from: heightText) }
    var weightKg: Double? { Self.number(from: weightText) }
    var goalWeightKg: Double? { Self.number(from: goalWeightText) }

    /// §10 S4, evaluated on the actual date.
    var isAdult: Bool {
        AgeGate.outcome(dob: dateOfBirth, on: now(), calendar: calendar) == .allowed
    }

    var heightMessage: String? {
        guard let heightCm, !heightText.isEmpty else { return nil }
        return (100...250).contains(heightCm) ? nil : OnboardingCopy.heightInvalid
    }

    var weightMessage: String? {
        guard let weightKg, !weightText.isEmpty else { return nil }
        return (25...400).contains(weightKg) ? nil : OnboardingCopy.weightInvalid
    }

    /// §10 S2. Non-nil is a refusal, and the screen's primary action stays
    /// disabled while it is showing.
    var goalWeightMessage: String? {
        guard goalType != .maintain, let goalWeightKg, let heightCm else { return nil }
        switch GoalWeight.check(goalWeightKg, heightCm: heightCm) {
        case .accepted:
            return nil
        case .belowHealthyRange(let minimumKg):
            return OnboardingCopy.goalWeightRejected(minimumKg: minimumKg)
        }
    }

    /// §10 S3. The rates that are at or below the user's ceiling — filtered, not
    /// disabled, because a control you can see and cannot use is an invitation
    /// to work out how to enable it.
    var availableRates: [Double] {
        guard goalType == .lose, let weightKg else { return [] }
        return LossRate.selectable(forBodyWeightKg: weightKg)
    }

    /// The band, once there is enough to compute one. Nil earlier in the flow.
    var band: CalorieBand? {
        guard let heightCm, let weightKg, let ageYears = AgeGate.age(dob: dateOfBirth, on: now(), calendar: calendar)
        else { return nil }

        return EnergyTarget.band(
            for: EnergyInputs(
                sex: sex,
                weightKg: weightKg,
                heightCm: heightCm,
                ageYears: ageYears,
                activityLevel: activityLevel,
                goalType: goalType,
                targetRateKgPerWeek: targetRate
            )
        )
    }

    /// Whether the current step's primary action is available.
    ///
    /// Every `false` here is paired with a visible sentence saying why — the
    /// component spec's rule that a disabled button is never the only feedback.
    var canAdvance: Bool {
        switch step {
        case .aboutYou:
            // Deliberately not gated on `isAdult`. S4 is a hard stop with an
            // explanation, and a Next button that silently refuses to enable is
            // the opposite of that — the user is told which limit they hit, on
            // a screen that also tells them where to get help.
            heightCm != nil && heightMessage == nil
        case .startingWeight:
            weightKg != nil && weightMessage == nil
        case .goal:
            goalWeightMessage == nil
                && (goalType == .maintain || goalWeightKg != nil)
                && (goalType != .lose || availableRates.contains(targetRate))
        case .band:
            band != nil
        }
    }

    // MARK: - Moving

    /// Writes what this step collected, then moves on.
    ///
    /// **The goal step's write happens on the last screen, not on the goal
    /// screen**, and that is deliberate. `Profile.hasCompletedPreSeason` is
    /// derived from the values, so writing the goal weight is what marks the
    /// flow finished — and if that happened a screen early, a user who quit on
    /// the band screen would be let into the app without ever seeing the
    /// calibration explainer, which is where §2.3's anti-sandbagging is said out
    /// loud. The cost is that quitting on the last screen loses three taps; the
    /// alternative loses the only screen that explains why there is no rank yet.
    func advance() {
        switch step {
        case .aboutYou:
            guard saveAboutYou() else { return }
            if !isAdult {
                isBlockedByAge = true
                return
            }
            step = .startingWeight

        case .startingWeight:
            guard recordWeight() else { return }
            step = .goal

        case .goal:
            step = .band

        case .band:
            guard saveGoal() else { return }
            isFinished = true
        }
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// Keeps the chosen rate inside the S3 ceiling when the numbers it depends
    /// on move.
    ///
    /// The ceiling is a function of body weight, so editing the weight can put
    /// an already-selected rate above it. Called when the goal step appears and
    /// whenever the weight or goal changes. It picks a rate rather than clearing
    /// one — the user has not done anything wrong, the limit moved — and
    /// `defaultRate` deliberately does not pick the fastest one available.
    func normaliseRate() {
        guard goalType == .lose else { return }
        let available = availableRates
        guard !available.isEmpty else { return }
        if !available.contains(targetRate) {
            targetRate = LossRate.defaultRate(forBodyWeightKg: weightKg ?? 0) ?? available[0]
        }
    }

    // MARK: - Writes

    /// Saved before the age gate is evaluated, on purpose. A date of birth that
    /// blocks the user is exactly the one worth persisting: it is what makes the
    /// block survive a relaunch instead of being a screen they can back out of.
    private func saveAboutYou() -> Bool {
        guard let heightCm else { return false }
        return write { profile in
            profile.dob = dateOfBirth
            profile.heightCm = heightCm
            profile.sex = sex
            profile.activityLevel = activityLevel
        }
    }

    private func saveGoal() -> Bool {
        write { profile in
            profile.goalType = goalType
            // Maintaining *is* a goal weight — it is the one you are at. Storing
            // it rather than leaving the column null keeps `hasCompletedPreSeason`
            // one question instead of two, and means the trend has something to
            // draw a corridor against.
            profile.goalWeightKg = goalType == .maintain ? weightKg : goalWeightKg
            // Clamped again on the way to the store. The picker already filters
            // to the ceiling, but S3 is a safety rule and a safety rule enforced
            // only by a UI control disappears the moment the control changes.
            profile.targetRateKgPerWeek = clampedRate
        }
    }

    /// §10 S3, applied to the value that is actually persisted. Zero for
    /// maintain; otherwise the chosen rate, never above the ceiling for the
    /// weight entered.
    private var clampedRate: Double {
        guard goalType != .maintain, let weightKg else { return 0 }
        return min(targetRate, LossRate.ceiling(forBodyWeightKg: weightKg))
    }

    /// One reading, and only when it is new.
    ///
    /// Stepping back and forth through the flow must not fill the trend with
    /// four identical weigh-ins from the same minute — the 7-day average would
    /// then be an average of one number entered repeatedly.
    private func recordWeight() -> Bool {
        guard let weightKg else { return false }
        if let latest = weights.recent(limit: 1).first, latest.kg == weightKg {
            return true
        }
        do {
            try weights.record(kg: weightKg, at: now(), source: .manual)
            writeFailed = false
            return true
        } catch {
            Log.data.error("Starting weight did not persist: \(error.localizedDescription, privacy: .public)")
            writeFailed = true
            return false
        }
    }

    private func write(_ change: (Profile) -> Void) -> Bool {
        let profile = profiles.current() ?? Profile(id: userID)
        change(profile)
        do {
            try profiles.save(profile)
            writeFailed = false
            return true
        } catch {
            Log.data.error("Pre-Season write did not persist: \(error.localizedDescription, privacy: .public)")
            writeFailed = true
            return false
        }
    }

    // MARK: - Numbers as text

    /// Accepts either decimal separator.
    ///
    /// The field uses a decimal keypad, and on a keypad the separator is
    /// whatever the device's region says it is — so a German phone sends `78,4`
    /// and `Double("78,4")` is nil. A height silently refusing to parse is a
    /// primary button that never enables and never says why.
    static func number(from text: String) -> Double? {
        let normalised = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return normalised.isEmpty ? nil : Double(normalised)
    }

    /// Back out again, without a trailing `.0` on a whole number.
    static func text(from value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    // MARK: - Completion, as the shell asks it

    /// Whether Pre-Season has everything. The profile's own values plus a weight
    /// reading, because the reading lives in another table.
    static func isComplete(
        profiles: any ProfileRepositoryProtocol,
        weights: any WeightRepositoryProtocol
    ) -> Bool {
        guard let profile = profiles.current(), profile.hasCompletedPreSeason else { return false }
        return !weights.recent(limit: 1).isEmpty
    }
}
