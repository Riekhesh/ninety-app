import Foundation

/// Local models, as Postgres rows.
///
/// The whole translation layer, in one file, deliberately. Swift spells a
/// column `kcalPer100g` and Postgres spells it `kcal_per_100g`; both are right
/// and neither can be inferred from the other, so the mapping is written down
/// once where a reviewer can check it against
/// `supabase/migrations/…_initial_schema.sql` line by line.
///
/// **Two columns are never sent, and both omissions are load-bearing.**
///
/// `updated_at` is the first. ADR 0005 resolves conflicts by *server*
/// timestamp, and migration 001 is emphatic about the word: a client-supplied
/// `updated_at` would let a device with a wrong clock — or a patched binary —
/// win every conflict. The `set_updated_at` trigger overwrites whatever arrives,
/// so sending one would be dishonest rather than dangerous; not sending one
/// makes it obvious that the server owns it.
///
/// `health_samples.hk_anchor` is the second. It is an opaque
/// `HKAnchoredObjectQuery` cursor describing what *one device* has already
/// read. Pushing it to the server and back to a second phone would tell that
/// phone it had already read a history it has never seen, which is the exact
/// failure §1.4 calls "the entire trick" for avoiding. The anchor stays where
/// it was minted.
///
/// `locked_at` is a third, of a different kind: it is `not null` with no
/// default, and migration 001 fills it by trigger from `logged_at` so the
/// client cannot move §2.3's 48-hour window. Sending it would be rejected on
/// principle; the trigger is the point.
@MainActor
enum SyncPayload {
    /// The row as the server should now hold it, or nil when there is nothing
    /// to say.
    ///
    /// Nil is not a failure. A `foods` row that is not custom belongs to the
    /// shared catalogue, and pushing a local copy of it back would be the
    /// client trying to write a row its own RLS policy refuses —
    /// `foods_insert_own_custom` checks `source = 'custom' and created_by =
    /// auth.uid()`. `SwiftDataFoodRepository` already declines to enqueue those;
    /// this is the second lock on the same door, because the first one lives in
    /// a different file from the request.
    static func row(for profile: Profile, calendar: Calendar) -> SyncRow {
        SyncRow(
            table: .profiles,
            id: profile.id,
            columns: [
                "id": .text(profile.id.uuidString.lowercased()),
                "created_at": .text(SyncTime.instant(profile.createdAt)),
                "dob": profile.dob.map { .text(SyncTime.day($0, calendar: calendar)) } ?? .null,
                "height_cm": profile.heightCm.map(SyncValue.number) ?? .null,
                "sex": .text(profile.sex.rawValue),
                "activity_level": .text(profile.activityLevel.rawValue),
                "goal_type": .text(profile.goalType.rawValue),
                "goal_weight_kg": profile.goalWeightKg.map(SyncValue.number) ?? .null,
                "target_rate_kg_per_week": .number(profile.targetRateKgPerWeek),
                "calibration_completed_at": profile.calibrationCompletedAt
                    .map { .text(SyncTime.instant($0)) } ?? .null,
                "competitive_opt_out": .flag(profile.competitiveOptOut),
                "terms_accepted_at": profile.termsAcceptedAt.map { .text(SyncTime.instant($0)) } ?? .null,
                "health_consent_at": profile.healthConsentAt.map { .text(SyncTime.instant($0)) } ?? .null,
            ]
        )
    }

    static func row(for food: Food) -> SyncRow? {
        guard food.source == .custom, let owner = food.createdBy else { return nil }
        return SyncRow(
            table: .foods,
            id: food.id,
            columns: [
                "id": .text(food.id.uuidString.lowercased()),
                "created_at": .text(SyncTime.instant(food.createdAt)),
                "source": .text(food.source.rawValue),
                "created_by": .text(owner.uuidString.lowercased()),
                "barcode": food.barcode.map(SyncValue.text) ?? .null,
                "name": .text(food.name),
                "brand": food.brand.map(SyncValue.text) ?? .null,
                "kcal_per_100g": .number(food.kcalPer100g),
                "protein_g": food.proteinG.map(SyncValue.number) ?? .null,
                "carbs_g": food.carbsG.map(SyncValue.number) ?? .null,
                "fat_g": food.fatG.map(SyncValue.number) ?? .null,
            ]
        )
    }

