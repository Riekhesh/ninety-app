import Foundation
import SwiftData

/// What the vision model guessed, and what the user corrected it to.
/// Mirrors `public.photo_estimates`.
///
/// ADR 0010: an estimate is never silently accepted. `wasCorrected` and
/// `correctionDelta` are not analytics — §1.3 calls this dataset a real
/// proprietary asset, and it is how the prompt gets better later.
@Model
final class PhotoEstimate {
    @Attribute(.unique)
    var id: UUID
    var userID: UUID
    var createdAt: Date
    var updatedAt: Date

    /// Path inside the private meal-photos bucket, always `<user-id>/<file>`.
    /// The first path segment is what the storage policies check.
    var storagePath: String

    /// The model's structured output, kept whole. Re-reading old estimates
    /// against a new prompt is only possible if the original survived.
    var modelOutput: Data

    /// 0...1, surfaced as HIGH / MEDIUM / LOW. A range and a confidence, never
    /// a single number presented as a fact.
    var confidence: Double?

    var wasCorrected: Bool
    var correctionDelta: Double?

    var log: FoodLog?

    init(
        id: UUID = UUID(),
        userID: UUID,
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast,
        storagePath: String,
        modelOutput: Data,
        confidence: Double? = nil,
        wasCorrected: Bool = false,
        correctionDelta: Double? = nil,
        log: FoodLog? = nil
    ) {
        self.id = id
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.storagePath = storagePath
        self.modelOutput = modelOutput
        self.confidence = confidence
        self.wasCorrected = wasCorrected
        self.correctionDelta = correctionDelta
        self.log = log
    }
}
