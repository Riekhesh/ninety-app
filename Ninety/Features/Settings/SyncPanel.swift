import SwiftUI

/// Where the day's logging currently is, and nothing more.
///
/// **This panel is the instrument the airplane-mode day is read off.** The
/// Phase 1 exit criterion asks for a real day with the radio off, reconciled
/// cleanly on reconnect, and "reconciled cleanly" is not something you can see
/// by looking at a list of meals — the whole point of ADR 0005 is that the list
/// looks identical either way. So the count of what has not gone up yet is a
/// surface rather than a log line: it is the only place in the app where the
/// difference between working offline and having quietly lost a write is
/// visible.
///
/// It is also, deliberately, the only place. Everywhere else the app behaves as
/// though the network does not exist, because in §04's terms it does not: a log
/// is written locally and rendered immediately, always. A badge on Matchday
/// counting unsent rows would be a tracker asking the user to care about its
/// plumbing on the screen they open to log breakfast.
struct SyncPanel: View {
    let status: SyncStatus
    /// Parked rows, when the headline is about something else. A day underground
    /// can have forty changes waiting and one that has stopped trying, and one
    /// line cannot say both.
    let stuck: Int

    var sendNow: () -> Void
    var retryStuck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            Text(SyncCopy.heading)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)

            Text(headline)
                .ninetyType(.title3)
                .foregroundStyle(Ninety.Colour.textPrimary)

            Text(detail)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

            if case .upToDate(let sent) = status, let sent {
                Text(SyncCopy.lastSent(at: sent))
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }

            if case .waiting = status {
                Button(SyncCopy.syncNow, action: sendNow)
                    .ninetyType(.callout)
                    .foregroundStyle(Ninety.Colour.accent)
            }

            // The stuck line appears under either headline: as the headline's
            // own detail when everything left is parked, and as a second line
            // when there is live work in front of it.
            if stuck > 0, !isStuckHeadline {
                Text(SyncCopy.stuck(stuck))
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }

            if stuck > 0 {
                Button(SyncCopy.tryAgain, action: retryStuck)
                    .ninetyType(.callout)
                    .foregroundStyle(Ninety.Colour.accent)
            }
        }
        .chalkPanel(padding: Ninety.Space.lg)
    }

    private var isStuckHeadline: Bool {
        if case .stuck = status { return true }
        return false
    }

    private var headline: String {
        switch status {
        case .upToDate: SyncCopy.upToDate
        case .waiting(let changes): SyncCopy.waiting(changes)
        case .sending: SyncCopy.sending
        case .stuck(let changes): SyncCopy.stuck(changes)
        case .noProject: SyncCopy.noProject
        }
    }

    private var detail: String {
        switch status {
        case .upToDate: SyncCopy.upToDateDetail
        case .waiting, .sending: SyncCopy.waitingDetail
        case .stuck: SyncCopy.stuckDetail
        case .noProject: SyncCopy.noProjectDetail
        }
    }
}

#if DEBUG
@MainActor
private func previewPanel(_ status: SyncStatus, stuck: Int = 0) -> some View {
    SyncPanel(status: status, stuck: stuck, sendNow: {}, retryStuck: {})
        .padding(Ninety.Space.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Pitch())
}

#Preview("Sync · up to date") {
    previewPanel(.upToDate(lastSentAt: .now))
}

#Preview("Sync · a day underground") {
    previewPanel(.waiting(changes: 23), stuck: 1)
}

#Preview("Sync · stopped asking") {
    previewPanel(.stuck(changes: 2))
}

#Preview("Sync · accessibility 5") {
    previewPanel(.waiting(changes: 23), stuck: 1)
        .dynamicTypeSize(.accessibility5)
}
#endif
