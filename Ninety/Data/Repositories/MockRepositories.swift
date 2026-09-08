#if DEBUG
import Foundation

/// In-memory repositories for tests and previews.
///
/// `#if DEBUG` so they cannot reach a release build. They earn their place
/// twice over: a ViewModel test that touches SwiftData is a slow test with a
/// file on disk and an ordering problem, and a SwiftUI preview with no data is
/// a preview of an empty state you were not trying to look at.
///
/// Arrays rather than a dictionary, and no protocol-witness cleverness: a test
/// should be able to read one of these top to bottom and be certain what it
/// returns.

@MainActor
final class MockProfileRepository: ProfileRepositoryProtocol {
    var profile: Profile?
    /// Set to make `save` throw, for the paths that have to survive a failure.
    var saveError: (any Error)?
    private(set) var saveCount = 0

    init(profile: Profile? = nil) {
        self.profile = profile
    }

    func current() -> Profile? { profile }

    @discardableResult
    func save(_ profile: Profile) throws -> Profile {
        if let saveError { throw saveError }
        saveCount += 1
        self.profile = profile
        return profile
    }

    func isCompetitiveOptOutEnabled() -> Bool { profile?.competitiveOptOut ?? false }
}

@MainActor
final class MockFoodRepository: FoodRepositoryProtocol {
    var storedLogs: [FoodLog] = []
    var catalogue: [Food] = []
    var storedEstimates: [PhotoEstimate] = []
    /// Set to make a write throw, for the paths that have to survive a failure.
    var saveError: (any Error)?
    var logError: (any Error)?
    private(set) var loggedCount = 0

    let userID: UUID
    /// Injected, so a test can place a log at a known instant rather than at
    /// whenever the suite happened to run.
    var now: Date

    init(
        logs: [FoodLog] = [],
        catalogue: [Food] = [],
        estimates: [PhotoEstimate] = [],
        userID: UUID = UUID(),
        now: Date = Date()
    ) {
        self.storedLogs = logs
        self.catalogue = catalogue
        self.storedEstimates = estimates
        self.userID = userID
        self.now = now
    }

    func logs(on day: Date, calendar: Calendar) -> [FoodLog] {
        storedLogs
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    func foods(matching query: String, limit: Int) -> [Food] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return Array(
            catalogue
                .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
                .prefix(limit)
        )
    }

    func food(withBarcode barcode: String) -> Food? {
        catalogue.first { $0.barcode == barcode }
    }

    @discardableResult
    func saveFood(_ draft: FoodDraft) throws -> Food {
        if let saveError { throw saveError }
        if let id = draft.id, let existing = catalogue.first(where: { $0.id == id }) {
            existing.name = draft.name
            existing.brand = draft.brand
            existing.barcode = draft.barcode
            existing.kcalPer100g = draft.kcalPer100g
            existing.proteinG = draft.proteinG
            existing.carbsG = draft.carbsG
            existing.fatG = draft.fatG
            return existing
        }
        let food = Food(
            id: draft.id ?? UUID(),
            source: draft.source,
            createdBy: draft.source == .custom ? userID : nil,
            barcode: draft.barcode,
            name: draft.name,
            brand: draft.brand,
            kcalPer100g: draft.kcalPer100g,
            proteinG: draft.proteinG,
            carbsG: draft.carbsG,
            fatG: draft.fatG
        )
        catalogue.append(food)
        return food
    }

    func recentLogs(since moment: Date, limit: Int) -> [FoodLog] {
        Array(
            storedLogs
                .filter { $0.loggedAt >= moment }
                .sorted { $0.loggedAt > $1.loggedAt }
                .prefix(limit)
        )
    }

    @discardableResult
    func log(_ draft: FoodLogDraft) throws -> FoodLog {
        try write(draft, estimate: nil)
    }

    @discardableResult
    func log(_ draft: FoodLogDraft, estimate: PhotoEstimateDraft) throws -> FoodLog {
        try write(draft, estimate: estimate)
    }

