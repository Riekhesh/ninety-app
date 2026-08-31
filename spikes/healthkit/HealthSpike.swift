//
//  HealthSpike.swift
//  Spike A — prove HealthKit read access works on a real device (§0.7)
//
//  THROWAWAY CODE. §0.7: "Write it fast, learn what you need, then delete it — do
//  not let spike code become the foundation of the real app." The things worth
//  carrying into Phase 1 are listed at the bottom of this file.
//
//  Heavily commented because this is likely to be among the first Swift you write.
//  Every non-obvious line says why, not just what.
//

import Foundation
import HealthKit
import os

// MARK: - What the spike reads

/// The three types §0.7 asks the spike to prove, plus the two Phase 1 also needs.
///
/// `HKQuantityType(.bodyMass)` is the modern initialiser (iOS 16+). Older tutorials
/// use `HKObjectType.quantityType(forIdentifier:)!` — note the force-unwrap, which
/// is exactly the kind of thing `force_unwrap` in our SwiftLint config exists to
/// stop. The new form is non-optional, so there is nothing to unwrap.
enum SpikeType: String, CaseIterable, Identifiable {
    case bodyMass
    case stepCount
    case activeEnergy
    case exerciseTime
    case workouts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bodyMass: "Weight"
        case .stepCount: "Steps"
        case .activeEnergy: "Active energy"
        case .exerciseTime: "Exercise minutes"
        case .workouts: "Workouts"
        }
    }

    /// The HealthKit object type. Workouts are an `HKWorkoutType`, not a quantity —
    /// which is why this returns the `HKObjectType` supertype.
    var objectType: HKObjectType {
        switch self {
        case .bodyMass: HKQuantityType(.bodyMass)
        case .stepCount: HKQuantityType(.stepCount)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        case .exerciseTime: HKQuantityType(.appleExerciseTime)
        case .workouts: HKObjectType.workoutType()
        }
    }

    var quantityType: HKQuantityType? {
        objectType as? HKQuantityType
    }

    /// How daily values combine.
    ///
    /// Steps and energy are **cumulative** — you add up the day. Weight is
    /// **discrete** — you average the readings, because summing three weigh-ins
    /// would give you 235 kg. Getting this backwards is the single most common
    /// HealthKit mistake and it produces numbers that look plausible at a glance.
    var statisticsOption: HKStatisticsOptions {
        switch self {
        case .bodyMass: .discreteAverage
        case .stepCount, .activeEnergy, .exerciseTime: .cumulativeSum
        case .workouts: []
        }
    }

    var unit: HKUnit {
        switch self {
        case .bodyMass: .gramUnit(with: .kilo)
        case .stepCount: .count()
        case .activeEnergy: .kilocalorie()
        case .exerciseTime: .minute()
        case .workouts: .count()
        }
    }

    var unitLabel: String {
        switch self {
        case .bodyMass: "kg"
        case .stepCount: "steps"
        case .activeEnergy: "kcal"
        case .exerciseTime: "min"
        case .workouts: "workouts"
        }
    }
}

// MARK: - Results

struct DailyValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// What one type's read produced.
///
/// Note `isEmpty` is a **first-class, non-error state**, not a failure. §0.7:
/// *"iOS deliberately will not tell you whether the user denied read access — this
/// is an anti-fingerprinting measure, since knowing a user hid their heart data is
/// itself information. You will get back an empty result set that looks identical
/// to 'this user has no data.'"*
struct TypeReadResult: Identifiable {
    let type: SpikeType
    let days: [DailyValue]
    let sampleCount: Int
    let anchorPersisted: Bool
    let error: String?

    var id: String { type.rawValue }
    var isEmpty: Bool { days.isEmpty && sampleCount == 0 }
}

// MARK: - The spike

@MainActor
@Observable
final class HealthSpike {

    private let store = HKHealthStore()
    private let log = Logger(subsystem: "com.ninety.spike.healthkit", category: "read")

    var isAvailable = HKHealthStore.isHealthDataAvailable()
    var didRequestAuthorisation = false
    var results: [TypeReadResult] = []
    var statusLine = "Ready."
    var isWorking = false

    /// Anchors survive app launches. This is the whole trick (§1.4): with a stored
    /// anchor, the next query returns only what changed since last time, instead of
    /// re-reading two years of step data on every cold start. That is the difference
    /// between an app that opens instantly and one that hangs for four seconds.
    ///
    /// `UserDefaults` is fine for a spike. In Phase 1 the anchor belongs in the
    /// `health_samples.hk_anchor` column so it lives with the data it describes.
    private let anchorStore = AnchorStore()

    // MARK: Authorisation

