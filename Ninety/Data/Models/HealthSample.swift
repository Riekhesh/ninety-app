import Foundation
import SwiftData

/// One day of HealthKit, already bucketed. Mirrors `public.health_samples`.
///
/// One row per day, never one per sample. Phase 0 measured ~1,830 step samples
/// and ~3,000 active-energy samples *per day* on a real device: iterating raw
/// samples for a daily total is the mistake this shape exists to prevent.
/// `HKStatisticsCollectionQuery` buckets inside HealthKit and hands back 31
/// values instead of 56,764 objects.
@Model
final class HealthSample {
    @Attribute(.unique)
    var id: UUID
    var userID: UUID
    var createdAt: Date
    var updatedAt: Date

    /// The user's local calendar day, normalised to its start. A day is what
    /// HealthKit buckets by and what the consistency score counts.
    var day: Date

    var steps: Int?
    var activeEnergy: Double?
    var exerciseMinutes: Int?
    var workoutCount: Int

    /// The persisted `HKAnchoredObjectQuery` anchor. §1.4 calls this "the
    /// entire trick": without it every cold start re-queries full history,
    /// which measured as a four-second hang on a device with two years of data.
    var anchor: Data?

    init(
        id: UUID = UUID(),
        userID: UUID,
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast,
        day: Date,
        steps: Int? = nil,
        activeEnergy: Double? = nil,
        exerciseMinutes: Int? = nil,
        workoutCount: Int = 0,
        anchor: Data? = nil
    ) {
        self.id = id
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.day = day
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.exerciseMinutes = exerciseMinutes
        self.workoutCount = workoutCount
        self.anchor = anchor
    }
}
