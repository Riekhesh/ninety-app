/// Ninety's ranking engine.
///
/// Pure by construction, and the three SwiftLint rules in `.swiftlint.yml`
/// keep it that way: no UI or persistence imports, no ambient clock, no
/// randomness. Each constraint pays for a later step —
///
///   · **No platform imports** so the module ports to the server unchanged.
///   · **No ambient clock** so timezone abuse, an explicit Phase 2 exploit,
///     can be tested deterministically. The date is a parameter, always.
///   · **No randomness** so the Phase 4 cutover can run identical test vectors
///     against the Swift and server implementations and check they agree.
///
/// Phase 2 fills this in. Phase 1 creates it so the boundary exists and the
/// lint rules have something to police from the first commit (ADR 0006).
public enum RankingEngine {
    /// The weighting the engine scores against until Phase 2 replaces it.
    public static let weighting = Weighting.v1
}
