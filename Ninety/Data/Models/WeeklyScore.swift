import Foundation
import SwiftData

/// A week's rank. Mirrors `public.weekly_scores`.
///
/// Phase 2 computes these; Phase 1 only has to store them, and the shape is
/// settled now so that when the engine arrives it writes somewhere that already
/// exists.
@Model
final class WeeklyScore {
    @Attribute(.unique)
    var id: UUID
    var userID: UUID
    var createdAt: Date
    var updatedAt: Date

    var weekStart: Date

    var consistency: Double?
    var adherence: Double?
    var progress: Double?
    var composite: Double?
    var tierRaw: Int?

    /// Not optional, and the brief is emphatic about why: retune the weights —
    /// and you will — and without this every historical score is meaningless,
    /// because you cannot tell which version produced which number.
    var engineVersion: String

    /// §2.3 plausibility flags. Flag, never reject: over-aggressive rejection
    /// destroys trust with honest outliers, and there are always more of those
    /// than cheats.
    var flags: Data

    init(
        id: UUID = UUID(),
        userID: UUID,
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast,
        weekStart: Date,
        consistency: Double? = nil,
        adherence: Double? = nil,
        progress: Double? = nil,
        composite: Double? = nil,
        tier: Tier? = nil,
        engineVersion: String,
        flags: Data = Data("{}".utf8)
    ) {
        self.id = id
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.weekStart = weekStart
        self.consistency = consistency
        self.adherence = adherence
        self.progress = progress
        self.composite = composite
        self.tierRaw = tier?.rawValue
        self.engineVersion = engineVersion
        self.flags = flags
    }
}

extension WeeklyScore {
    var tier: Tier? {
        get { tierRaw.flatMap { Tier(rawValue: $0) } }
        set { tierRaw = newValue?.rawValue }
    }
}
