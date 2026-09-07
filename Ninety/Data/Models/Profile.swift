import Foundation
import SwiftData

/// The user, as the app needs to know them.
///
/// Mirrors `public.profiles`. Every field the §10 gates depend on lives here,
/// because a safety rule that has to fetch something over the network is a
/// safety rule that does not apply in a gym basement.
@Model
final class Profile {
    /// The auth user id. Same value as the Postgres primary key, so a row
    /// round-trips without a lookup.
    @Attribute(.unique)
    var id: UUID

    var createdAt: Date
    var updatedAt: Date

    /// §10 S4. Stored as a date so the age gate is computed on the actual day —
    /// someone turning 18 tomorrow is 17 today, and a year subtraction says
    /// otherwise.
    var dob: Date?
    var heightCm: Double?
    var sexRaw: String
    var activityLevelRaw: String

    var goalTypeRaw: String
    /// §10 S2. Rejected, never clamped, if its BMI would fall below 18.5.
    var goalWeightKg: Double?
    /// §10 S3. The ceiling is min(1.0, 1% of body weight) per week, so it moves
    /// with the user; this is the rate they chose within it.
    var targetRateKgPerWeek: Double

    /// Null while the first 14 days are still establishing a baseline. No rank
    /// is shown until it closes.
    var calibrationCompletedAt: Date?

    /// §10 S6. Off by default; when on, every competitive surface goes away and
    /// the tracker stays entirely useful.
    var competitiveOptOut: Bool

    /// Two dates, not one flag. Article 9 health data needs explicit consent
    /// recorded separately from terms acceptance — one checkbox covering both
    /// is not explicit consent to anything.
    var termsAcceptedAt: Date?
    var healthConsentAt: Date?

    init(
        id: UUID,
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast,
        dob: Date? = nil,
        heightCm: Double? = nil,
        sex: Sex = .unspecified,
        activityLevel: ActivityLevel = .sedentary,
        goalType: GoalType = .lose,
        goalWeightKg: Double? = nil,
        targetRateKgPerWeek: Double = 0.5,
        calibrationCompletedAt: Date? = nil,
        competitiveOptOut: Bool = false,
        termsAcceptedAt: Date? = nil,
        healthConsentAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dob = dob
        self.heightCm = heightCm
        self.sexRaw = sex.rawValue
        self.activityLevelRaw = activityLevel.rawValue
        self.goalTypeRaw = goalType.rawValue
        self.goalWeightKg = goalWeightKg
        self.targetRateKgPerWeek = targetRateKgPerWeek
        self.calibrationCompletedAt = calibrationCompletedAt
        self.competitiveOptOut = competitiveOptOut
        self.termsAcceptedAt = termsAcceptedAt
        self.healthConsentAt = healthConsentAt
    }
}

// Enums are stored as their raw strings and surfaced as types.
//
// SwiftData can persist a Codable enum directly, but it encodes it in a form
// only SwiftData reads. These rows also travel to Postgres, where the column is
// a real enum type, so the stored value has to be the bare string the database
// expects — and a `#Predicate` can filter on a String but not on an associated
// enum, which matters the moment a query needs a WHERE.
extension Profile {
    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .sedentary }
        set { activityLevelRaw = newValue.rawValue }
    }

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .lose }
        set { goalTypeRaw = newValue.rawValue }
    }

    /// §10 S4. Computed on the actual date, never by subtracting years.
    func isAdult(on day: Date, calendar: Calendar) -> Bool {
        guard let dob else { return false }
        guard let years = calendar.dateComponents([.year], from: dob, to: day).year else { return false }
        return years >= 18
    }

    /// True once the 14-day calibration window has closed. Until then the app
    /// shows "CALIBRATING · N days to go" and no rank at all.
    var isCalibrated: Bool { calibrationCompletedAt != nil }
}
