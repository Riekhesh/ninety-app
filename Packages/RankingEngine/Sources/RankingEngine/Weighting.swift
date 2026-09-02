/// The weighting of the composite score (§2.2).
///
/// Phase 2 owns the maths. Phase 1 owns only this: the shape of the score, and
/// the fact that the weights are data rather than three constants scattered
/// through a function. The Table publishes them to the user from day one,
/// because a rank whose workings only appear once it is flattering is not a
/// fair rank.
///
///     S = wc·C + wa·A + wp·P
///
public struct Weighting: Equatable, Sendable {
    /// Consistency. Weighted highest on purpose (ADR 0008): showing up is both
    /// the better predictor and the part the user actually controls.
    public let consistency: Double

    /// Adherence — days landing inside the calorie band.
    public let adherence: Double

    /// Normalised progress, against what someone of this size would expect.
    public let progress: Double

    public init(consistency: Double, adherence: Double, progress: Double) {
        self.consistency = consistency
        self.adherence = adherence
        self.progress = progress
    }

    /// The v1 weighting. Not final — ADR 0008 records what would move it.
    public static let v1 = Weighting(consistency: 0.50, adherence: 0.25, progress: 0.25)

    /// Weights must sum to 1, or the composite stops being comparable between
    /// two users — which is the entire premise of a normalised rank.
    public var isNormalised: Bool {
        abs(consistency + adherence + progress - 1) < 1e-9
    }
}