    /// `food_id` is nil for a quick-add by calories and for a log whose food row
    /// has gone, and `on delete set null` in migration 001 says the same thing.
    /// The name and the calories are on the log itself, which is what makes
    /// either survivable rather than data loss.
    static func row(for log: FoodLog) -> SyncRow {
        SyncRow(
            table: .foodLogs,
            id: log.id,
            columns: [
                "id": .text(log.id.uuidString.lowercased()),
                "user_id": .text(log.userID.uuidString.lowercased()),
                "food_id": log.food.map { .text($0.id.uuidString.lowercased()) } ?? .null,
                "created_at": .text(SyncTime.instant(log.createdAt)),
                "logged_at": .text(SyncTime.instant(log.loggedAt)),
                "grams": .number(log.grams),
                "entry_method": .text(log.entryMethod.rawValue),
                "kcal": .number(log.kcal),
                "name_snapshot": .text(log.nameSnapshot),
            ]
        )
    }

    /// Nil when the log it belongs to has gone. An estimate with no `log_id` is
    /// a row Postgres refuses — the column is `not null` — and it is also
    /// meaningless: ADR 0010's dataset is the *pair*, the model's answer next to
    /// what the user confirmed, and half of it scores nothing.
    static func row(for estimate: PhotoEstimate) -> SyncRow? {
        guard let log = estimate.log else { return nil }
        return SyncRow(
            table: .photoEstimates,
            id: estimate.id,
            columns: [
                "id": .text(estimate.id.uuidString.lowercased()),
                "log_id": .text(log.id.uuidString.lowercased()),
                "user_id": .text(estimate.userID.uuidString.lowercased()),
                "created_at": .text(SyncTime.instant(estimate.createdAt)),
                "storage_path": .text(estimate.storagePath),
                // Verbatim, and `SyncRow.body` is written by hand so that it
                // stays that way. See ADR 0010.
                "model_output": .json(estimate.modelOutput),
                "confidence": estimate.confidence.map(SyncValue.number) ?? .null,
                "was_corrected": .flag(estimate.wasCorrected),
                "correction_delta": estimate.correctionDelta.map(SyncValue.number) ?? .null,
            ]
        )
    }

    static func row(for weight: WeightLog) -> SyncRow {
        SyncRow(
            table: .weightLogs,
            id: weight.id,
            columns: [
                "id": .text(weight.id.uuidString.lowercased()),
                "user_id": .text(weight.userID.uuidString.lowercased()),
                "created_at": .text(SyncTime.instant(weight.createdAt)),
                "measured_at": .text(SyncTime.instant(weight.measuredAt)),
                "kg": .number(weight.kg),
                "source": .text(weight.source.rawValue),
            ]
        )
    }

    static func row(for sample: HealthSample, calendar: Calendar) -> SyncRow {
        SyncRow(
            table: .healthSamples,
            id: sample.id,
            columns: [
                "id": .text(sample.id.uuidString.lowercased()),
                "user_id": .text(sample.userID.uuidString.lowercased()),
                "created_at": .text(SyncTime.instant(sample.createdAt)),
                "date": .text(SyncTime.day(sample.day, calendar: calendar)),
                "steps": sample.steps.map(SyncValue.integer) ?? .null,
                "active_energy": sample.activeEnergy.map(SyncValue.number) ?? .null,
                "exercise_minutes": sample.exerciseMinutes.map(SyncValue.integer) ?? .null,
                "workout_count": .integer(sample.workoutCount),
            ]
        )
    }
}
