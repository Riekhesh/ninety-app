import Foundation

/// Every string the four logging routes render, in one place.
///
/// Same reasoning as `PreSeasonCopy` and `SettingsCopy`: this is a *test
/// surface*, not a strings file. `SafetyCopyTests` sweeps the copy the app
/// actually shows, and a hand-copied inventory decays the first time somebody
/// edits a view.
///
/// `design/spec/04-copy-deck.md` §4 is the source. Change it there first.
enum SubOnCopy {
    static let masthead = "Sub On"

    // MARK: - The routes

    static let routesLabel = "How are you logging it?"
    static let manualRoute = "Manual"
    static let searchRoute = "Search"
    static let barcodeRoute = "Barcode"
    static let photoRoute = "Snap"

    // MARK: - The team sheet

    static let squadHeading = "The Squad"
    static let squadDetail = "Tap to bring on"
    static let benchHeading = "On the Bench"
    static let benchDetail = "Recent"
    static let emptySquadHeadline = "No squad yet."
    static let emptySquad = """
        The foods you log most turn up here after a couple of days, so logging the same \
        breakfast twice is one tap the second time.
        """

    // MARK: - Today

    static let todayHeading = "Today"
    static let todayDetail = "Tap to correct"
    static let nothingLoggedYet = "Nothing logged yet today."
    static let nothingLoggedDetail = """
        What you log turns up here, so a tap you did not mean is one you can take straight \
        back out.
        """
    static let editTitle = "Correct it"
    static let saveEdit = "Save"

    /// The band remaining, on the artboard as ROOM LEFT TODAY.
    static let roomLeft = "Room left today"
    static let roomLeftUnknown = "Finish Pre-Season to see your band."

    // MARK: - Path 0 · manual

    static let manualTitle = "Add it yourself"
    static let manualDetail = """
        Works with no signal, and it is the route that carries most days. Name it, say how \
        much, and it is logged.
        """
    static let nameField = "What was it?"
    static let gramsField = "How much?"
    static let kcalField = "Calories"
    static let proteinField = "Protein"
    static let carbsField = "Carbs"
    static let fatField = "Fat"
    static let macrosOptional = "Macros are optional. Calories are what the band is made of."
    static let quickAdd = "Quick add by calories"
    static let quickAddDetail = "When you only know the number"
    static let saveForNextTime = "Keep this for next time"
    static let saveForNextTimeDetail = """
        Adds it to your own foods, so it turns up in search and on the team sheet.
        """
    static let logAction = "Log it"

    // MARK: - Path 1 · search

    static let searchPlaceholder = "Search foods or scan a barcode"
    static let resultsHeading = "Results"
    static let yourFoodsHeading = "On this phone"
    static let searchingNote = "Looking…"

    static func noMatch(for query: String) -> String { "No match for \"\(query)\"" }

    static let addItManually = "Add it manually"
    static let catalogueNote = """
        Foods come from Open Food Facts and USDA. Anything missing, you can add yourself.
        """
    static let offlineNote = "Saved on your phone. It'll sync when you're back online."

    // MARK: - Path 2 · barcode

    static let barcodePrompt = "Point at the barcode"
    static let barcodeNotFound = "No match for that barcode"
    static let barcodeSearchInstead = "Search by name instead"
    static let barcodeSaveAsCustom = "Add it as your own food"
    static let barcodeUnavailable = "This phone can't scan barcodes."
    static let barcodeNoCamera = """
        Ninety needs the camera to read a barcode. Search and manual entry both still work.
        """

    // MARK: - Path 3 · photo

    static let photoPrompt = "Photograph your meal"
    static let photoWorking = "Estimating…"
    static let photoTakePhoto = "Take a photo"
    static let photoChoosePhoto = "Choose a photo"
    static let photoRetake = "Retake"

    static let estimateOffline = """
        Ninety can't reach the estimator right now.
        """
    static let estimateUnreadable = """
        That photo didn't come back as anything Ninety can read.
        """
    static let estimateUnavailable = """
        The estimator isn't answering right now.
        """
    static let photoCapReached = """
        That's today's photo estimates used up.
        """
    /// The line under every photo failure. §1.3's whole framing of this feature:
    /// it is a helper, so losing it costs a shortcut and never a day's logging.
    static let estimateFallback = "The other three routes all still work, and none of them needs a signal."

    // MARK: - Under Review