    /// Ask for read access to all five types.
    ///
    /// **What this call does and does not tell you.** It throws if the request could
    /// not be presented at all (no entitlement, unavailable device). It does NOT
    /// report whether the user granted anything — `authorizationStatus(for:)` is
    /// meaningful for *write* access only. For reads, the only signal you ever get
    /// is data or no data, and those are indistinguishable.
    ///
    /// Design consequence: there is no "permission denied" branch to write. Build
    /// the no-data state as normal, from the start.
    func requestAuthorisation() async {
        guard isAvailable else {
            statusLine = "HealthKit is not available on this device."
            return
        }

        let readTypes = Set(SpikeType.allCases.map(\.objectType))

        do {
            // Empty `toShare` — the spike only reads. Asking to write would also
            // require NSHealthUpdateUsageDescription in Info.plist.
            try await store.requestAuthorization(toShare: [], read: readTypes)
            didRequestAuthorisation = true
            statusLine = """
                Authorisation sheet completed. iOS will not say what you granted — \
                that is by design. Read some data to find out.
                """
            log.info("Authorisation request completed")
        } catch {
            // A failure here almost always means the HealthKit capability is missing
            // from the target, or NSHealthShareUsageDescription is missing from
            // Info.plist. See README.md step 4.
            statusLine = "Authorisation request failed: \(error.localizedDescription)"
            log.error("Authorisation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Reading

    /// Read the last `days` days for every type, and print to the console — which is
    /// §0.7's actual exit condition for this spike.
    func readRecentHistory(days: Int = 30) async {
        guard isAvailable else { return }
        isWorking = true
        defer { isWorking = false }

        statusLine = "Reading \(days) days…"
        var collected: [TypeReadResult] = []

        for type in SpikeType.allCases {
            let result = await read(type: type, days: days)
            collected.append(result)
            printToConsole(result, days: days)
        }

        results = collected

        let withData = collected.filter { !$0.isEmpty }
        statusLine = withData.isEmpty
            ? "No data for any type. Either nothing is recorded, or read access was "
              + "declined — iOS will not tell you which. This is a normal state."
            : "\(withData.count) of \(collected.count) types returned data."
    }

    private func read(type: SpikeType, days: Int) async -> TypeReadResult {
        // Anchored query first: this is the incremental path Phase 1 will use, so
        // the spike proves it works AND that the anchor round-trips through storage.
        var sampleCount = 0
        var anchorPersisted = false
        var errorText: String?

        do {
            let anchorResult = try await runAnchoredQuery(for: type)
            sampleCount = anchorResult.added
            anchorPersisted = anchorResult.savedAnchor
        } catch {
            errorText = error.localizedDescription
            log.error("\(type.rawValue) anchored query: \(error.localizedDescription, privacy: .public)")
        }

        // Then a statistics collection for the daily buckets we want to display.
        // Workouts are not a quantity type, so they have no statistics collection —
        // the anchored count above is the whole story for them.
        var daily: [DailyValue] = []
        if type.quantityType != nil {
            do {
                daily = try await runDailyStatistics(for: type, days: days)
            } catch {
                errorText = errorText ?? error.localizedDescription
            }
        }

        return TypeReadResult(
            type: type,
            days: daily,
            sampleCount: sampleCount,
            anchorPersisted: anchorPersisted,
            error: errorText
        )
    }

    /// The incremental read Phase 1 depends on (§1.4).
    ///
    /// `HKAnchoredObjectQueryDescriptor` is the modern async form. Pass the saved
    /// anchor and you get back only what has been added or deleted since — plus a
    /// new anchor to save. **Deletions matter**: a user correcting a mis-typed weight
    /// shows up here as a deleted object, and an app that only handles additions
    /// silently keeps the wrong value forever.
    ///
    /// **Why this branches instead of building one predicate.** `HKSamplePredicate`
    /// is generic over the sample it matches: `.quantitySample(type:)` produces
    /// `HKSamplePredicate<HKQuantitySample>` and `.workout()` produces
    /// `HKSamplePredicate<HKWorkout>`. They are different types, so they cannot be
    /// assigned to one `HKSamplePredicate<HKSample>` variable — and the descriptor
    /// carries that generic through to its result, which is the point: the compiler
    /// knows `addedSamples` is `[HKQuantitySample]` on one path and `[HKWorkout]` on
    /// the other. Erasing that to `HKSample` would throw away the typing that makes
    /// the modern API worth using.
    private func runAnchoredQuery(for type: SpikeType) async throws -> (added: Int, savedAnchor: Bool) {
        let saved = anchorStore.load(for: type.rawValue)

        let added: Int
        let deleted: Int
        let newAnchor: HKQueryAnchor

        if let quantityType = type.quantityType {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.quantitySample(type: quantityType)],
                anchor: saved,
                limit: nil
            )
            let result = try await descriptor.result(for: store)
            added = result.addedSamples.count
            deleted = result.deletedObjects.count
            newAnchor = result.newAnchor
        } else {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.workout()],
                anchor: saved,
                limit: nil
            )
            let result = try await descriptor.result(for: store)
            added = result.addedSamples.count
            deleted = result.deletedObjects.count
            newAnchor = result.newAnchor
        }

        // `newAnchor` is NON-optional on the async descriptor — unlike the older
        // callback-based HKAnchoredObjectQuery, where it was optional and every
        // tutorial wraps it in `if let`. A query that ran always yields an anchor,
        // so there is nothing to unwrap and nothing to compare against nil.
        anchorStore.save(newAnchor, for: type.rawValue)

        log.info("""
            \(type.rawValue, privacy: .public): \
            +\(added) added, \
            -\(deleted) deleted
            """)

