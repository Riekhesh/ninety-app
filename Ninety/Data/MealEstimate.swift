import Foundation

/// How sure the model says it is about one item.
///
/// Three levels, per item and never per photo. §1.3's reasoning, and the spike
/// schema's: a plate can hold one obvious thing and one ambiguous thing, and a
/// per-photo figure averages exactly the signal the correction screen needs.
///
/// > **Deviation from the artboards, recorded in `DESIGN.md`.** `Var.dc.html`
/// > labels these CLEAR / TIGHT / UNSIGHTED. The build uses the copy deck's
/// > HIGH / MEDIUM / LOW. The world's vocabulary runs through the product
/// > everywhere it costs nothing, and here it costs something: this label is
/// > what tells a user which number to go and check, and "TIGHT" does not say
/// > that to anybody who has not been told what it means. `DESIGN.md`'s Mode
/// > section settles ties the same way — scanability outranks expression on
/// > every screen except The Table.
enum EstimateConfidence: String, Codable, CaseIterable, Sendable, Comparable {
    case low
    case medium
    case high

    /// Sentence case in the string; `ninetyType(.label)` applies the caps, so
    /// VoiceOver reads a word instead of spelling one out.
    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    /// The line a low-confidence item carries. Copy deck §4.
    ///
    /// `safety`-toned rather than `critical`, like every other notice in the
    /// app: the model being unsure is not the user having done something wrong.
    var note: String? {
        self == .low ? SubOnCopy.lowConfidence : nil
    }

    /// **An ordinal encoding, not a probability.** The model emits three levels
    /// and nothing calibrated; mapping them to 0, 0.5 and 1 keeps the ordering
    /// and invents nothing. Anything that looked like a percentage here would be
    /// a number nobody measured, which is the one thing the design principles
    /// rule out outright.
    var ordinal: Double {
        switch self {
        case .low: 0
        case .medium: 0.5
        case .high: 1
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.ordinal < rhs.ordinal }
}

/// A plausible interval, as the model gave it.
///
/// **It renders as a figure plus a tolerance and never as two numbers joined by
/// a dash.** `PRODUCT.md` and the Under Review ticket both say so, and the
/// reason is what each form reads as: `120–160` reads as a rule about where to
/// stay, `140 ±20` reads as an estimate with slack in it, which is what this is.
/// `CalorieBand` renders the same way for the same reason.
struct EstimateRange: Equatable, Sendable {
    let low: Double
    let high: Double

    /// Rounded. A calorie estimate to a decimal place is false precision, and
    /// the lint rule that catches the formatted version agrees.
    var centre: Int { Int(((low + high) / 2).rounded()) }
    var tolerance: Int { Int(((high - low) / 2).rounded()) }

    /// The midpoint unrounded, for arithmetic that then rounds once at the end.
    var midpoint: Double { (low + high) / 2 }

    init(low: Double, high: Double) {
        // Repaired rather than rejected, exactly as the spike's `parse_estimate`
        // does: an inverted range is one bad field, and throwing the whole
        // estimate away over it loses four good items to save one.
        self.low = Swift.max(0, Swift.min(low, high))
        self.high = Swift.max(0, Swift.max(low, high))
    }

    /// A range around a single known figure. Used when the user types a portion
    /// themselves — their number is not an estimate and carries no spread.
    static func exact(_ value: Double) -> EstimateRange {
        EstimateRange(low: value, high: value)
    }
}

/// One food the model found in the photograph, before anyone has agreed to it.
struct EstimatedItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var grams: EstimateRange
    var kcal: EstimateRange
    /// Nil for an item the user added themselves — the model has no opinion
    /// about something it never saw, and a fabricated one would pollute the
    /// dataset ADR 0010 is paying for.
    var confidence: EstimateConfidence?

    /// What the user has settled on. Starts at the midpoint, which is the app's
    /// best guess and not a claim.
    var confirmedGrams: Double
    var confirmedKcal: Double

    /// True once this item has been moved or was never the model's to begin
    /// with. Read straight into `photo_estimates.was_corrected`.
    var wasCorrected: Bool

