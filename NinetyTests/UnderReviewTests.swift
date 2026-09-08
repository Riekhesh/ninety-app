import Foundation
import Testing
@testable import Ninety

/// P1-F — the photo route, and the screen that stands between an estimate and a
/// logged row.
///
/// The Under Review ticket is the one tagged `safety` and `gate`, and its first
/// criterion is the one worth the most tests: *"no estimate can reach
/// `food_logs` without an explicit confirmation."*
@Suite("Under Review and the photo estimate")
@MainActor
struct UnderReviewTests {
    static func estimate(
        items: [EstimatedItem] = MealEstimate.artboard.items,
        storagePath: String = "user/meal.jpg"
    ) -> MealEstimate {
        MealEstimate(
            items: items,
            notes: "",
            storagePath: storagePath,
            rawOutput: Data(#"{"items":[]}"#.utf8),
            model: "test-model",
            latency: 2.1
        )
    }

    static func harness(now: Date = Date()) -> (SubOnModel, MockFoodRepository) {
        let user = UUID()
        let foods = MockFoodRepository(userID: user, now: now)
        return (
            SubOnModel(
                foods: foods,
                profiles: MockProfileRepository(profile: Profile(id: user)),
                weights: MockWeightRepository(),
                now: { now }
            ),
            foods
        )
    }

    // MARK: - The gate

    @Test("nothing is written until the decision is given")
    func nothingIsLoggedBeforeConfirmation() {
        let (model, foods) = Self.harness()
        let review = UnderReviewModel(estimate: Self.estimate())

        // Everything a user can do on the screen short of the button.
        review.nudge(review.items[0].id, up: true)
        review.setGrams(200, for: review.items[1].id)
        review.remove(review.items[2].id)
        review.add(name: "Olive oil", grams: 12, kcal: 106)

        #expect(foods.storedLogs.isEmpty)
        #expect(foods.storedEstimates.isEmpty)
        #expect(!review.isConfirmed)

        review.confirm(using: model)
        #expect(foods.storedLogs.count == 3)
    }

    @Test("confirming twice writes one meal")
    func confirmingIsIdempotent() {
        let (model, foods) = Self.harness()
        let review = UnderReviewModel(estimate: Self.estimate())

        #expect(review.confirm(using: model))
        let after = foods.storedLogs.count
        // A double tap on a slow phone. The second copy of a meal is
        // indistinguishable from a real one, so it must not exist.
        #expect(!review.confirm(using: model))
        #expect(foods.storedLogs.count == after)
    }

    @Test("an empty sheet cannot be confirmed")
    func emptySheetCannotBeConfirmed() {
        let (model, foods) = Self.harness()
        let review = UnderReviewModel(estimate: Self.estimate())
        for item in review.items { review.remove(item.id) }

        #expect(review.isEmpty)
        #expect(!review.confirm(using: model))
        #expect(foods.storedLogs.isEmpty)
    }

    @Test("every confirmed item is written as a photo log")
    func confirmedItemsAreLoggedAsPhoto() {
        let (model, foods) = Self.harness()
        let review = UnderReviewModel(estimate: Self.estimate())
        review.confirm(using: model)

        #expect(foods.storedLogs.count == 3)
        #expect(foods.storedLogs.allSatisfy { $0.entryMethod == .photo })
        #expect(foods.storedLogs.allSatisfy { $0.grams > 0 })
    }

    // MARK: - Correction, and the record of it

    @Test("one tap moves the portion and takes the energy with it")
    func oneTapCorrects() throws {
        let review = UnderReviewModel(estimate: Self.estimate())
        let before = review.items[0]
        let density = before.kcal.midpoint / before.grams.midpoint

        review.nudge(before.id, up: true)
        let after = try #require(review.items.first)

        #expect(after.confirmedGrams == before.confirmedGrams + UnderReviewModel.step(forGrams: before.confirmedGrams))
        #expect(after.confirmedKcal == (after.confirmedGrams * density).rounded())
        #expect(after.wasCorrected)
    }

    @Test("a portion cannot be nudged below zero")
    func portionsStopAtZero() {
        let review = UnderReviewModel(estimate: Self.estimate())
        let id = review.items[0].id
        for _ in 0..<100 { review.nudge(id, up: false) }
        #expect(review.items[0].confirmedGrams == 0)
    }

    /// *"`was_corrected` and `correction_delta` written to `photo_estimates` on
    /// every pass — that dataset is how the prompt improves later."*
    ///
    /// **Every pass**, including the ones where nothing moved. A dataset holding
    /// only corrections cannot tell "the model was right" from "nobody looked",
    /// and that distinction is most of its value.
    @Test("an untouched estimate still writes was_corrected and a delta")
    func untouchedEstimateStillWritesTheRecord() throws {
        let (model, foods) = Self.harness()
        let review = UnderReviewModel(estimate: Self.estimate())
        review.confirm(using: model)

        #expect(foods.storedEstimates.count == 3)
        for record in foods.storedEstimates {
            #expect(!record.wasCorrected)
            // Zero because the confirmed value is the midpoint, which is what
            // the screen starts on. A nil here would be the absence of a
            // measurement rather than a measurement of zero.
            let delta = try #require(record.correctionDelta)
            #expect(abs(delta) <= 0.5)
        }
    }

    @Test("a correction is recorded with its direction")
    func correctionDeltaIsSigned() throws {
        let (model, foods) = Self.harness()
        let review = UnderReviewModel(estimate: Self.estimate())
        let id = review.items[0].id
        let estimated = review.items[0].kcal.midpoint

        review.setGrams(review.items[0].confirmedGrams * 2, for: id)
        review.confirm(using: model)

        let record = try #require(foods.storedEstimates.first { $0.log?.nameSnapshot == "Greek yogurt" })
        #expect(record.wasCorrected)
        let delta = try #require(record.correctionDelta)
        #expect(delta > 0)
        #expect(abs(delta - (review.items[0].confirmedKcal - estimated)) < 0.5)
    }

    /// §1.3 names this failure mode first: cooking oil and hidden sugar
    /// photograph as nothing at all and are frequently large. An item the user
    /// adds is recorded as a correction against an estimate of zero, so a miss
    /// shows up in the dataset rather than being invisible in it.
    @Test("something the model missed is recorded as a miss")
    func addedItemsRecordTheMiss() throws {
        let (model, foods) = Self.harness()
        let review = UnderReviewModel(estimate: Self.estimate(items: []))
        review.add(name: "Olive oil", grams: 12, kcal: 106)
        review.confirm(using: model)

        let record = try #require(foods.storedEstimates.first)
        #expect(record.wasCorrected)
        #expect(record.correctionDelta == 106)
        // The model had no opinion about something it never saw, and inventing
        // one would pollute the set this is being collected for.
        #expect(record.confidence == nil)
    }

    /// ADR 0010's condition for folding the benchmark into Phase 1.
    @Test("the photo, the model's output and the confirmed values persist together")
    func theSetStaysTogether() throws {
        let (model, foods) = Self.harness()
        let estimate = Self.estimate(storagePath: "abc/8f3e.jpg")
        let review = UnderReviewModel(estimate: estimate)
        review.confirm(using: model)

        let record = try #require(foods.storedEstimates.first)
        #expect(record.storagePath == "abc/8f3e.jpg")
        #expect(record.modelOutput == estimate.rawOutput)
        #expect(record.log != nil)
        #expect(record.confidence != nil)
    }

    @Test("a failed write is reported rather than reported as a log")
    func failedConfirmSurfaces() {
        let (model, foods) = Self.harness()
        foods.logError = RepositoryError.noProfile
        let review = UnderReviewModel(estimate: Self.estimate())

        #expect(!review.confirm(using: model))
        #expect(review.writeFailed)
        #expect(!review.isConfirmed)
    }

    // MARK: - The benchmark export

    @Test("the export is in the shape the spike's ground truth loader reads")
    func exportMatchesTheSpikeFormat() throws {
        let (model, foods) = Self.harness()
        UnderReviewModel(estimate: Self.estimate(storagePath: "abc/8f3e.jpg")).confirm(using: model)

        let csv = PhotoBenchmarkExport.groundTruthCSV(from: foods.photoEstimates(limit: 100))
        let lines = csv.split(separator: "\n").map(String.init)

        #expect(lines.first == "photo_id,item_name,actual_grams,actual_kcal,notes")
        #expect(lines.count == 4)
        // photo_id must equal the photo's filename stem — that is what joins a
        // row back to the object in the bucket.
        #expect(lines.dropFirst().allSatisfy { $0.hasPrefix("8f3e,") })
        // Provenance on every row, because these are confirmed values and not
        // weighed ones, and a file that escapes its documentation must still say so.
        #expect(lines.dropFirst().allSatisfy { $0.contains("NOT weighed") })
    }

    @Test("a food name containing a comma does not shift the columns")
    func csvEscapesCommas() {
        let escaped = PhotoBenchmarkExport.escaped("curry, rice and naan")
        #expect(escaped == "\"curry, rice and naan\"")
        #expect(PhotoBenchmarkExport.escaped("say \"cheese\"") == "\"say \"\"cheese\"\"\"")
        #expect(PhotoBenchmarkExport.escaped("banana") == "banana")
    }

    @Test("the photo id is the filename stem")
    func photoIDIsTheStem() {
        #expect(PhotoBenchmarkExport.photoID(from: "abc-123/8f3e-99.jpg") == "8f3e-99")
        #expect(PhotoBenchmarkExport.photoID(from: "meal-001") == "meal-001")
    }
}
