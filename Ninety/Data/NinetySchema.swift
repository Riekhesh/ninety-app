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

/// How the store gets from one version to the next.
///
/// One stage per release that changes the schema. A lightweight stage covers
/// adding an optional property or a new model; anything that reshapes or
/// reinterprets existing data needs a custom stage that says explicitly what
/// happens to the rows already there.
enum NinetyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NinetySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // Empty until V2. The list is what a future stage is appended to, and
        // having it here means the next schema change is an append rather than
        // a decision about whether versioning was worth it.
        []
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
        try ModelContainer(
            for: Schema(versionedSchema: NinetySchemaV1.self),
            migrationPlan: NinetyMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
