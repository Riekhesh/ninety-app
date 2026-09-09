import Foundation
import SwiftData

/// The four data domains, as protocols.
///
/// ADR 0004 keeps MVVM and skips TCA, and names the part worth keeping
/// regardless: protocol-based repositories are what make the app testable at
/// all. Views talk to `@Observable` ViewModels, ViewModels talk to these, and
/// nothing above this line knows whether the answer came from SwiftData, from
/// Supabase or from a mock.
///
/// Two rules hold across all four, and both come from measurements rather than
/// taste:
///
/// **Reads return empty, they do not throw.** Phase 0 established that iOS has
/// no permission-denied branch to write: a denied HealthKit read returns a
/// result identical to "no data" and the two will never be distinguishable. A
/// repository that throws on absence forces every call site to invent a
/// difference that does not exist. Absence is a value here, and the empty state
/// is designed to cover both without claiming either.
///
/// **Writes are local-first and return immediately.** ADR 0005: the UI never
/// waits on the network. A write lands in SwiftData, an outbox entry is
/// enqueued, and the caller gets its object back. Nothing here is async for the
/// sake of the network, because nothing here touches it.

/// A meal about to be logged.
///
/// A value rather than six parameters, and the reason is P1-F rather than the
/// argument count. All four logging routes converge on one of these, and the
/// photo route builds it up over two screens — the estimate arrives, the user
/// corrects the portion on Under Review, and only then does anything get
/// written. A struct can be held and edited between those steps; an argument
/// list cannot.
struct FoodLogDraft {
    /// Nil for manual entry, which is the route that works offline by
    /// construction and the one that starts the 21-day clock.
    var food: Food?
    var grams: Double
    /// Carried rather than derived: a photo estimate's kcal comes from the
    /// model and the user's correction, not from a catalogue row.
    var kcal: Double
    /// Snapshotted onto the log, so a logged day survives its food being
    /// deleted or a catalogue refresh rewriting it.
    var name: String
    var entryMethod: EntryMethod
    var loggedAt: Date

    init(
        food: Food? = nil,
        grams: Double,
        kcal: Double,
        name: String,
        entryMethod: EntryMethod,
        loggedAt: Date
    ) {
        self.food = food
        self.grams = grams
        self.kcal = kcal
        self.name = name
        self.entryMethod = entryMethod
        self.loggedAt = loggedAt
    }
}

/// A food about to be created or cached locally.
///
/// Two jobs, deliberately one type. A custom food the user typed on the manual
/// route and an Open Food Facts row that arrived from search or a barcode scan
/// are the same row in `public.foods` — they differ only in `source` and in who
/// owns them — so a second draft type would be two shapes for one table.
///
/// **`id` is carried rather than generated when it is known.** A catalogue row
/// cached from the server keeps the server's id, which is what stops the same
/// food arriving twice under two local identities after two searches. A custom
/// food has no server row yet, so it passes nil and the store mints one.
struct FoodDraft {
    /// The server's id for a catalogue row; nil for something typed here.
    var id: UUID?
    var source: FoodSource
    var barcode: String?
    var name: String
    var brand: String?
    var kcalPer100g: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?

    init(
        id: UUID? = nil,
        source: FoodSource,
        barcode: String? = nil,
        name: String,
        brand: String? = nil,
        kcalPer100g: Double,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil
    ) {
        self.id = id
        self.source = source
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.kcalPer100g = kcalPer100g
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}

/// What the vision model said, alongside what the user decided.
///
/// ADR 0010's condition for folding the photo benchmark into Phase 1: the photo
/// and the model's output are kept next to the confirmed values, so the 21 days
/// produce the dataset rather than a separate evening's collection. All five
/// fields are written in the same transaction as the log they belong to — a
/// `photo_estimates` row written afterwards is one that can be missing.
///
/// `wasCorrected` is written on **every** pass, including the passes where the
/// user changed nothing. A dataset that only records corrections cannot tell
/// "the model was right" from "nobody looked".
struct PhotoEstimateDraft {
    var storagePath: String
    /// The model's structured output, whole and unedited.
    var modelOutput: Data
    /// 0...1, surfaced as HIGH / MEDIUM / LOW.
    var confidence: Double?
    var wasCorrected: Bool
    /// Confirmed kcal minus estimated kcal. Signed: the direction is the
    /// interesting half, because a model that is consistently under is a
    /// different problem from one that is noisy.
    var correctionDelta: Double?
}

/// One food the user actually eats, with how often and how it was last logged.
///
/// The Squad and the Bench are both made of these. Keyed on the **name
/// snapshot** rather than on a food id, and that is the load-bearing choice: a
/// quick-add by calories has no food row at all, and a catalogue row can be
/// deleted underneath a log. Grouping on the snapshot means both still appear on
/// the team sheet, which is the difference between a feature that works for the
/// user's own vocabulary and one that only works for packaged food.
struct FoodHabit: Identifiable, Equatable, Sendable {
    /// The name is the identity. See the note above.
    var id: String { name }

