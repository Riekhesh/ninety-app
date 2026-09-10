import Foundation

/// Every string the sync panel renders, in one place.
///
/// Same reasoning as `SettingsCopy` and `SubOnCopy`: this is a *test surface*.
/// `SafetyCopyTests` sweeps what the app actually shows, and a hand-copied
/// inventory decays the first time somebody edits a view.
///
/// The voice matters more here than the layout does. A queue that has not
/// drained is not a problem the user caused or can solve, and every line below
/// says the same two things — where the data is, and that it is safe. The copy
/// deck's existing offline line sets the register: *"Saved on your phone. It'll
/// sync when you're back online"* — reassuring, not a warning.
enum SyncCopy {
    static let heading = "Sync"

    static let upToDate = "Everything's on the server."
    static let upToDateDetail = """
        Ninety keeps a copy of what you log, so a lost or replaced phone doesn't take your \
        days with it.
        """

    static let waitingDetail = """
        Saved on your phone and readable right now. They'll go up on their own when there's \
        a signal.
        """

    static let sending = "Sending…"

    static let stuckDetail = """
        The server didn't take these, so Ninety has stopped asking for now. Everything is \
        still on this phone and nothing has been lost.
        """

    static let syncNow = "Send them now"
    static let tryAgain = "Try these again"

    static let noProject = "This build has no project in it."
    static let noProjectDetail = """
        Everything you log is saved on this phone and stays there. Nothing is being sent \
        anywhere.
        """

    /// "1 change waiting" · "12 changes waiting".
    static func waiting(_ count: Int) -> String {
        "\(count) \(changes(count)) waiting"
    }

    /// Not "failed" and not "stuck on the user": the sentence is about where
    /// the changes are, which is on the phone, safely.
    static func stuck(_ count: Int) -> String {
        "\(count) \(changes(count)) still here"
    }

    static func lastSent(at moment: Date) -> String {
        "Last sent \(moment.formatted(date: .omitted, time: .shortened))"
    }

    private static func changes(_ count: Int) -> String {
        count == 1 ? "change" : "changes"
    }

    /// Everything above, for the S5 sweep. Listed by reference rather than
    /// retyped, so a new string is one edit and not two. The two formatted
    /// lines are included at both plural forms, because that is where a
    /// hand-written plural would go wrong.
    static let all: [String] = [
        heading,
        upToDate, upToDateDetail,
        waitingDetail, sending, stuckDetail,
        syncNow, tryAgain,
        noProject, noProjectDetail,
        waiting(1), waiting(12),
        stuck(1), stuck(2),
    ]
}
