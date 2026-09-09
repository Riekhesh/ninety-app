import Foundation
import Testing
@testable import Ninety

/// P1-F — what comes back from the Edge Function, and what is done to it before
/// the UI is allowed to see it.
///
/// *"Structured output validated before it reaches the UI; a malformed response
/// degrades to manual entry."* Structured outputs constrain the response's
/// shape, not its sense — the schema carries no numeric constraints because they
/// are unsupported — so every case here is one the model can produce while
/// satisfying its own schema.
@Suite("Meal estimates")
struct MealEstimateTests {
    /// One item, written as the JSON the Edge Function actually returns.
    ///
    /// A string rather than a `[String: Any]`, for two reasons that point the
    /// same way. `[String: Any]` is not `Sendable`, so it cannot be a stored
    /// `static` under Swift 6 at all. And the thing under test is a **decoder**:
    /// feeding it bytes is the path the app takes, where handing it
    /// `JSONSerialization` output of a dictionary would test a round trip
    /// through Foundation as much as the type.
    static func item(
        name: String = "porridge with milk",
        gramsLow: Int = 200,
        gramsHigh: Int = 280,
        kcalLow: Int = 290,
        kcalHigh: Int = 390,
        confidence: String = "high"
    ) -> String {
        """
        {"name": "\(name)", "grams_low": \(gramsLow), "grams_high": \(gramsHigh), \
        "kcal_low": \(kcalLow), "kcal_high": \(kcalHigh), "confidence": "\(confidence)"}
        """
    }

    static func payload(
        _ items: [String],
        notes: String = "",
        model: String = "gemini-3.5-flash-lite"
    ) throws -> MealEstimatePayload {
        let json = """
            {"items": [\(items.joined(separator: ","))], "notes": "\(notes)", \
            "model": "\(model)", "storage_path": "abc/meal.jpg"}
            """
        return try JSONDecoder().decode(MealEstimatePayload.self, from: Data(json.utf8))
    }

    // MARK: - Ranges

    /// **The range renders as a figure plus a tolerance, never as two numbers
    /// joined by a dash.** `PRODUCT.md` and the Under Review ticket both say so:
    /// `290–390` reads as a rule about where to stay; `340 ±50` reads as an
    /// estimate with slack, which is what it is.
    @Test("a range renders as a figure and a tolerance, never as a dash")
    func rangeRendersAsToleranceNotADash() {
        let rendered = Figure.range(EstimateRange(low: 290, high: 390))
        #expect(rendered == "340 ±50")

        for dash in ["–", "—", "-", " to "] {
            #expect(!rendered.contains(dash), "the range form must not join two numbers with \"\(dash)\"")
        }
    }

    @Test("a range with no spread drops the tolerance rather than printing ±0")
    func exactRangeHasNoTolerance() {
        #expect(Figure.range(.exact(233)) == "233")
    }

    @Test("an inverted range is repaired rather than rendered upside down")
    func invertedRangeIsRepaired() {
        let range = EstimateRange(low: 390, high: 290)
        #expect(range.low == 290)
        #expect(range.high == 390)
        #expect(range.centre == 340)
    }

    @Test("a negative bound is clamped")
    func negativeBoundIsClamped() {
        #expect(EstimateRange(low: -40, high: 100).low == 0)
    }

    // MARK: - Validation

    @Test("a well-formed response passes through")
    func wellFormedResponseValidates() throws {
        let estimate = try Self.payload([Self.item()]).validated(rawOutput: Data(), latency: 2.0)
        #expect(estimate.items.count == 1)
        #expect(estimate.items[0].confidence == .high)
        #expect(estimate.items[0].kcal.centre == 340)
        // The screen starts on the midpoint — the app's best guess, presented as
        // one, and never as a fact.
        #expect(estimate.items[0].confirmedKcal == 340)
        #expect(!estimate.items[0].wasCorrected)
    }

    @Test("an unknown confidence level becomes medium rather than throwing")
    func unknownConfidenceBecomesMedium() throws {
        let estimate = try Self.payload([Self.item(confidence: "certain")])
            .validated(rawOutput: Data(), latency: 1)
        #expect(estimate.items[0].confidence == .medium)
    }

    @Test("one unusable item does not lose the rest of the meal")
    func oneBadItemDoesNotLoseTheMeal() throws {
        // A name that is only whitespace, and an item whose whole energy range
        // is zero. Both satisfy the schema — it carries no numeric constraints
        // and cannot — and neither is something a user can confirm or correct.
        let nameless = Self.item(name: "   ")
        let weightless = Self.item(kcalLow: 0, kcalHigh: 0)

        let estimate = try Self.payload([Self.item(), nameless, weightless])
            .validated(rawOutput: Data(), latency: 1)
        #expect(estimate.items.count == 1)
    }

