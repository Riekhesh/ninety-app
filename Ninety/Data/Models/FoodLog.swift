import Foundation
import SwiftData

/// One thing eaten. Mirrors `public.food_logs`.
///
/// This is the row the whole of Phase 1 exists to produce: 21 consecutive days
/// of these is the exit criterion, and they are the test set the entire ranking
/// engine is designed against in Phase 2.
@Model
final class FoodLog {
    @Attribute(.unique)
    var id: UUID
    var userID: UUID
    var createdAt: Date
    var updatedAt: Date

    var loggedAt: Date
    var grams: Double
    var entryMethodRaw: String

    /// Which meal this was, **only when the user said so** (ADR 0022).
    ///
    /// Nil is not a missing value and must not be filled in by a backfill: it
    /// means the slot is derived from `loggedAt`, which is what every row
    /// written by every route means, because no route asks the question. A
    /// stored value is the user having corrected the derivation — a night shift,
    /// a very late dinner — and the two are different statements. Read it
    /// through `mealSlot(calendar:)` rather than directly, which is where the
    /// two are resolved into the one answer a screen wants.
    var mealSlotRaw: String?

    /// §2.3. Set from `loggedAt` on creation and never moved. Postgres derives
    /// the same value by trigger and enforces it in the update policy, so the
    /// two agree without the client being trusted about it.
    var locksAt: Date

    /// Denormalised on purpose. A logged day has to stay readable forever, and
    /// it cannot depend on a food row surviving a catalogue refresh or a custom
    /// entry being deleted.
    var kcal: Double
    var nameSnapshot: String

    /// Nil when the food it referenced has gone. The snapshot above is why that
    /// is survivable rather than data loss.
    var food: Food?

    @Relationship(deleteRule: .cascade, inverse: \PhotoEstimate.log)
    var estimates: [PhotoEstimate]

    init(
        id: UUID = UUID(),
        userID: UUID,
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast,
        loggedAt: Date,
        grams: Double,
        entryMethod: EntryMethod,
        kcal: Double,
        nameSnapshot: String,
        mealSlot: MealSlot? = nil,
        food: Food? = nil,
        estimates: [PhotoEstimate] = []
    ) {
        self.id = id
        self.userID = userID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.loggedAt = loggedAt
        self.grams = grams
        self.entryMethodRaw = entryMethod.rawValue
        self.mealSlotRaw = mealSlot?.rawValue
        self.locksAt = loggedAt.addingTimeInterval(FoodLog.editWindow)
        self.kcal = kcal
        self.nameSnapshot = nameSnapshot
        self.food = food
        self.estimates = estimates
    }
}

extension FoodLog {
    /// §2.3's retroactive edit lock. Forty-eight hours, and the copy deck says
    /// so plainly to the user: "Logs older than 48 hours can't be edited. It
    /// keeps scores honest." A rule someone can see the point of is one they
    /// accept; a mysterious disabled control is not.
    static let editWindow: TimeInterval = 48 * 60 * 60

    var entryMethod: EntryMethod {
        get { EntryMethod(rawValue: entryMethodRaw) ?? .manual }
        set { entryMethodRaw = newValue.rawValue }
    }

    /// The correction the user made, or nil if they have not made one.
    ///
    /// Separate from `mealSlot(calendar:)` because a picker has to be able to
    /// tell "the user chose dinner" from "the app worked out dinner" — the first
    /// survives a change to the boundaries and the second does not.
    var storedMealSlot: MealSlot? {
        get { mealSlotRaw.flatMap(MealSlot.init(rawValue:)) }
        set { mealSlotRaw = newValue?.rawValue }
    }

    /// Which meal this log belongs to: the user's answer if there is one, the
    /// derivation off `loggedAt` otherwise.
    ///
    /// The calendar is a parameter for the same reason it is on
    /// `MealSlot.of(_:calendar:)` and on `isEditable(at:)` — a rule that reads
    /// ambient state cannot be tested in a timezone other than the machine's,
    /// and logging across a date boundary is an explicit Phase 2 exploit.
    func mealSlot(calendar: Calendar) -> MealSlot {
        storedMealSlot ?? MealSlot.of(loggedAt, calendar: calendar)
    }

    /// The date is injected rather than read from the clock, for the same
    /// reason the ranking engine may not read it: a rule that consults ambient
    /// state cannot be tested deterministically, and logging across timezone
    /// boundaries is an explicit Phase 2 exploit.
    func isEditable(at moment: Date) -> Bool { moment < locksAt }
}
