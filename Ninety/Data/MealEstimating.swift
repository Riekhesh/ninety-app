import Foundation

/// The photo route's one dependency, as a protocol.
///
/// ADR 0010: the provider sits behind an interface so swapping arms costs
/// nothing. The interface is here rather than at the model — the app never sees
/// a provider at all, because the key that would let it is the one thing §04
/// refuses to put in a client binary. What the app swaps is *where the estimate
/// comes from*: an Edge Function, or a mock in a test and a preview.
@MainActor
protocol MealEstimating {
    /// Upload, estimate, validate. The JPEG is already downscaled.
    func estimate(jpeg: Data) async throws -> MealEstimate
}

/// The wire shape, exactly as `supabase/functions/estimate-meal` returns it.
///
/// A separate type from `MealEstimate` on purpose. This one is `Decodable` and
/// believes nothing; the validated one is what the UI is allowed to see. The
/// step between them is `validated(rawOutput:latency:)`, and it is
/// the ticket's *"structured output validated before it reaches the UI"*.
///
/// Structured outputs constrain the response's **shape**; they cannot constrain
/// its **sense**. The schema in `spikes/vision-accuracy/ninetyvision/schema.py`
/// says so in as many words — numeric constraints are unsupported — so `low >
/// high`, a negative bound and an unknown confidence string all have to be
/// caught on this side. They are repaired rather than rejected, the same way the
/// spike's `parse_estimate` repairs them, and for the same reason: throwing away
/// four good items because of one bad field is a worse outcome than a repaired
/// range and a recorded warning.
struct MealEstimatePayload: Decodable, Equatable, Sendable {
    struct Item: Decodable, Equatable, Sendable {
        let name: String
        let gramsLow: Double
        let gramsHigh: Double
        let kcalLow: Double
        let kcalHigh: Double
        let confidence: String

        enum CodingKeys: String, CodingKey {
            case name
            case gramsLow = "grams_low"
            case gramsHigh = "grams_high"
            case kcalLow = "kcal_low"
            case kcalHigh = "kcal_high"
            case confidence
        }
    }

    let items: [Item]
    let notes: String
    let model: String
    let storagePath: String

    enum CodingKeys: String, CodingKey {
        case items
        case notes
        case model
        case storagePath = "storage_path"
    }

    /// Turns the wire shape into something the UI may render, or refuses.
    ///
    /// The one refusal is an estimate with **no usable item in it**. There is
    /// nothing to confirm and nothing to correct, so the honest move is to say
    /// the photo did not work and leave the user on manual entry — rather than
    /// draw an empty Under Review screen and let them press a button that logs
    /// nothing.
    func validated(rawOutput: Data, latency: TimeInterval) throws -> MealEstimate {
        // Named rather than shadowing `items`: a local `let items = items…`
        // is the "variable used within its own initial value" trap, and it is
        // the kind that reads as correct.
        let validated: [EstimatedItem] = items.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let kcal = EstimateRange(low: item.kcalLow, high: item.kcalHigh)
            // A zero-energy item is not an estimate, it is a gap in one. It
            // would render as `0 ±0` and read as a fact.
            guard kcal.high > 0 else { return nil }

            return EstimatedItem(
                name: name,
                grams: EstimateRange(low: item.gramsLow, high: item.gramsHigh),
                kcal: kcal,
                // An unrecognised level becomes `medium` rather than throwing.
                // The spike does the same, and the reason is that this field
                // drives a chip and a sentence, not a decision the app cannot
                // make without it.
                confidence: EstimateConfidence(rawValue: item.confidence.lowercased()) ?? .medium
            )
        }

        guard !validated.isEmpty else { throw MealEstimateError.malformedResponse }

        return MealEstimate(
            items: validated,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            storagePath: storagePath,
            rawOutput: rawOutput,
            model: model,
            latency: latency
        )
    }
}

#if DEBUG
/// A fixed estimate, for tests and for the Under Review preview.
///
/// The numbers are `Var.dc.html`'s, so the preview renders the artboard rather
/// than something invented to fill the space.
@MainActor
final class MockMealEstimator: MealEstimating {
    var result: Result<MealEstimate, MealEstimateError>
    private(set) var calls = 0

    init(result: Result<MealEstimate, MealEstimateError> = .success(.artboard)) {
        self.result = result
    }

    func estimate(jpeg: Data) async throws -> MealEstimate {
        calls += 1
        return try result.get()
    }
}

extension MealEstimate {
    /// The three items on `design/redesign/Var.dc.html`.
    static var artboard: MealEstimate {
        MealEstimate(
            items: [
                EstimatedItem(
                    name: "Greek yogurt",
                    grams: EstimateRange(low: 155, high: 185),
                    kcal: EstimateRange(low: 116, high: 140),
                    confidence: .high
                ),
                EstimatedItem(
                    name: "Blueberries",
                    grams: EstimateRange(low: 70, high: 100),
                    kcal: EstimateRange(low: 32, high: 64),
                    confidence: .medium
                ),
                EstimatedItem(
                    name: "Honey drizzle",
                    grams: EstimateRange(low: 6, high: 30),
                    kcal: EstimateRange(low: 23, high: 91),
                    confidence: .low
                ),
            ],
            notes: "The honey is partly hidden, and there may be more under the fruit.",
            storagePath: "preview/meal.jpg",
            rawOutput: Data("{}".utf8),
            model: "preview",
            latency: 2.4
        )
    }
}
#endif