    /// The one refusal. There is nothing to confirm and nothing to correct, so
    /// the honest answer is that the photo did not work — not an empty Under
    /// Review screen with a button that logs nothing.
    @Test("a response with nothing usable in it degrades to manual entry")
    func emptyResponseIsRefused() throws {
        let payload = try Self.payload([])
        #expect(throws: MealEstimateError.malformedResponse) {
            try payload.validated(rawOutput: Data(), latency: 1)
        }
    }

    @Test("the raw output is kept exactly as it arrived")
    func rawOutputIsKeptWhole() throws {
        // Re-encoding from the parsed values would leave the benchmark
        // re-scoring the app's idea of the answer rather than the model's.
        let raw = Data(#"{"items":[{"name":"porridge with milk"}],"notes":"oil unknown"}"#.utf8)
        let estimate = try Self.payload([Self.item()]).validated(rawOutput: raw, latency: 1)
        #expect(estimate.rawOutput == raw)
    }

    @Test("the model id survives, because a measurement is attributed to one")
    func modelIDSurvives() throws {
        let estimate = try Self.payload([Self.item()], model: "gemini-3.5-flash-lite")
            .validated(rawOutput: Data(), latency: 2.7)
        #expect(estimate.model == "gemini-3.5-flash-lite")
        #expect(estimate.latency == 2.7)
    }

    @Test("the meal total adds the tolerances rather than narrowing them")
    func totalAddsTolerances() throws {
        let second = Self.item(name: "banana", kcalLow: 90, kcalHigh: 120)
        let estimate = try Self.payload([Self.item(), second])
            .validated(rawOutput: Data(), latency: 1)
        // 290+90 .. 390+120. The errors on two items of one meal are not
        // independent — one badly judged plate size moves both the same way —
        // so a total narrower than its parts would be false confidence.
        #expect(estimate.total.low == 380)
        #expect(estimate.total.high == 510)
        #expect(estimate.total.centre == 445)
    }

    // MARK: - Confidence

    @Test("low confidence carries the sentence that tells the user to look")
    func lowConfidenceCarriesItsNote() {
        #expect(EstimateConfidence.low.note == SubOnCopy.lowConfidence)
        #expect(EstimateConfidence.medium.note == nil)
        #expect(EstimateConfidence.high.note == nil)
    }

    @Test("confidence is ordered, and its encoding is ordinal rather than a probability")
    func confidenceIsOrdinal() {
        #expect(EstimateConfidence.low < EstimateConfidence.medium)
        #expect(EstimateConfidence.medium < EstimateConfidence.high)
        #expect(EstimateConfidence.allCases.map(\.ordinal) == [0, 0.5, 1])
    }

    // MARK: - The downscale

    /// §1.3: about 1,024 px on the longest edge before upload. The bytes that
    /// cost the user time are the ones going up.
    @Test("a large photo is scaled to the long edge, keeping its shape")
    func largePhotoIsScaled() {
        let fitted = MealPhoto.fittedSize(for: CGSize(width: 4_032, height: 3_024))
        #expect(fitted.width == 1_024)
        #expect(fitted.height == 768)
    }

    @Test("a portrait photo is scaled on its height")
    func portraitScalesOnHeight() {
        let fitted = MealPhoto.fittedSize(for: CGSize(width: 3_024, height: 4_032))
        #expect(fitted.height == 1_024)
        #expect(fitted.width == 768)
    }

    /// A small image scaled *up* is more bytes carrying no more information: the
    /// model sees the same picture and the upload takes twice as long.
    @Test("a small photo is left alone")
    func smallPhotoIsNotUpscaled() {
        let size = CGSize(width: 600, height: 400)
        #expect(MealPhoto.fittedSize(for: size) == size)
    }

    @Test("a degenerate size does not divide by zero")
    func zeroSizedImageIsSurvivable() {
        #expect(MealPhoto.fittedSize(for: .zero) == .zero)
    }

    // MARK: - Failure states

    /// Every failure on this route leaves the other three intact. §1.3 frames
    /// the photo estimate as a helper, so losing it costs a shortcut and never a
    /// day's logging.
    @Test("every photo failure offers a way to log anyway")
    func everyFailureHasAWayForward() {
        for error in [
            MealEstimateError.notSignedIn,
            .offline,
            .dailyCapReached,
            .malformedResponse,
            .unavailable,
        ] {
            #expect(error.errorDescription?.isEmpty == false)
            #expect(error.recoveryDescription == SubOnCopy.estimateFallback)
        }
    }

    /// §10's cap: *"hitting it produces calm copy and an intact manual path, not
    /// an error."*
    @Test("the daily cap reads as a limit rather than as a fault")
    func capCopyIsCalm() throws {
        let copy = try #require(MealEstimateError.dailyCapReached.errorDescription)
        for accusation in ["failed", "error", "too many", "blocked", "denied"] {
            #expect(!copy.lowercased().contains(accusation))
        }
    }
}