    let name: String
    /// How many times it has been logged in the window. The artboard's "APPS".
    let appearances: Int
    let lastLoggedAt: Date
    /// The portion it was last logged at, which is what a tap repeats.
    let grams: Double
    let kcal: Double
    /// Nil for a quick-add, and for a log whose food row has gone.
    let foodID: UUID?
}

/// Everything about the profile, including the values the §10 gates read.
@MainActor
protocol ProfileRepositoryProtocol {
    /// Nil when onboarding has not run. Not an error — it is the first-launch
    /// state, and the app has a designed answer for it.
    func current() -> Profile?

    @discardableResult
    func save(_ profile: Profile) throws -> Profile

    /// §10 S6, and it has to be cheap: the opt-out is read on every surface
    /// that could show a division.
    func isCompetitiveOptOutEnabled() -> Bool
}

/// The catalogue and the logs written against it.
@MainActor
protocol FoodRepositoryProtocol {
    /// Everything logged on one calendar day, oldest first. Empty is a normal
    /// answer and renders as "Nothing logged yet."
    func logs(on day: Date, calendar: Calendar) -> [FoodLog]

    /// The local catalogue: custom entries plus whatever search has cached.
    /// The full mirror lives in Postgres and is not copied to the phone.
    func foods(matching query: String, limit: Int) -> [Food]

    /// A cached or custom food carrying this barcode, if the phone has one.
    ///
    /// Checked before the network on the barcode route, because a scan in a
    /// supermarket aisle is the case with the worst signal and the least
    /// patience. A second scan of the same tin should never wait on anything.
    func food(withBarcode barcode: String) -> Food?

    /// Creates a custom food, or caches a catalogue row the server returned.
    ///
    /// Upserts on the draft's id when it has one, so a catalogue row that comes
    /// back from three searches is cached once rather than three times.
    @discardableResult
    func saveFood(_ draft: FoodDraft) throws -> Food

    /// The logs behind the Squad and the Bench, newest first.
    ///
    /// Raw logs rather than a computed team sheet, because the interesting part
    /// — how frequency and recency are ranked against each other — is a rule
    /// worth testing without a store. `TeamSheet` is where it lives.
    func recentLogs(since moment: Date, limit: Int) -> [FoodLog]

    /// Writes locally and returns. §2.3's lock is set from `loggedAt` here and
    /// never moved afterwards.
    @discardableResult
    func log(_ draft: FoodLogDraft) throws -> FoodLog

    /// A log and the estimate that produced it, in one write.
    ///
    /// One call rather than two so the pair cannot come apart: an estimate row
    /// written after a successful log is one that a crash, a signal drop or a
    /// user closing the sheet can lose, and the benchmark dataset ADR 0010 is
    /// paying for is exactly the pair.
    @discardableResult
    func log(_ draft: FoodLogDraft, estimate: PhotoEstimateDraft) throws -> FoodLog

    /// Every estimate kept alongside its confirmed log, newest first. The
    /// benchmark export reads this and nothing else does.
    func photoEstimates(limit: Int) -> [PhotoEstimate]

    /// Refuses after the 48-hour window. The moment is a parameter so the rule
    /// can be tested without waiting two days or moving the device clock.
    func update(_ log: FoodLog, grams: Double, kcal: Double, at moment: Date) throws

    func delete(_ log: FoodLog, at moment: Date) throws
}

/// Weight, and the readings the trend is computed from.
@MainActor
protocol WeightRepositoryProtocol {
    /// Newest first. Fewer than seven readings is a real state the UI has copy
    /// for — "Trend needs a week of readings" — not an error.
    func recent(limit: Int) -> [WeightLog]

