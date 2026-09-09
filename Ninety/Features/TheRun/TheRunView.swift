import SwiftUI

/// Weight and trend against the pace chosen at onboarding.
///
/// **The headline is the 7-day average and it is not negotiable.** §1.5 is the
/// strongest wording in the brief about a display choice: raw daily weight is
/// mostly water, glycogen and gut content, and showing it as the number makes a
/// genuinely successful week look like failure. The raw series is available
/// behind a toggle, off every time the screen appears, because a user's own
/// measurements are theirs to look at — but it is never the primary series and
/// never the figure at the top.
///
/// Four states, each rendered deliberately rather than as a sparse-data edge
/// case. The one-point state came out of Spike A on a real device: bodyweight
/// read 120.00 kg from a single same-day entry, so the trend had exactly one
/// point and nothing at all was wrong.
struct TheRunView: View {
    @State private var model: TheRunModel
    @State private var isWeighingIn = false

    init(model: TheRunModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Screen(title: Destination.theRun.title, meta: meta) {
            ScrollView {
                VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                    switch model.readiness {
                    case .noReadings:
                        HoldingNote(
                            eyebrow: TheRunCopy.eyebrow,
                            headline: TheRunCopy.noWeightHeadline,
                            detail: TheRunCopy.noWeightDetail
                        )
                    case .oneReading:
                        headline
                        HoldingNote(
                            eyebrow: TheRunCopy.eyebrow,
                            headline: TheRunCopy.oneReadingHeadline,
                            detail: TheRunCopy.oneReadingDetail
                        )
                    case .building(let days):
                        headline
                        buildingNote(days: days)
                        chart
                        paceSection
                    case .ready:
                        headline
                        chart
                        paceSection
                    }

                    explainer
                    weighInButton
                    healthSection
                    readingsSection
                }
                .padding(.bottom, Ninety.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .sheet(isPresented: $isWeighingIn, onDismiss: model.refresh) {
            WeightEntryView(model: model)
        }
        .onAppear(perform: model.refresh)
    }

    /// The masthead's meta line: when the run started. "No readings" until it
    /// has, which is the same wording the holding note is built around.
    private var meta: String {
        guard let started = model.startedOn else { return "No readings" }
        return "\(TheRunCopy.sinceLabel) \(started.formatted(.dateTime.day().month(.abbreviated)))"
    }

    // MARK: - The number

    @ViewBuilder private var headline: some View {
        if let kg = model.latestTrendKg {
            VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                Text(TheRunCopy.averageLabel)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)

                Text(TheRunCopy.kilograms(kg))
                    .ninetyType(.metricXL)
                    .foregroundStyle(Ninety.Colour.textPrimary)

                // The comparison slot, which `design/spec/02-components.md` §4
                // makes mandatory: if a stat has nothing to compare against yet,
                // the slot says so rather than disappearing.
                comparison
            }
            .chalkPanel(padding: Ninety.Space.lg)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var comparison: some View {
        if let change = model.changeOverFourWeeks {
            // Flat is a legitimate outcome and gets its own words rather than
            // "0.0 kg", which reads as a failure to move.
            Text(isFlat(change) ? TheRunCopy.flatOverFourWeeks : TheRunCopy.versusFourWeeks(change))
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.textSecondary)

            if change > 0 {
                Text(TheRunCopy.shortWindow)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        } else {
            Text(TheRunCopy.trendNeedsAWeek)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
    }

    /// Under a tenth of a kilogram over four weeks is steady. The trend is
    /// reported to one decimal place, so anything smaller is a difference the
    /// screen does not show and must not describe.
    private func isFlat(_ change: Double) -> Bool { abs(change) < 0.05 }

    // MARK: - The chart

    private var chart: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            SectionHeading(title: model.range.title)
            rangePicker

            WeightChart(
                points: model.visiblePoints,
                pace: model.visiblePace,
                showsRawReadings: model.showsRawReadings
            )

            WeightChartLegend(
                showsPace: !model.visiblePace.isEmpty,
                showsRawReadings: model.showsRawReadings
            )

            Toggle(TheRunCopy.showRawReadings, isOn: $model.showsRawReadings)
                .ninetyType(.callout)
                .tint(Ninety.Colour.accent)

            if model.showsRawReadings {
                Text(TheRunCopy.rawReadingsNote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    private var rangePicker: some View {
        Picker(TheRunCopy.rangeLabel, selection: $model.range) {
            ForEach(TrendRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(TheRunCopy.rangeLabel)
    }

    private func buildingNote(days: Int) -> some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xs) {
            Text(TheRunCopy.building(days: days))
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.textPrimary)
            Text(TheRunCopy.buildingDetail)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        }
        .chalkPanel(padding: Ninety.Space.lg)
        .accessibilityElement(children: .combine)
    }

    // MARK: - The pace

    @ViewBuilder private var paceSection: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            SectionHeading(
                title: TheRunCopy.paceLabel,
                detail: model.pace.map { TheRunCopy.rate(abs($0.ratePerWeekKg)) }
            )

            if let standing = model.standing, let goal = model.profile?.goalType {
                VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                    // `textPrimary`, not `positive`, on every one of the three.
                    // §10 S3: the engine caps rate of loss, so a screen that
                    // paints "ahead" green is an incentive pulling against the
                    // cap — and there is no punitive colour for "behind"
                    // either, which is S5.
                    Text(TheRunCopy.pace(standing, goalType: goal))
                        .ninetyType(.callout)
                        .foregroundStyle(Ninety.Colour.textPrimary)
                    Text(TheRunCopy.paceNote(standing, goalType: goal))
                        .ninetyType(.footnote)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                }
                .chalkPanel(padding: Ninety.Space.lg)
                .accessibilityElement(children: .combine)
            } else {
                HoldingNote(
                    eyebrow: TheRunCopy.paceLabel,
                    headline: TheRunCopy.noPace,
                    detail: TheRunCopy.noPaceDetail
                )
            }
        }
    }

    // MARK: - Everything else

    private var explainer: some View {
        Text(TheRunCopy.explainer)
            .ninetyType(.footnote)
            .foregroundStyle(Ninety.Colour.textTertiary)
    }

    private var weighInButton: some View {
        Button(TheRunCopy.addWeight) { isWeighingIn = true }
            .buttonStyle(.primary)
    }

    @ViewBuilder private var healthSection: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            SectionHeading(title: TheRunCopy.healthHeading)

            if model.offersHealth {
                Text(TheRunCopy.healthDetail)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)

                Button(TheRunCopy.connectHealth) {
                    Task { await model.readFromHealth() }
                }
                .buttonStyle(.plain)
                .ninetyType(.callout)
                .foregroundStyle(Ninety.Colour.accent)
                .frame(minHeight: 44, alignment: .leading)
                .disabled(model.isReadingHealth)

                if let count = model.lastImportCount {
                    // Both outcomes stated plainly. An empty read is what iOS
                    // returns for "nothing there" and for "not allowed" alike,
                    // so neither sentence claims to know which.
                    Text(count == 0 ? TheRunCopy.importedNothing : TheRunCopy.imported(count))
                        .ninetyType(.footnote)
                        .foregroundStyle(Ninety.Colour.textSecondary)
                }
            } else {
                Text(TheRunCopy.healthUnavailable)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
        }
    }

    @ViewBuilder private var readingsSection: some View {
        if !model.readings.isEmpty {
            VStack(alignment: .leading, spacing: Ninety.Space.sm) {
                SectionHeading(title: TheRunCopy.readingsHeading, detail: TheRunCopy.readingsDetail)

                // Newest first here, oldest first in the series. The list is
                // read backwards from now; the EWMA is walked forwards.
                ForEach(model.readings.reversed(), id: \.id) { reading in
                    ReadingRow(reading: reading) { model.delete(reading) }
                }
            }
        }
    }
}

