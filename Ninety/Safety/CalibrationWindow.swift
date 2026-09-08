import Foundation

/// The window before the first tier — **seven days** (ADR 0018).
///
/// §2.3 opened with fourteen and ADR 0018 halved it: a 14-day window means a new
/// user does not see the one thing the product is for until their third week,
/// and §1.5 records that the first fortnight is exactly when weight-tracking apps
/// get abandoned. The ADR states the cost — a thinner baseline, less room for
/// outlier rejection — rather than pretending there is not one.
///
/// **Seven calendar days, not seven logged days.** A countdown a user can shorten
/// by logging more is a streak mechanic wearing a baseline's clothes, and §10
/// rules out exactly that pressure. Calendar days are not gameable because they
/// cannot be earned.
///
/// This is the only place the number seven appears in Swift.
struct CalibrationWindow: Equatable, Sendable {
    static let days = 7

    /// Any moment on the first day. The window is measured from the *start* of
    /// this day, so signing up at 23:50 does not spend a day of it in ten
    /// minutes.
    let startedAt: Date

    init(startedAt: Date) {
        self.startedAt = startedAt
    }

    /// The profile's creation is the start: the row is written when consent is
    /// given, immediately before Pre-Season, so it is the day the user set the
    /// app up.
    init(profile: Profile) {
        self.init(startedAt: profile.createdAt)
    }

    /// Midnight at the start of the day the window closes.
    func closes(_ calendar: Calendar) -> Date {
        let firstDay = calendar.startOfDay(for: startedAt)
        return calendar.date(byAdding: .day, value: Self.days, to: firstDay) ?? firstDay
    }

    /// Whole days left, `0...days`.
    ///
    /// **Both ends are collapsed to the start of their day before subtracting**,
    /// which is what makes the countdown survive the two cases the ticket names.
    /// A date change is then a change of one whole day rather than of a fraction
    /// that rounds unpredictably; and a timezone change moves both boundaries in
    /// the same direction at once, so flying east cannot silently consume a day
    /// — the same calendar answers both halves of the subtraction.
    func daysRemaining(on day: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: day)
        let remaining = calendar.dateComponents([.day], from: today, to: closes(calendar)).day ?? 0
        return min(max(remaining, 0), Self.days)
    }

    func hasClosed(on day: Date, calendar: Calendar) -> Bool {
        daysRemaining(on: day, calendar: calendar) == 0
    }
}

/// What the app shows in a tier slot.
///
/// Two cases and no "unknown": a profile always has a creation date, so the
/// window always has an answer. Screens that render a division switch on this
/// rather than on a nil check against the timestamp — a null column means
/// "still calibrating", which is not the same statement as "we do not know".
enum CalibrationState: Equatable, Sendable {
    case calibrating(daysRemaining: Int)
    case closed(on: Date)

    /// `CALIBRATING · 6 days to go`, in the copy deck's words. Singular at one,
    /// because "1 days to go" is the kind of thing that makes an app feel
    /// unfinished on the day it matters most.
    var chip: String? {
        switch self {
        case .calibrating(let remaining):
            "CALIBRATING · \(remaining) \(remaining == 1 ? "day" : "days") to go"
        case .closed:
            nil
        }
    }

    var isCalibrating: Bool {
        if case .calibrating = self { return true }
        return false
    }
}

/// Reads the window, and stamps it closed exactly once.
///
/// `profiles.calibration_completed_at` is null while the window is open and
/// carries the moment it closed afterwards. Something has to write that, and it
/// is not a background job: the app has no scheduler in Phase 1, and a column
/// that only becomes true while the app is open is fine — nothing reads it while
/// nobody is looking.
///
/// The write is idempotent and the read never depends on it. `state(on:)`
/// computes the answer from the window and returns it whether or not the stamp
/// landed, so a failed write means a missing timestamp rather than a user stuck
/// in calibration forever.
@MainActor
struct CalibrationRecorder {
    let profiles: any ProfileRepositoryProtocol

    /// Nil before Pre-Season has created a profile — there is no window yet.
    func state(on day: Date, calendar: Calendar) -> CalibrationState? {
        guard let profile = profiles.current() else { return nil }

        if let closedAt = profile.calibrationCompletedAt {
            return .closed(on: closedAt)
        }

        let window = CalibrationWindow(profile: profile)
        guard window.hasClosed(on: day, calendar: calendar) else {
            return .calibrating(daysRemaining: window.daysRemaining(on: day, calendar: calendar))
        }

        // The day it closes, and only then. Stamped with the moment the app
        // noticed rather than with the window's own boundary: the boundary is
        // derivable from `created_at` at any time, and what is worth recording
        // is when the app acted on it.
        profile.calibrationCompletedAt = day
        do {
            try profiles.save(profile)
        } catch {
            Log.data.error("Calibration close did not persist: \(error.localizedDescription, privacy: .public)")
        }
        return .closed(on: day)
    }
}