    init(
        id: UUID = UUID(),
        name: String,
        grams: EstimateRange,
        kcal: EstimateRange,
        confidence: EstimateConfidence?
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.kcal = kcal
        self.confidence = confidence
        confirmedGrams = grams.midpoint.rounded()
        confirmedKcal = kcal.midpoint.rounded()
        wasCorrected = false
    }

    /// The user moved the portion. Energy follows it at the model's own density,
    /// because the thing they are correcting is *how much*, not *what it is* —
    /// re-deriving kcal from a food-table row would answer a question nobody
    /// asked and would silently discard the model's read on preparation.
    mutating func adjust(toGrams newGrams: Double) {
        let clamped = Swift.max(0, newGrams.rounded())
        let density = grams.midpoint > 0 ? kcal.midpoint / grams.midpoint : 0
        confirmedGrams = clamped
        confirmedKcal = (clamped * density).rounded()
        wasCorrected = true
    }

    /// Signed, and the direction is the interesting half: a model that is
    /// consistently under is a different problem from one that is noisy.
    var correctionDelta: Double { confirmedKcal - kcal.midpoint }

    /// An item the user added because the model missed it.
    ///
    /// Recorded as a correction against an estimate of zero rather than left out
    /// of the dataset. A miss is the failure mode §1.3 names first — cooking oil
    /// and hidden sugar photograph as nothing at all — so a dataset that only
    /// contains what the model *did* see cannot measure the thing most worth
    /// measuring.
    static func added(name: String, grams: Double, kcal: Double) -> EstimatedItem {
        var item = EstimatedItem(
            name: name,
            grams: .exact(0),
            kcal: .exact(0),
            confidence: nil
        )
        item.confirmedGrams = Swift.max(0, grams.rounded())
        item.confirmedKcal = Swift.max(0, kcal.rounded())
        item.wasCorrected = true
        return item
    }
}

/// Everything one round trip produced, validated.
struct MealEstimate: Equatable, Sendable {
    var items: [EstimatedItem]
    /// What the model could not tell from the photo. Shown, because the honest
    /// version of this feature is the one that says what it missed.
    var notes: String

    /// Path inside the private `meal-photos` bucket, always `<user-id>/<file>`.
    var storagePath: String

    /// The structured output, whole. Re-reading old estimates against a new
    /// prompt is only possible if the original survived, so this is stored
    /// unedited rather than re-encoded from the parsed values.
    var rawOutput: Data

    /// The exact model id that produced it. ADR 0010's first requirement: a
    /// measured error rate is only meaningful attributed to a version.
    var model: String

    /// Measured client-side, upload included. The spike saw 1.9–3.1 s.
    var latency: TimeInterval

    /// The meal's energy, as a range. The tolerances add rather than combining
    /// in quadrature: the errors on two items of the same meal are not
    /// independent — one badly judged plate size moves all of them the same way
    /// — and a narrower total than the parts is the kind of false confidence
    /// this whole screen exists to avoid.
    var total: EstimateRange {
        EstimateRange(
            low: items.reduce(0) { $0 + $1.kcal.low },
            high: items.reduce(0) { $0 + $1.kcal.high }
        )
    }

    /// The energy the user actually agreed to.
    var confirmedKcal: Double { items.reduce(0) { $0 + $1.confirmedKcal } }
}

/// What can go wrong between the shutter and the Under Review screen.
///
/// Every case has copy, and **every case leaves manual entry intact** — the
/// photo route is a helper, so a failure here is never a dead end. The cap case
/// exists because §10 asks for the limit before the app is handed to anyone
/// rather than after a surprise bill.
enum MealEstimateError: LocalizedError, Equatable, CaseIterable {
    case notSignedIn
    case offline
    /// The server's per-user daily cap. Enforced there, reported here.
    case dailyCapReached
    /// The response did not survive validation. Degrades to manual entry.
    case malformedResponse
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in to save this."
        case .offline: SubOnCopy.estimateOffline
        case .dailyCapReached: SubOnCopy.photoCapReached
        case .malformedResponse: SubOnCopy.estimateUnreadable
        case .unavailable: SubOnCopy.estimateUnavailable
        }
    }

    /// The way forward, in every case. Shown under the message.
    var recoveryDescription: String { SubOnCopy.estimateFallback }
}