    /// Everything measured at or after a moment, **oldest first**.
    ///
    /// The opposite order from `recent(limit:)` on purpose: this is what the
    /// trend is built from, the EWMA walks forward through time, and a reversed
    /// array reaching `WeightTrend` would produce a line that smooths the past
    /// toward the present. Sorting at the boundary means no caller has to
    /// remember which way round the other method hands them.
    func readings(since moment: Date) -> [WeightLog]

    @discardableResult
    func record(kg: Double, at measuredAt: Date, source: WeightSource) throws -> WeightLog

    /// Writes the external readings this store has not already seen.
    ///
    /// One call rather than a read, a filter at the call site and a loop of
    /// writes, because the read and the write have to be the same transaction
    /// for the duplicate check to mean anything — two syncs racing each other
    /// would otherwise each find the store empty of the sample they are both
    /// about to insert. The rule itself is `WeightReconciliation.unseen`, which
    /// is pure and tested without a store.
    ///
    /// Returns what was actually written, which is what lets the screen say
    /// "nothing new" rather than claiming a sync that added nothing.
    @discardableResult
    func importReadings(_ readings: [BodyMassReading], calendar: Calendar) throws -> [WeightLog]

    func delete(_ log: WeightLog) throws
}

/// Daily HealthKit buckets, and the anchor that makes sync incremental.
@MainActor
protocol HealthRepositoryProtocol {
    func samples(from start: Date, to end: Date) -> [HealthSample]

    @discardableResult
    func upsert(
        day: Date,
        steps: Int?,
        activeEnergy: Double?,
        exerciseMinutes: Int?,
        workoutCount: Int
    ) throws -> HealthSample

    /// §1.4's "entire trick". Nil on a first run, which is the only time a full
    /// history query is the right thing to do.
    func anchor() -> Data?
    func saveAnchor(_ anchor: Data) throws
}

/// What a repository refuses to do, and why.
///
/// Deliberately small. Most failure modes here are not errors — an empty result
/// is a value — so this covers only the cases where the app must not proceed.
enum RepositoryError: LocalizedError, Equatable {
    /// §2.3. The log is older than 48 hours.
    case logIsLocked(since: Date)
    /// No signed-in user, so there is no row to own the write.
    case noProfile

    var errorDescription: String? {
        switch self {
        case .logIsLocked:
            // The copy deck's wording, verbatim. Stating the rule plainly is
            // what makes it acceptable rather than mysterious.
            "Logs older than 48 hours can't be edited. It keeps scores honest."
        case .noProfile:
            "Sign in to save this."
        }
    }
}

/// Everything a ViewModel might need, in one injectable value.
///
/// A struct of protocols rather than a service locator: a test builds one with
/// the mocks it cares about, and the compiler lists what it forgot.
@MainActor
struct Repositories {
    var profile: any ProfileRepositoryProtocol
    var food: any FoodRepositoryProtocol
    var weight: any WeightRepositoryProtocol
    var health: any HealthRepositoryProtocol
}

extension Repositories {
    /// The real set, for one signed-in user.
    ///
    /// The user id is a parameter and not a lookup on purpose: every repository
    /// here scopes its reads and writes to it, and it comes from the auth
    /// session, so there is no path by which a repository can be built before
    /// anybody is signed in. It is the same id as `profiles.id` and as the
    /// `user_id` every RLS policy compares against, which is what makes the
    /// local store and Postgres agree about ownership without a mapping table.
    static func live(context: ModelContext, userID: UUID) -> Repositories {
        Repositories(
            profile: SwiftDataProfileRepository(context: context, userID: userID),
            food: SwiftDataFoodRepository(context: context, userID: userID),
            weight: SwiftDataWeightRepository(context: context, userID: userID),
            health: SwiftDataHealthRepository(context: context, userID: userID)
        )
    }
}

// Still deliberately no `EnvironmentValues` entry.
//
// `Repositories` holds MainActor-isolated existentials, so putting it in the
// environment needs care under Swift 6 strict concurrency. P1-C's consent gate
// is the first real consumer and it takes the one repository it needs as an
// init parameter, which is both simpler to test and honest about its
// dependencies. The environment entry can land with P1-D, when there is a
// ViewModel that wants all four.
