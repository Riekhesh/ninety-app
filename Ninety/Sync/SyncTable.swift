import Foundation

/// The six tables the outbox can carry, and what each one needs to reach
/// Postgres intact.
///
/// **This is where `OutboxEntry.tableName` becomes `sync_outbox.entity`.** That
/// model's own doc comment promised the mapping to P1-I and said why it was
/// deferred: a stored attribute called `entity` shadows the one
/// `NSManagedObject` already owns and traps inside `ModelContext.save()` with a
/// message that names neither the property nor the model. A column name is a
/// cheap thing to translate, and this is the one place that translates it.
///
/// Three things live here rather than being spelled at the call site, because
/// each of them is a property of the table and getting one wrong is a write
/// that fails at the server rather than in the compiler.
enum SyncTable: String, CaseIterable, Sendable {
    case profiles
    case foods
    case foodLogs = "food_logs"
    case photoEstimates = "photo_estimates"
    case weightLogs = "weight_logs"
    case healthSamples = "health_samples"

    /// The Postgres table. Identical to the raw value, and named so that a
    /// reader of the drain does not have to know that.
    var postgres: String { rawValue }

    /// What has to exist on the server before a row of this table can.
    ///
    /// Two real chains, and both of them are foreign keys that a batch drained
    /// in the wrong order would violate: a custom food has to land before the
    /// log that references it, and a log has to land before the estimate that
    /// produced it. Everything else is independent, and rank 1 says so rather
    /// than inventing an order for rows that do not need one.
    ///
    /// `profiles` is rank 0 not because anything references it — `food_logs`
    /// keys on `auth.users`, not on the profile — but because a first sync
    /// after onboarding should put the row that makes the account legible
    /// before the rows that fill it.
    var rank: Int {
        switch self {
        case .profiles: 0
        case .foods, .weightLogs, .healthSamples: 1
        case .foodLogs: 2
        case .photoEstimates: 3
        }
    }

    /// The unique constraint an upsert should resolve against, when it is not
    /// the primary key.
    ///
    /// Both of these are the reinstall case rather than a theoretical one. A
    /// phone restored from nothing re-reads Apple Health and mints **new local
    /// ids for the same weigh-ins**; upserting those on `id` would insert a
    /// second row for a weight that already exists and then fail the
    /// `(user_id, measured_at, source)` constraint that migration 001 put there
    /// precisely to stop a smart scale and the app double-counting one
    /// stepping-on. Resolving against the natural key instead converges the two
    /// copies — the server row keeps the reading and takes the device's id, so
    /// the next update or delete by id finds it.
    ///
    /// Neither column in either key is ever mutated locally, which is what
    /// makes this safe: a row whose natural key moved under a fixed id would
    /// conflict on the primary key instead, and that conflict has no arbiter.
    var conflictTarget: String? {
        switch self {
        case .weightLogs: "user_id,measured_at,source"
        case .healthSamples: "user_id,date"
        case .profiles, .foods, .foodLogs, .photoEstimates: nil
        }
    }
}
