import Foundation

/// The enumerations the local store and Postgres both speak.
///
/// Each mirrors a Postgres enum in `supabase/migrations/…_initial_schema.sql`,
/// and the raw values are the strings the database stores — so a value crosses
/// the wire unchanged and a rename has to happen in both places or the build
/// stops matching the schema. `Tier` is deliberately absent: it is generated
/// from the design tokens, because a tier is a division and a division is a
/// visual thing (ADR 0012).

/// Where a food came from. `custom` rows belong to one user; the other two are
/// the shared catalogue and belong to nobody.
enum FoodSource: String, Codable, CaseIterable, Sendable {
    case off, usda, custom
}

/// Which of the four routes logged this. `manual` first, because it works
/// offline by construction and it is the route that starts the 21-day clock.
enum EntryMethod: String, Codable, CaseIterable, Sendable {
    case manual, search, barcode, photo
}

enum WeightSource: String, Codable, CaseIterable, Sendable {
    case manual, healthkit
}

enum OutboxOperation: String, Codable, CaseIterable, Sendable {
    case insert, update, delete
}

enum GoalType: String, Codable, CaseIterable, Sendable {
    case lose, maintain, gain
}

/// `unspecified` is a real answer to a question the user may decline, not a
/// missing value. S1 pairs it with the HIGHER calorie floor of 1,500, because
/// erring high is the safe direction when you do not know.
enum Sex: String, Codable, CaseIterable, Sendable {
    case female, male, unspecified

    /// §10 S1. The daily target may never fall below this, whatever is asked.
    var calorieFloor: Int {
        switch self {
        case .female: 1_200
        case .male, .unspecified: 1_500
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary, light, moderate, active
    case veryActive = "very_active"

    /// The Mifflin-St Jeor activity factor. Here rather than in the ranking
    /// engine because it is a property of the profile, not of the score.
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}