        return (added, true)
    }

    /// Daily buckets for display.
    ///
    /// The anchor date is set to **local midnight**, not "now minus N days". Buckets
    /// anchored to an arbitrary time of day split each day across two buckets, which
    /// is a genuinely confusing bug to chase — and it foreshadows the timezone
    /// handling the ranking engine needs (§2.4 lists timezone abuse as an exploit).
    private func runDailyStatistics(for type: SpikeType, days: Int) async throws -> [DailyValue] {
        guard let quantityType = type.quantityType else { return [] }

        let calendar = Calendar.current
        let endOfToday = calendar.startOfDay(for: .now).addingTimeInterval(86_400)
        guard let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: .now)) else {
            return []
        }

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: quantityType,
                predicate: HKQuery.predicateForSamples(withStart: start, end: endOfToday)
            ),
            options: type.statisticsOption,
            anchorDate: calendar.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )

        let collection = try await descriptor.result(for: store)

        var values: [DailyValue] = []
        collection.enumerateStatistics(from: start, to: endOfToday) { statistics, _ in
            let quantity = switch type.statisticsOption {
            case .cumulativeSum: statistics.sumQuantity()
            default: statistics.averageQuantity()
            }
            // No entry rather than a zero: a day with no weigh-in is not 0 kg, and
            // a day with no step data is not 0 steps. Conflating "absent" with
            // "zero" is how you end up telling someone they walked 0 steps on a day
            // their phone was charging.
            if let quantity {
                values.append(
                    DailyValue(date: statistics.startDate, value: quantity.doubleValue(for: type.unit))
                )
            }
        }
        return values
    }

    // MARK: Console output — §0.7's exit condition

    private func printToConsole(_ result: TypeReadResult, days: Int) {
        // print() is fine here. It is a warning in the real app (`no_print` in
        // .swiftlint.yml) because print() cannot be filtered by subsystem and does
        // not survive into a shipped build — but this is a throwaway spike whose
        // entire purpose is console output.
        print("\n── \(result.type.label) — last \(days) days ──")

        if let error = result.error {
            print("   error: \(error)")
        }

        print("   anchored query: \(result.sampleCount) new sample(s), "
              + "anchor \(result.anchorPersisted ? "saved" : "NOT saved")")

        guard !result.days.isEmpty else {
            print("   no daily values.")
            print("   ↳ Either there is nothing recorded, or read access was declined.")
            print("     iOS deliberately does not distinguish these. Treat as normal.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for day in result.days {
            let value = result.type == .bodyMass
                ? String(format: "%.2f", day.value)
                : String(format: "%.0f", day.value)
            print("   \(formatter.string(from: day.date))  \(value) \(result.type.unitLabel)")
        }

        let total = result.days.reduce(0) { $0 + $1.value }
        let mean = total / Double(result.days.count)
        print("   \(result.days.count) day(s) with data · mean "
              + String(format: "%.1f", mean) + " \(result.type.unitLabel)")
    }

    func resetAnchors() {
        anchorStore.clear()
        statusLine = "Anchors cleared. The next read re-fetches full history — "
            + "which is exactly the slow path a persisted anchor avoids."
    }
}

// MARK: - Anchor persistence

/// Store `HKQueryAnchor` across launches.
///
/// `HKQueryAnchor` is an opaque `NSSecureCoding` object, so it is archived rather
/// than stored as a value. `requiringSecureCoding: true` on the way out and an
/// explicit class on the way in — the unarchiver must be told what it is allowed to
/// decode, which is the point of secure coding.
private struct AnchorStore {
    private let defaults = UserDefaults.standard
    private let prefix = "spike.hk.anchor."

    func load(for key: String) -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: prefix + key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    func save(_ anchor: HKQueryAnchor, for key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: anchor, requiringSecureCoding: true
        ) else { return }
        defaults.set(data, forKey: prefix + key)
    }

    func clear() {
        for type in SpikeType.allCases {
            defaults.removeObject(forKey: prefix + type.rawValue)
        }
    }
}

// MARK: - What to keep from this spike
//
// Delete this file at the end of Phase 0. Carry forward only:
//
//  1. The type list and, critically, the cumulative-vs-discrete mapping. Getting
//     bodyMass wrong (summing instead of averaging) produces plausible nonsense.
//  2. The anchored-query + persisted-anchor pattern. §1.4 calls this "the entire
//     trick", and it is.
//  3. Deletion handling. `result.deletedObjects` is not optional to handle.
//  4. Local-midnight bucketing for daily statistics.
//  5. The conclusion that drives real design work: **there is no permission-denied
//     branch.** Empty is normal. Phase 1's repositories must return an empty result
//     rather than throwing, and every data surface needs a designed empty state
//     (docs/design/00-design-principles.md, principle 5).
//
// What Phase 1 adds that this spike deliberately skips:
//  · HKObserverQuery + enableBackgroundDelivery(for:frequency:) for updates while
//    the app is backgrounded
//  · the anchor moving from UserDefaults to health_samples.hk_anchor
//  · protocol-based repository wrapping, so ViewModels can be tested with a mock
