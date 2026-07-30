//
//  NotchHealthSpikeApp.swift
//  Spike A — app entry point and a minimal UI (§0.7)
//
//  THROWAWAY. The UI exists only so the spike can be driven on a device without a
//  debugger attached. §0.7's actual exit condition is the console output, but you
//  need buttons to trigger it and it is useful to see the data on the screen it will
//  eventually live on.
//

import HealthKit
import SwiftUI

@main
struct NotchHealthSpikeApp: App {
    var body: some Scene {
        WindowGroup {
            SpikeView()
        }
    }
}

struct SpikeView: View {
    // @State with an @Observable class is the iOS 17+ pattern, and the one Phase 1
    // uses for its ViewModels (ADR 0004). No ObservableObject, no @Published.
    @State private var spike = HealthSpike()

    var body: some View {
        NavigationStack {
            List {
                statusSection
                actionsSection

                if !spike.results.isEmpty {
                    ForEach(spike.results) { result in
                        resultSection(result)
                    }
                }

                gotchaSection
            }
            .navigationTitle("HealthKit spike")
        }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            LabeledContent("HealthKit available") {
                Text(spike.isAvailable ? "yes" : "no")
                    .foregroundStyle(spike.isAvailable ? .green : .red)
            }
            LabeledContent("Authorisation asked") {
                Text(spike.didRequestAuthorisation ? "yes" : "not yet")
            }
            Text(spike.statusLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Status")
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Request read authorisation") {
                Task { await spike.requestAuthorisation() }
            }
            .disabled(!spike.isAvailable || spike.isWorking)

            Button("Read last 30 days") {
                Task { await spike.readRecentHistory(days: 30) }
            }
            .disabled(!spike.isAvailable || spike.isWorking)

            Button("Read again (should be incremental)") {
                Task { await spike.readRecentHistory(days: 30) }
            }
            .disabled(!spike.isAvailable || spike.isWorking || spike.results.isEmpty)

            Button("Reset anchors", role: .destructive) {
                spike.resetAnchors()
            }
            .disabled(spike.isWorking)

            if spike.isWorking {
                HStack {
                    ProgressView()
                    Text("Working…").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("""
                Run "Read last 30 days" twice. The first pass reports many new \
                samples from the anchored query; the second should report close to \
                zero. That difference IS the spike — it is what §1.4 calls "the \
                entire trick", and it is the difference between an app that opens \
                instantly and one that hangs for four seconds.
                """)
        }
    }

    private func resultSection(_ result: TypeReadResult) -> some View {
        Section {
            if let error = result.error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }

            LabeledContent("New samples") { Text("\(result.sampleCount)") }
            LabeledContent("Anchor saved") { Text(result.anchorPersisted ? "yes" : "no") }

            if result.isEmpty {
                // The designed empty state. Note the wording: it does not claim a
                // permission problem, because the app cannot know (§0.7).
                VStack(alignment: .leading, spacing: 4) {
                    Text("No data").font(.headline)
                    Text("""
                        Nothing is recorded for this type, or read access was \
                        declined. iOS deliberately does not distinguish the two — \
                        so this is a normal state, not an error.
                        """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(result.days.suffix(10).reversed()) { day in
                    LabeledContent(day.date.formatted(date: .abbreviated, time: .omitted)) {
                        Text(formatted(day.value, for: result.type))
                            .monospacedDigit()
                    }
                }
                if result.days.count > 10 {
                    Text("+ \(result.days.count - 10) more days — see the Xcode console")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(result.type.label)
        }
    }

    private var gotchaSection: some View {
        Section {
            Text("""
                iOS will not tell you whether the user denied READ access. That is \
                an anti-fingerprinting measure: knowing a user hid their heart data \
                is itself information about them.

                A denied read returns an empty result set that is byte-for-byte \
                identical to "this user has no data". `authorizationStatus(for:)` \
                only reports WRITE permission, so it cannot help.

                The design consequence, and the whole reason this spike exists: \
                there is no permission-denied branch to write. Build "no data" as a \
                normal, non-error state from the very beginning.
                """)
            .font(.footnote)
        } header: {
            Text("The gotcha that catches everyone")
        }
    }

    private func formatted(_ value: Double, for type: SpikeType) -> String {
        let digits = type == .bodyMass ? 2 : 0
        return String(format: "%.\(digits)f %@", value, type.unitLabel)
    }
}

#Preview {
    // HealthKit does not meaningfully work in previews or the Simulator — the
    // preview is only here to check layout. §0.1 is blunt about this: "HealthKit
    // does not meaningfully work in the Simulator — you cannot fake your way
    // through this." Run it on your phone.
    SpikeView()
}