/// One weigh-in on the list, and the way to take it back.
///
/// **Removal has no 48-hour window on it**, unlike a food log. §2.3's lock
/// exists because an editable food log is a way to rewrite a scored week; a
/// mistyped weight is a measurement that never happened, and it drags every
/// trend value after it for as long as it is stored. There is no version of the
/// EWMA that shrugs off `7.84`.
struct ReadingRow: View {
    let reading: WeightLog
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.md) {
            VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                Text(TheRunCopy.kilograms(reading.kg))
                    .ninetyType(.callout)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Text(detail)
                    .ninetyType(.label)
                    .foregroundStyle(Ninety.Colour.textTertiary)
            }
            Spacer(minLength: Ninety.Space.sm)
        }
        .padding(.vertical, Ninety.Space.sm)
        .chalkRule(Chalk.faint)
        .accessibilityElement(children: .combine)
        // A swipe needs a `List`, which this is not — the screen is a
        // `ScrollView` so the chart and the panels can size themselves. The
        // context menu is the affordance that works in one, and the same action
        // is on the accessibility rotor for anyone who cannot swipe anyway.
        .contextMenu {
            Button(TheRunCopy.removeReading, role: .destructive, action: remove)
        }
        .accessibilityAction(named: TheRunCopy.removeReading, remove)
    }

    /// `2 Sep, 08:14 · Apple Health`. Where it came from is on the row because
    /// the two sources behave differently when something looks wrong — a typed
    /// number is the user's to fix here, and a scale's is the scale's.
    private var detail: String {
        let stamp = reading.measuredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        return "\(stamp) · \(TheRunCopy.source(reading.source))"
    }
}

#if DEBUG
#Preview("The Run") {
    TheRunView(model: .preview())
}

#Preview("The Run · light") {
    TheRunView(model: .preview()).preferredColorScheme(.light)
}

#Preview("The Run · one reading") {
    TheRunView(model: .preview(readingDays: 1))
}

#Preview("The Run · no readings") {
    TheRunView(model: .preview(readingDays: 0, health: nil))
}

#Preview("The Run · building") {
    TheRunView(model: .preview(readingDays: 4))
}

#Preview("The Run · accessibility 5") {
    TheRunView(model: .preview()).dynamicTypeSize(.accessibility5)
}
#endif
