#if canImport(HealthKit)
import Foundation
import HealthKit

/// Body mass, read out of HealthKit.
///
/// **The only file in `Ninety/` that imports HealthKit**, which is what
/// `BodyMassSourcing` is for. Everything above it — the model, the screen, the
/// reconciliation rule, every test — works against the protocol and never learns
/// that the framework exists.
///
/// **This is not P1-E.** That epic reads steps, active energy and exercise
/// minutes, and its whole subject is the finding from Spike A: ~1,830 step
/// samples and ~3,000 active-energy samples *per day*, which is why it must use
/// `HKStatisticsCollectionQuery` and a persisted anchor. Body mass is the
/// opposite shape — a handful of samples a week, each one a discrete event with
/// its own timestamp, and nothing to bucket. A statistics query over it would
/// average a day's weigh-ins inside HealthKit and hand back a number with no
/// instant attached, which is precisely what the duplicate check needs. So this
/// reads samples directly, and the volume that makes that a mistake for steps
/// does not exist here.
///
/// It shares no anchor with P1-E for the same reason: the window is bounded by
/// the last reading Ninety holds, so a re-sync re-reads a few days rather than
/// two years, and `WeightReconciliation` drops what it has already seen.
@MainActor
final class HealthKitBodyMass: BodyMassSourcing {
    private let store: HKHealthStore
    private let bodyMass = HKQuantityType(.bodyMass)

    /// How far back a first sync reaches when the store has no readings at all.
    ///
    /// A year, not everything. A first read exists to give the trend some
    /// back-history — Spike A's one-point trend is the state it is trying to
    /// avoid — and a decade of a smart scale's output is a decade of rows to
    /// push through the outbox for a chart that shows twelve weeks.
    static let firstSyncDays = 365

    init?() {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        self.store = HKHealthStore()
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Read-only. Ninety asks for nothing it does not read.
    ///
    /// The share set is empty, and that is a decision rather than an omission:
    /// writing manual entries back to Apple Health would be a second copy of
    /// Article 9 data in a place the user did not ask Ninety to put it, and the
    /// acceptance criteria do not ask for it. `WeightReconciliation` already
    /// handles the duplicate it would create, so the day that changes it is a
    /// change to this array and nothing else.
    func requestAuthorization() async -> Bool {
        do {
            try await store.requestAuthorization(toShare: [], read: [bodyMass])
            return true
        } catch {
            // The *request* failed — the sheet could not be presented, or the
            // device refuses health data entirely. Not the same as a refusal,
            // which iOS reports as a successful request and an empty read.
            Log.data.error("Health authorization did not complete: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func readings(since moment: Date) async -> [BodyMassReading] {
        guard isAvailable else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: moment, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        do {
            let samples = try await descriptor.result(for: store)
            let thisApp = HKSource.default()
            return samples.map { sample in
                BodyMassReading(
                    // `startDate`, not `endDate`. A body-mass sample is an
                    // instant rather than an interval, and the two are equal for
                    // every writer that behaves — but a writer that does not
                    // would shift the reading onto the wrong day at midnight.
                    measuredAt: sample.startDate,
                    kg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                    isFromThisApp: sample.sourceRevision.source == thisApp
                )
            }
        } catch {
            // Empty, never a throw. `Repositories.swift`'s first rule, and the
            // reason for it: a denied read and an empty store are the same
            // result on iOS, so a failure here has to render as the same empty
            // state rather than as an error the screen cannot justify.
            Log.data.error("Body mass read failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
#endif
