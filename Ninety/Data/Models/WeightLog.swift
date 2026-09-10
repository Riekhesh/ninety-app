import Foundation
import SwiftData

/// One weigh-in. Mirrors `public.weight_logs`.
///
/// Raw daily weight is stored but is never the headline. §1.5: daily weight is
/// mostly water, glycogen and gut content, and showing it raw produces a jagged
/// line that makes a genuinely successful week look like failure — one of the
/// main reasons people abandon weight-loss apps in the first fortnight. The
/// 7-day EWMA is the series; this is what feeds it.
@Model
final class WeightLog {
    @Attribute(.unique)
    var id: UUID
    var userID: UUID
    var createdAt: Date
    var updatedAt: Date

    var measuredAt: Date
    var kg: Double
    var sourceRaw: String

    init(
        id: UUID = UUID(),
        userID: UUID,
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast,
        measuredAt: Date,
        kg: Double,
        source: WeightSource = .manual
    ) {
        self.id = id
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.measuredAt = measuredAt
        self.kg = kg
        self.sourceRaw = source.rawValue
    }
}

extension WeightLog {
    var source: WeightSource {
        get { WeightSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// The row as the pure code sees it.
    ///
    /// `WeightTrend` and `WeightReconciliation` are both pure and neither may
    /// touch SwiftData — the trend because Phase 2's progress score will read
    /// the same series out of `Packages/RankingEngine`, which the purity lint
    /// forbids from importing persistence at all, and the reconciliation because
    /// a duplicate rule that needs a store to test is a rule nobody tests. This
    /// is the one line that crosses between them.
    var weighIn: WeighIn { WeighIn(measuredAt: measuredAt, kg: kg) }
}
