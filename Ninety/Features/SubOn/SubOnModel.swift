import Foundation
import Observation

/// Sub On, as state.
///
/// ADR 0004's shape again: an `@Observable` between the views and the
/// repositories. It owns the four things every route needs and none of the
/// routes should each work out for itself — which of the four is showing, the
/// team sheet, how much room is left in the band today, and the single write
/// path that all four converge on.
///
/// **Every write here is local and returns immediately.** ADR 0005: a gym has no
/// signal, a restaurant basement has no signal, and those are where people log
/// food. Nothing on this type is `async`, because nothing on it touches the
/// network — the two routes that do (search and photo) own that themselves and
/// hand the result back as a `FoodLogDraft` like everything else.
@MainActor
@Observable
final class SubOnModel {
    /// The four routes, in the order the sheet offers them.
    ///
    /// > **Deviation from the artboards, recorded in `DESIGN.md`.**
    /// > `SubOn.dc.html` draws four chips as SEARCH · BARCODE · SNAP · SQUAD.
    /// > The Squad is the list underneath rather than a way of logging, so the
    /// > fourth chip here is Manual — which the ticket requires to be visible as
    /// > a route, and which the artboard instead puts at the bottom of the
    /// > screen as "Quick add by calories". Both are still reachable.
    enum Route: String, CaseIterable, Identifiable, Sendable {
        case search
        case barcode
        case photo
        case manual

        var id: String { rawValue }

        var title: String {
            switch self {
            case .search: SubOnCopy.searchRoute
            case .barcode: SubOnCopy.barcodeRoute
            case .photo: SubOnCopy.photoRoute
            case .manual: SubOnCopy.manualRoute
            }
        }

        /// SF Symbols, for the same reason the tab bar uses them: these have to
        /// hold at every size class and at accessibility sizes.
        var symbol: String {
            switch self {
            case .search: "magnifyingglass"
            case .barcode: "barcode.viewfinder"
            case .photo: "camera"
            case .manual: "square.and.pencil"
            }
        }
    }

    /// How many rows each list gets. Five and four, because the sheet has to
    /// stay one screen at the Large baseline and the scroll is the fallback
    /// rather than the design.
    static let squadLimit = 5
    static let benchLimit = 4

    // MARK: - What the screen shows

    /// Nil is the team sheet — the screen you land on, because for most meals
    /// the answer is already on it.
    var route: Route?

    /// A food on its way to a portion screen.
    ///
    /// It lives here rather than on whichever screen found it because a
    /// `NavigationStack` registers destinations by type: search and barcode both
    /// end on the same screen, and declaring that destination twice in one stack
    /// is a runtime warning and an ambiguity about which one wins. One binding,
    /// one declaration, on the sheet that owns the stack.
    var portion: PortionPrefill?

    private(set) var squad: [FoodHabit] = []
    private(set) var bench: [FoodHabit] = []

    /// Everything logged today, newest first.
    ///
    /// **The screen had no way to see this, and that was the hole.** Four routes
    /// wrote rows and nothing read them back: the undo strip covered only the
    /// last entry and vanished the moment anything else was logged, so a Squad
    /// row tapped twice by accident was permanent. §2.3's forty-eight-hour edit
    /// window has been in the repository and tested since P1-B and had no
    /// surface at all.
    ///
    /// Deliberately *not* Matchday's team sheet. That is P1-H and it is a
    /// different screen doing a different job — the band, the Form ring, the
    /// sparkline, the division. This is the list you check while you are still
    /// standing in the place you did the logging.
    private(set) var today: [FoodLog] = []

    /// Nil until Pre-Season has produced one. Nil renders as a sentence, never
    /// as a zero: a band nobody computed is a number nobody measured.
    private(set) var band: CalorieBand?
    private(set) var loggedTodayKcal: Double = 0

    /// The last thing logged, for the undo strip. Cleared when it is undone or
    /// when the sheet is dismissed.
    private(set) var lastLogged: FoodLog?

    /// A write that did not land. Shown rather than swallowed — a screen that
    /// says it logged and did not is how a day's streak disappears silently.
    private(set) var writeFailed = false

    // MARK: - Dependencies

    /// Not private: the search route builds its own model over the same
    /// repository, and handing it the repository is honest about the dependency
    /// in a way that proxying five methods through here would not be.
    let foods: any FoodRepositoryProtocol
    private let profiles: any ProfileRepositoryProtocol
    private let weights: any WeightRepositoryProtocol
    private let calendar: Calendar
    private let now: () -> Date

    init(
        foods: any FoodRepositoryProtocol,
        profiles: any ProfileRepositoryProtocol,
        weights: any WeightRepositoryProtocol,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.foods = foods
        self.profiles = profiles
        self.weights = weights
        self.calendar = calendar
        self.now = now
        refresh()
    }

    // MARK: - Derived

    /// The masthead's meta line. Which meal it is now, in the user's calendar.
    var slot: MealSlot { MealSlot.of(now(), calendar: calendar) }

    /// What is left in the band, and it is allowed to be negative.
    ///
    /// Above the band is a fact rather than an error — `BandState.above` is
    /// `.neutral` and the token set has no red for it — so this returns the
    /// number rather than clamping at zero and pretending the day is still open.
    var roomLeftKcal: Int? {
        band.map { $0.centre - Int(loggedTodayKcal.rounded()) }
    }

    var bandState: BandState? {
        band.map { BandState.of(kcal: Int(loggedTodayKcal.rounded()), band: $0) }
    }

    // MARK: - Reading

