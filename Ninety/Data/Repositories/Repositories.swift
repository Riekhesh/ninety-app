import Foundation

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

    /// Writes locally and returns. §2.3's lock is set from `loggedAt` here and
    /// never moved afterwards.
    @discardableResult
    func log(_ draft: FoodLogDraft) throws -> FoodLog

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

    @discardableResult
    func record(kg: Double, at measuredAt: Date, source: WeightSource) throws -> WeightLog

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

// Deliberately no `EnvironmentValues` entry yet.
//
// `Repositories` holds MainActor-isolated existentials, so putting it in the
// environment needs care under Swift 6 strict concurrency — and nothing
// consumes it until P1-D brings the first ViewModel. Tests build one directly
// with `Repositories.mock()`, which is all the injection the ticket asks for.
// The wiring lands with the first screen that needs it, where it can be
// compiled against a real call site rather than guessed at.
