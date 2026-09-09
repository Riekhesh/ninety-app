import Foundation

/// A body-mass sample that arrived from somewhere other than a Ninety screen.
///
/// Smart scales write to HealthKit automatically, which is the entire reason
/// this route exists: the acceptance criterion is that both sources land in
/// `weight_logs` with `source` set correctly, and the cheapest way to get a
/// daily weight out of somebody who owns a scale is not to ask them for one.
struct BodyMassReading: Equatable, Sendable {
    let measuredAt: Date
    let kg: Double

    /// True when Ninety itself wrote this sample. See
    /// `WeightReconciliation.unseen` — it is the first and cleanest of the three
    /// duplicate cases, and the only one that is exact rather than heuristic.
    let isFromThisApp: Bool

    init(measuredAt: Date, kg: Double, isFromThisApp: Bool = false) {
        self.measuredAt = measuredAt
        self.kg = kg
        self.isFromThisApp = isFromThisApp
    }
}

/// Where body mass comes from when it does not come from the keyboard.
///
/// Behind a protocol for the same reason `MealEstimating` is: HealthKit does not
/// exist in a test, on the simulator it exists and is empty, and the app has to
/// behave identically in both. It is also the boundary that keeps `HealthKit`
/// out of every other file in `Ninety/` — the framework is imported in exactly
/// one place.
@MainActor
protocol BodyMassSourcing {
    /// Whether the device can offer this at all. False on a simulator or an
    /// iPad, and the screen says nothing about permissions when it is false —
    /// there is nothing to ask for.
    var isAvailable: Bool { get }

    /// Asks for read access, and returns whether the request itself completed.
    ///
    /// **It does not return whether permission was granted, because iOS does not
    /// tell you.** Phase 0 measured this and it is written into
    /// `Repositories.swift` as a rule: a denied read returns a result identical
    /// to "no data". A method here returning `granted: Bool` would be inventing
    /// a distinction the platform does not have.
    func requestAuthorization() async -> Bool

    /// Every reading since a moment, oldest first. Empty is a normal answer and
    /// covers both "no data" and "not allowed" without claiming either.
    func readings(since moment: Date) async -> [BodyMassReading]
}

/// Which readings a store has not already got.
///
/// The acceptance criterion is one line — *"no duplicate when the same reading
/// arrives both ways"* — and it hides three separate cases. Each is handled
/// distinctly below rather than by one fuzzy comparison, because they fail
/// differently: the first is exact, the second is exact, and only the third is a
/// judgement with a tolerance in it.
enum WeightReconciliation {
    /// Two numbers describing one weigh-in agree to within this.
    ///
    /// A hundred grams. `weight_logs.kg` is `numeric(5, 2)`, scales report to a
    /// tenth or a twentieth, and a person reading a dial rounds to a tenth — so
    /// a scale writing 78.35 and the same person typing 78.4 is one weigh-in
    /// recorded twice, and 78.4 against 78.9 is two. Wider than this starts
    /// swallowing a real morning-to-evening difference; narrower stops catching
    /// the rounding that causes the duplicate in the first place.
    static let sameWeighInToleranceKg = 0.1

    /// The incoming readings that are genuinely new.
    ///
    /// Three filters, in order of how certain they are:
    ///
    /// 1. **Ninety's own samples.** If a later epic writes manual entries back
    ///    to HealthKit, reading them in again would duplicate every one of them
    ///    on the next sync. `HKSource` says who wrote a sample, so this case is
    ///    exact and needs no tolerance. Nothing writes to HealthKit today, which
    ///    makes this filter inert rather than wrong — and inert now is what stops
    ///    the duplicate arriving the day writing lands.
    /// 2. **The same instant, already stored.** A second sync over the same
    ///    window re-offers everything it offered last time. Matched on the exact
    ///    timestamp, whatever source holds it, which is also what
    ///    `weight_logs`' `unique (user_id, measured_at, source)` enforces
    ///    server-side.
    /// 3. **The same day, the same number.** The case the criterion is actually
    ///    about: the user typed this morning's weight into Ninety, and the scale
    ///    wrote the same reading to HealthKit ninety seconds earlier under a
    ///    different timestamp. Two rows, one weigh-in, and only a tolerance can
    ///    tell.
    ///
    /// Deliberately **not** "one reading per day". Somebody who weighs morning
    /// and evening has made two measurements, and the trend takes their mean
    /// (see `WeightTrend.daily`) rather than throwing one away.
    static func unseen(
        _ incoming: [BodyMassReading],
        against existing: [WeighIn],
        calendar: Calendar
    ) -> [BodyMassReading] {
        var kept: [BodyMassReading] = []
        // Grows as the batch is walked, so two duplicates *inside one batch*
        // also collapse — a sync that offers the same sample twice is otherwise
        // two inserts, because neither is in the store when the other is judged.
        var seen = existing

        for reading in incoming.sorted(by: { $0.measuredAt < $1.measuredAt }) {
            if reading.isFromThisApp { continue }
            if seen.contains(where: { $0.measuredAt == reading.measuredAt }) { continue }

            let day = calendar.startOfDay(for: reading.measuredAt)
            let matchesADayReading = seen.contains {
                calendar.startOfDay(for: $0.measuredAt) == day
                    && abs($0.kg - reading.kg) <= sameWeighInToleranceKg
            }
            if matchesADayReading { continue }

            kept.append(reading)
            seen.append(WeighIn(measuredAt: reading.measuredAt, kg: reading.kg))
        }
        return kept
    }
}

#if DEBUG
/// A fixed set of readings, for tests and previews.
@MainActor
final class MockBodyMassSource: BodyMassSourcing {
    var isAvailable: Bool
    var authorized: Bool
    var stored: [BodyMassReading]
    private(set) var authorizationRequests = 0
    private(set) var reads = 0

    init(
        isAvailable: Bool = true,
        authorized: Bool = true,
        readings: [BodyMassReading] = []
    ) {
        self.isAvailable = isAvailable
        self.authorized = authorized
        self.stored = readings
    }

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return authorized
    }

    func readings(since moment: Date) async -> [BodyMassReading] {
        reads += 1
        // Empty when it is not allowed, which is exactly what the real one
        // returns and exactly why the screen cannot tell the two apart.
        guard authorized else { return [] }
        return stored.filter { $0.measuredAt >= moment }.sorted { $0.measuredAt < $1.measuredAt }
    }
}
#endif
