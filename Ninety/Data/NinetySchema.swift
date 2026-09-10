import Foundation
import SwiftData

/// The local store's schema, versioned from the first release.
///
/// The ticket asks for a migration story because the store *will* change during
/// the 21 days — P1-E adds HealthKit fields, P1-F adds the photo route, and
/// each of those is a schema change landing on a device that already holds real
/// logged days.
///
/// SwiftData will migrate an unversioned store implicitly, right up until it
/// cannot, and then it throws at launch and the app is dead on the user's
/// phone with their data inside it. Once the 21-day clock is running that is
/// not an inconvenience: a change that breaks a day's logging resets a counter
/// costing three weeks to rebuild, which is why the tracker makes it a fix-now
/// bug by definition.
///
/// Declaring V1 now costs one enum. Retrofitting versioning onto a store that
/// already holds a fortnight of someone's health data does not.
enum NinetySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Profile.self,
            Food.self,
            FoodLog.self,
            PhotoEstimate.self,
            WeightLog.self,
            HealthSample.self,
            WeeklyScore.self,
            OutboxEntry.self,
        ]
    }
}

/// V2 · `FoodLog.mealSlotRaw` (ADR 0022).
///
/// **The first schema change to land on a phone that already holds logged
/// days**, which is the case the whole of `NinetySchemaV1`'s note was written
/// for. It is the cheapest shape that change can have: one new property, on one
/// model, optional, with no default and nothing to backfill.
///
/// That last part is not an accident of the design, it *is* the design. Nil
/// means "derive the slot from `logged_at`", so every row already in the store
/// is already correct under V2 without being touched — which is what makes this
/// a lightweight stage rather than a custom one that has to walk somebody's
/// fortnight of history on launch, on a phone, with the clock running.
enum NinetySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    /// The same eight types. SwiftData reads the *current* declarations, so this
    /// list and V1's are the same array — the version identifier is what
    /// distinguishes them, and V1 stays declared as the record of what the store
    /// on an existing device was opened as.
    static var models: [any PersistentModel.Type] { NinetySchemaV1.models }
}

/// How the store gets from one version to the next.
///
/// One stage per release that changes the schema. A lightweight stage covers
/// adding an optional property or a new model; anything that reshapes or
/// reinterprets existing data needs a custom stage that says explicitly what
/// happens to the rows already there.
enum NinetyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NinetySchemaV1.self, NinetySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        // Lightweight, and it is worth being explicit about why rather than
        // reaching for the cheap one by default: the only difference between V1
        // and V2 is an optional property whose absent value is meaningful, so
        // there is no row in an existing store that needs a decision made about
        // it. A custom stage here would have nothing to do.
        [.lightweight(fromVersion: NinetySchemaV1.self, toVersion: NinetySchemaV2.self)]
    }
}

extension ModelContainer {
    /// The app's store.
    ///
    /// Deliberately not `try?` with a fallback to an in-memory container: a
    /// store that silently becomes ephemeral looks like a working app right up
    /// to the moment the user reopens it and a day of logging is gone. If this
    /// cannot open, that is a bug to fix before shipping, not to paper over.
    static func ninety(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory { try makeApplicationSupportDirectory() }
        return try ModelContainer(
            for: Schema(versionedSchema: NinetySchemaV2.self),
            migrationPlan: NinetyMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    /// `Library/Application Support` is not created for you.
    ///
    /// SwiftData puts `default.store` there and does not make the directory
    /// first, so a fresh install logs around two hundred lines of CoreData
    /// errors — `Sandbox access to file-write-create denied`, `The file
    /// couldn't be saved` — before recovering and creating it itself. The store
    /// does open, which is why this is a tidy-up rather than a bug.
    ///
    /// It is still worth doing. That block appears on *every* user's first
    /// launch, it is indistinguishable at a glance from a store that genuinely
    /// failed to open, and this is the one file whose whole design note is that
    /// a local store which quietly goes wrong is the most expensive bug in the
    /// project. A log that cries wolf on first launch is one nobody reads on
    /// the launch that matters.
    ///
    /// `create: true` is the documented way to ask for it; the URL is
    /// discarded because the directory existing is the entire point.
    private static func makeApplicationSupportDirectory() throws {
        _ = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}