    func refresh() {
        let moment = now()
        let habits = TeamSheet.habits(
            from: foods.recentLogs(since: moment.addingTimeInterval(-TeamSheet.window), limit: 500)
        )
        squad = TeamSheet.squad(from: habits, limit: Self.squadLimit)
        bench = TeamSheet.bench(from: habits, excluding: squad, limit: Self.benchLimit)

        // Newest first: the thing you just logged, and most likely the thing
        // you want to correct, is the thing at the top.
        today = foods.logs(on: moment, calendar: calendar).sorted { $0.loggedAt > $1.loggedAt }
        loggedTodayKcal = today.reduce(0) { $0 + $1.kcal }
        band = profiles.current().flatMap { profile in
            EnergyTarget.band(
                for: profile,
                weightKg: weights.recent(limit: 1).first?.kg,
                on: moment,
                calendar: calendar
            )
        }
    }

    // MARK: - Writing

    /// Bring a food on again at the portion it was last logged at.
    ///
    /// The whole of the "tap to bring on" claim: no screen, no field, no
    /// confirmation. The entry method is `manual` because that is what this is —
    /// a portion the user has already agreed to once, repeated, with nothing
    /// external involved.
    @discardableResult
    func log(_ habit: FoodHabit) -> FoodLog? {
        log(
            FoodLogDraft(
                food: nil,
                grams: habit.grams,
                kcal: habit.kcal,
                name: habit.name,
                entryMethod: .manual,
                loggedAt: now()
            )
        )
    }

    /// The one write path. Every route ends here.
    @discardableResult
    func log(_ draft: FoodLogDraft) -> FoodLog? {
        do {
            let entry = try foods.log(draft)
            lastLogged = entry
            writeFailed = false
            refresh()
            return entry
        } catch {
            writeFailed = true
            return nil
        }
    }

    /// A log and its estimate, together. Only Under Review calls this.
    @discardableResult
    func log(_ draft: FoodLogDraft, estimate: PhotoEstimateDraft) -> FoodLog? {
        do {
            let entry = try foods.log(draft, estimate: estimate)
            lastLogged = entry
            writeFailed = false
            refresh()
            return entry
        } catch {
            writeFailed = true
            return nil
        }
    }

    /// Creates a food the user typed, so it turns up next time.
    ///
    /// Returns nil on failure rather than throwing: the log itself does not
    /// depend on this succeeding, and losing the meal because the catalogue
    /// write failed would be the tail wagging the dog.
    @discardableResult
    func saveCustomFood(_ draft: FoodDraft) -> Food? {
        try? foods.saveFood(draft)
    }

    /// Caches a catalogue row locally, so the next search finds it with no
    /// signal. Best effort, for the same reason as above.
    @discardableResult
    func cache(_ food: CatalogueFood) -> Food? {
        try? foods.saveFood(food.draft)
    }

    /// Today's logs, by meal (ADR 0022).
    ///
    /// Was First Half / Second Half, which was derived and stored nowhere. It is
    /// still derived for almost every row — `FoodLog.mealSlot(calendar:)` falls
    /// back to `logged_at` — so this costs no keystroke at logging time; what
    /// changed is that a row the derivation got wrong can now be moved, and the
    /// move sticks.
    func today(in slot: MealSlot) -> [FoodLog] {
        today.filter { $0.mealSlot(calendar: calendar) == slot }
    }

    /// Which slot a log currently sits in, asked at the model's own calendar so
    /// a view never has to reach for one.
    func slot(of log: FoodLog) -> MealSlot { log.mealSlot(calendar: calendar) }

    /// Whether a log is still inside §2.3's window, asked at the model's own
    /// clock so a view never has to reach for one.
    func isEditable(_ log: FoodLog) -> Bool {
        log.isEditable(at: now())
    }

    /// Correct a portion after the fact.
    ///
    /// Refused past forty-eight hours by the repository, which is where the rule
    /// lives — the copy deck's line says so plainly rather than leaving a
    /// mysterious disabled control: *"Logs older than 48 hours can't be edited.
    /// It keeps scores honest."*
    @discardableResult
    func update(_ log: FoodLog, grams: Double, kcal: Double, mealSlot: MealSlot) -> Bool {
        do {
            try foods.update(
                log,
                grams: max(grams, 1),
                kcal: kcal,
                mealSlot: mealSlot,
                at: now(),
                calendar: calendar
            )
            writeFailed = false
            refresh()
            return true
        } catch {
            writeFailed = true
            return false
        }
    }

    /// Take a log back out, at any point in the window.
    ///
    /// The answer to a Squad row tapped twenty times: not a confirmation
    /// dialogue on the tap, which would cost the one-tap speed the whole screen
    /// is built on, but a list where the mistake is visible and removable.
    @discardableResult
    func delete(_ log: FoodLog) -> Bool {
        do {
            try foods.delete(log, at: now())
            if lastLogged?.id == log.id { lastLogged = nil }
            writeFailed = false
            refresh()
            return true
        } catch {
            writeFailed = true
            return false
        }
    }

    /// Takes the last log back.
    ///
    /// Inside the 48-hour window by construction — it was written seconds ago —
    /// so the lock cannot refuse it. It is still passed the moment rather than
    /// reading the clock inside the repository, because that is the rule
    /// everywhere else and an exception here would be the one that gets copied.
    func undoLast() {
        guard let entry = lastLogged else { return }
        do {
            try foods.delete(entry, at: now())
            lastLogged = nil
            refresh()
        } catch {
            writeFailed = true
        }
    }

    /// Clears the undo strip without undoing anything — the user moved on.
    func dismissUndo() {
        lastLogged = nil
    }
}
