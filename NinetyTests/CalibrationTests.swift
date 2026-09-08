import Foundation
import Testing
@testable import Ninety

/// The calibration window — seven days (ADR 0018), counted in calendar days.
///
/// The ticket names the two things that break a countdown, and both are here: a
/// date change and a timezone change. Neither is exotic. The first happens every
/// night to every user, and the second happens to anyone who flies anywhere
/// during their first week.
@MainActor
@Suite("Calibration window")
struct CalibrationTests {
    private static func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        return calendar
    }

    private static let utc = calendar("UTC")

    private static func moment(_ day: Int, hour: Int = 9, in calendar: Calendar = utc) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour)) ?? .distantPast
    }

    /// ADR 0018. The one place the number lives.
    @Test("the window is seven days")
    func theWindowIsSevenDays() {
        #expect(CalibrationWindow.days == 7)
    }

    @Test("the countdown runs 7 to 0 over the week")
    func countdownRunsToZero() {
        let window = CalibrationWindow(startedAt: Self.moment(8))

        #expect(window.daysRemaining(on: Self.moment(8), calendar: Self.utc) == 7)
        #expect(window.daysRemaining(on: Self.moment(9), calendar: Self.utc) == 6)
        #expect(window.daysRemaining(on: Self.moment(14), calendar: Self.utc) == 1)
        #expect(window.daysRemaining(on: Self.moment(15), calendar: Self.utc) == 0)
        #expect(window.hasClosed(on: Self.moment(15), calendar: Self.utc))
        #expect(!window.hasClosed(on: Self.moment(14), calendar: Self.utc))
    }

    /// Signing up at ten to midnight must not spend a day of the window in ten
    /// minutes. Both ends are collapsed to the start of their day first, which
    /// is what makes the count whole days rather than elapsed hours.
    @Test("a late-evening start still gets a full first day")
    func lateStartKeepsTheWholeDay() {
        let lateStart = CalibrationWindow(startedAt: Self.moment(8, hour: 23))

        #expect(lateStart.daysRemaining(on: Self.moment(8, hour: 23), calendar: Self.utc) == 7)
        #expect(lateStart.daysRemaining(on: Self.moment(9, hour: 0), calendar: Self.utc) == 6)
    }

    /// The date change. Crossing midnight moves the countdown by exactly one,
    /// with no fraction to round.
    @Test("the countdown moves by one across a date change, not by a fraction")
    func countdownSurvivesADateChange() {
        let window = CalibrationWindow(startedAt: Self.moment(8))

        let beforeMidnight = window.daysRemaining(on: Self.moment(10, hour: 23), calendar: Self.utc)
        let afterMidnight = window.daysRemaining(on: Self.moment(11, hour: 0), calendar: Self.utc)

        #expect(beforeMidnight - afterMidnight == 1)
    }

    /// The timezone change. Both boundaries are resolved in the same calendar,
    /// so moving between zones cannot silently consume or invent a day.
    @Test("the countdown is the same number of whole days in another timezone")
    func countdownSurvivesATimezoneChange() {
        let tokyo = Self.calendar("Asia/Tokyo")
        let losAngeles = Self.calendar("America/Los_Angeles")
        let started = Self.moment(8, hour: 12)
        let today = Self.moment(10, hour: 12)

        let window = CalibrationWindow(startedAt: started)

        #expect(window.daysRemaining(on: today, calendar: Self.utc) == 5)
        #expect(window.daysRemaining(on: today, calendar: tokyo) == 5)
        #expect(window.daysRemaining(on: today, calendar: losAngeles) == 5)
    }

    /// Never negative and never above the window, whatever date it is asked
    /// about — a countdown reading "-3 days to go" is worse than no countdown.
    @Test("the countdown is clamped at both ends")
    func countdownIsClamped() {
        let window = CalibrationWindow(startedAt: Self.moment(8))

        #expect(window.daysRemaining(on: Self.moment(30), calendar: Self.utc) == 0)
        #expect(window.daysRemaining(on: Self.moment(1), calendar: Self.utc) == 7)
    }

    @Test("the chip says days, and says day on the last one")
    func chipReadsProperly() {
        #expect(CalibrationState.calibrating(daysRemaining: 6).chip == "CALIBRATING · 6 days to go")
        #expect(CalibrationState.calibrating(daysRemaining: 1).chip == "CALIBRATING · 1 day to go")
        #expect(CalibrationState.closed(on: .now).chip == nil)
    }

    // MARK: - The recorder

    private func makeRecorder(createdAt: Date) -> (CalibrationRecorder, Profile) {
        let profile = Profile(id: UUID(), createdAt: createdAt)
        return (CalibrationRecorder(profiles: MockProfileRepository(profile: profile)), profile)
    }

    @Test("the window is open, and unstamped, during the first week")
    func openWindowIsNotStamped() {
        let (recorder, profile) = makeRecorder(createdAt: Self.moment(8))

        let state = recorder.state(on: Self.moment(11), calendar: Self.utc)

        #expect(state == CalibrationState.calibrating(daysRemaining: 4))
        #expect(profile.calibrationCompletedAt == nil, "null means still calibrating, and it still is")
        #expect(!profile.isCalibrated)
    }

    /// `profiles.calibration_completed_at` set and honoured — the story's own
    /// acceptance criterion, and the stamp is written once.
    @Test("the window stamps itself closed exactly once, then is read from the stamp")
    func closingStampsOnce() {
        let (recorder, profile) = makeRecorder(createdAt: Self.moment(8))
        let closingDay = Self.moment(15)

        #expect(recorder.state(on: closingDay, calendar: Self.utc) == CalibrationState.closed(on: closingDay))
        #expect(profile.calibrationCompletedAt == closingDay)
        #expect(profile.isCalibrated)

        // Asked again a week later, the answer comes from the stamp rather than
        // being rewritten with a newer date.
        #expect(recorder.state(on: Self.moment(22), calendar: Self.utc) == CalibrationState.closed(on: closingDay))
        #expect(profile.calibrationCompletedAt == closingDay)
    }

    /// A failed write must not trap the user in calibration forever. The state
    /// is computed from the window; the stamp is a record of it, not the source.
    @Test("a stamp that does not persist still reports the window as closed")
    func failedStampStillReportsClosed() {
        let profile = Profile(id: UUID(), createdAt: Self.moment(8))
        let profiles = MockProfileRepository(profile: profile)
        profiles.saveError = RepositoryError.noProfile
        let recorder = CalibrationRecorder(profiles: profiles)

        #expect(recorder.state(on: Self.moment(15), calendar: Self.utc) == CalibrationState.closed(on: Self.moment(15)))
    }

    @Test("there is no window before there is a profile")
    func noProfileMeansNoWindow() {
        let recorder = CalibrationRecorder(profiles: MockProfileRepository())

        #expect(recorder.state(on: Self.moment(15), calendar: Self.utc) == nil)
    }
}