    static let underReviewMasthead = "Under Review"
    static let underReviewEyebrow = "Estimates, not measurements"
    static let underReviewBody = """
        Ninety is guessing from a photo. It misses cooking oil, hidden sugar and portion \
        size — trained dietitians are 20–30% out and models do worse.
        """
    static let underReviewBody2 = """
        That's fine for tracking a trend: a consistent error still shows the direction \
        correctly. Correct anything that looks wrong.
        """
    static let callsHeading = "The calls"
    static let lowConfidence = "Ninety isn't confident about this one — worth a look."
    static let adjustPortion = "Adjust portion"
    static let removeItem = "Remove"
    static let addMissedItem = "Something it missed"
    static let addMissedDetail = "If you give it"
    static let mealTotal = "Meal total"
    static let confirmAction = "Give the decision"
    static let nothingLeftToLog = "Nothing left on the sheet. Retake the photo, or add it yourself."
    static let modelNotesHeading = "What it couldn't tell"

    /// Says where a derived calorie figure came from, so a number that moves
    /// when you edit a *different* field does not read as the app being broken.
    static func derivedFrom(kcalPer100g: Double) -> String {
        "Following the portion, at \(Int(kcalPer100g.rounded())) kcal / 100 g. Change it yourself to stop."
    }

    /// "3 found" — the count beside The Calls heading.
    static func found(_ count: Int) -> String {
        count == 1 ? "1 found" : "\(count) found"
    }

    /// The model's own figure, kept beside the confirmed one. It is what the
    /// user is correcting *against*, so it stays on screen after a correction
    /// rather than being replaced by it.
    static func estimated(_ text: String) -> String { "Estimated \(text)" }

    /// The artboard's "APPS" — how many times a food has been logged.
    static func appearances(_ count: Int) -> String {
        count == 1 ? "1 app" : "\(count) apps"
    }

    /// The stepper's spoken label. It names the food and the size of the step,
    /// because "increase" on its own tells a screen-reader user neither what
    /// they are about to change nor by how much.
    static func nudgeLabel(up: Bool, item: String, grams: Int) -> String {
        up ? "Increase \(item) by \(grams) grams" : "Reduce \(item) by \(grams) grams"
    }

    static func confirmLabel(items: Int) -> String {
        items == 1 ? "Give the decision. Log 1 item." : "Give the decision. Log \(items) items."
    }

    // MARK: - Shared

    static let added = "Added"
    static let undo = "Undo"
    static let dismiss = "Dismiss"
    static let close = "Close"
    static let kcalUnit = "kcal"
    static let lockedRow = "Locked"
    static let lockedNote = "Logs older than 48 hours can't be edited. It keeps scores honest."
    static let writeFailed = "That didn't save. Try again."

    /// Everything above, for the S5 sweep. Listed by reference rather than
    /// retyped, so a new string is one edit and not two.
    static let all: [String] = [
        masthead,
        routesLabel, manualRoute, searchRoute, barcodeRoute, photoRoute,
        squadHeading, squadDetail, benchHeading, benchDetail,
        emptySquadHeadline, emptySquad, roomLeft, roomLeftUnknown,
        manualTitle, manualDetail, nameField, gramsField, kcalField,
        proteinField, carbsField, fatField, macrosOptional,
        quickAdd, quickAddDetail, saveForNextTime, saveForNextTimeDetail, logAction,
        searchPlaceholder, resultsHeading, yourFoodsHeading, searchingNote,
        noMatch(for: "quinoa salad"), addItManually, catalogueNote, offlineNote,
        barcodePrompt, barcodeNotFound, barcodeSearchInstead, barcodeSaveAsCustom,
        barcodeUnavailable, barcodeNoCamera,
        photoPrompt, photoWorking, photoTakePhoto, photoChoosePhoto, photoRetake,
        estimateOffline, estimateUnreadable, estimateUnavailable, photoCapReached,
        estimateFallback,
        underReviewMasthead, underReviewEyebrow, underReviewBody, underReviewBody2,
        callsHeading, lowConfidence, adjustPortion, removeItem,
        addMissedItem, addMissedDetail, mealTotal, confirmAction,
        nothingLeftToLog, modelNotesHeading,
        confirmLabel(items: 1), confirmLabel(items: 3),
        todayHeading, todayDetail, nothingLoggedYet, nothingLoggedDetail,
        editTitle, saveEdit, derivedFrom(kcalPer100g: 133),
        found(1), found(3), estimated("340 ±50"), appearances(1), appearances(9),
        nudgeLabel(up: true, item: "Greek yogurt", grams: 10),
        nudgeLabel(up: false, item: "Greek yogurt", grams: 10),
        added, undo, dismiss, close, kcalUnit, lockedRow, lockedNote, writeFailed,
    ]
}