    func photoEstimates(limit: Int) -> [PhotoEstimate] {
        Array(storedEstimates.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    private func write(_ draft: FoodLogDraft, estimate: PhotoEstimateDraft?) throws -> FoodLog {
        if let logError { throw logError }
        let entry = FoodLog(
            userID: userID,
            createdAt: now,
            loggedAt: draft.loggedAt,
            grams: draft.grams,
            entryMethod: draft.entryMethod,
            kcal: draft.kcal,
            nameSnapshot: draft.name,
            food: draft.food
        )
        storedLogs.append(entry)
        loggedCount += 1

        if let estimate {
            storedEstimates.append(
                PhotoEstimate(
                    userID: userID,
                    createdAt: now,
                    storagePath: estimate.storagePath,
                    modelOutput: estimate.modelOutput,
                    confidence: estimate.confidence,
                    wasCorrected: estimate.wasCorrected,
                    correctionDelta: estimate.correctionDelta,
                    log: entry
                )
            )
        }
        return entry
    }

    func update(_ log: FoodLog, grams: Double, kcal: Double, at moment: Date) throws {
        guard log.isEditable(at: moment) else { throw RepositoryError.logIsLocked(since: log.locksAt) }
        log.grams = grams
        log.kcal = kcal
    }

    func delete(_ log: FoodLog, at moment: Date) throws {
        guard log.isEditable(at: moment) else { throw RepositoryError.logIsLocked(since: log.locksAt) }
        storedLogs.removeAll { $0.id == log.id }
    }
}

@MainActor
final class MockWeightRepository: WeightRepositoryProtocol {
    var storedLogs: [WeightLog]

    init(logs: [WeightLog] = []) {
        self.storedLogs = logs
    }

    func recent(limit: Int) -> [WeightLog] {
        Array(storedLogs.sorted { $0.measuredAt > $1.measuredAt }.prefix(limit))
    }

    @discardableResult
    func record(kg: Double, at measuredAt: Date, source: WeightSource) throws -> WeightLog {
        let entry = WeightLog(userID: UUID(), measuredAt: measuredAt, kg: kg, source: source)
        storedLogs.append(entry)
        return entry
    }

    func delete(_ log: WeightLog) throws {
        storedLogs.removeAll { $0.id == log.id }
    }
}

@MainActor
final class MockHealthRepository: HealthRepositoryProtocol {
    var storedSamples: [HealthSample]
    var storedAnchor: Data?

    init(samples: [HealthSample] = [], anchor: Data? = nil) {
        self.storedSamples = samples
        self.storedAnchor = anchor
    }

    func samples(from start: Date, to end: Date) -> [HealthSample] {
        storedSamples.filter { $0.day >= start && $0.day <= end }.sorted { $0.day < $1.day }
    }

    @discardableResult
    func upsert(
        day: Date,
        steps: Int?,
        activeEnergy: Double?,
        exerciseMinutes: Int?,
        workoutCount: Int
    ) throws -> HealthSample {
        let sample = storedSamples.first { $0.day == day }
            ?? {
                let fresh = HealthSample(userID: UUID(), day: day)
                storedSamples.append(fresh)
                return fresh
            }()
        sample.steps = steps
        sample.activeEnergy = activeEnergy
        sample.exerciseMinutes = exerciseMinutes
        sample.workoutCount = workoutCount
        return sample
    }

    func anchor() -> Data? { storedAnchor }

    func saveAnchor(_ anchor: Data) throws { storedAnchor = anchor }
}

extension Repositories {
    /// A whole set of empty mocks. The first-launch state, which is what most
    /// tests and most previews actually want.
    static func mock(
        profile: MockProfileRepository = MockProfileRepository(),
        food: MockFoodRepository = MockFoodRepository(),
        weight: MockWeightRepository = MockWeightRepository(),
        health: MockHealthRepository = MockHealthRepository()
    ) -> Repositories {
        Repositories(profile: profile, food: food, weight: weight, health: health)
    }
}
#endif
