import SwiftUI

/// The daily driver.
///
/// P1-A built the frame and left a holding note in it. This is the screen: the
/// band and what is left of it, the pitch, Form, the macro split, the weight
/// trend, the division slot and the day's team sheet — each with the real data
/// behind it, and each with a designed state for having none.
///
/// **Every panel here can be empty, and none of them fills the gap with a
/// number.** `DESIGN.md` § Numbers: a figure the app did not compute is not
/// shown. No band means a sentence about Pre-Season rather than a zero, no
/// readings means the weight panel says so, and a day with nothing logged has a
/// team sheet that says what will fill it. That rule is the difference between
/// this screen and a mock-up of it, and it is the rule this screen is most
/// tempted to break because it has the most holes to fill.
///
/// **Nothing on it waits on, mentions, or branches on the network** — P1-I's
/// constraint on this epic, and the reason `MatchdayModel` has no reference to
/// `SyncService`. A count of unsent rows here would be the plumbing leaking into
/// the screen somebody opens to log breakfast. `Settings → Sync` is the only
/// surface in the app that talks about the network.
///
/// **The masthead control is S6's two-tap requirement.** §10 asks for the
/// competitive opt-out to be reachable in at most two taps from this screen, and
/// §1.6 caps the app at three tabs — so Settings can be neither a fourth tab nor
/// three taps deep. One glyph here, one switch there.
struct MatchdayView: View {
    @State private var model: MatchdayModel

    /// Changes when something happened that this screen has to re-read — today,
    /// only Sub On closing. The dashboard sits *behind* that sheet rather than
    /// being replaced by it, so dismissing it fires no `onAppear` and a meal
    /// just logged would otherwise not reach the band until the tab was left and
    /// come back to. See the note on `MainTabView.matchdayRefresh`.
    var refreshToken: Int

    /// Presents Sub On. Owned by the shell because logging is an action that
    /// returns you here, not a place you navigate to.
    var subOn: () -> Void

    /// Presents Settings, and with it the opt-out, the signposting, consent
    /// withdrawal and signing out.
    var openSettings: () -> Void

    init(
        model: MatchdayModel,
        refreshToken: Int = 0,
        subOn: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.refreshToken = refreshToken
        self.subOn = subOn
        self.openSettings = openSettings
    }

    var body: some View {
        // Both closures labelled, neither trailing. `Screen` takes two now, and
        // trailing-closure syntax with more than one is the case where a reader
        // has to go and look up which parameter the braces landed on.
        Screen(
            title: Destination.matchday.title,
            meta: model.todayLabel,
            accessory: { SettingsButton(action: openSettings) },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: Ninety.Space.xl) {
                        BandHeadline(model: model)
                        FormGuide(form: model.form)
                        WeightPanel(
                            readiness: model.readiness,
                            points: model.sparkline,
                            latestKg: model.latestTrendKg,
                            changeOverFourWeeks: model.changeOverFourWeeks
                        )
                        MacroPanel(macros: model.macros)

                        // §10 S6: the division is the competitive surface, so
                        // the opt-out takes the slot away rather than greying it
                        // out. Everything above and below is untouched.
                        if model.features.showsTierBadges {
                            DivisionSlot(calibration: model.calibration)
                        }

                        TeamSheetPanel(model: model, subOn: subOn)
                    }
                    .padding(.bottom, Ninety.Space.xxl)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        )
        .onAppear(perform: model.refresh)
        .onChange(of: refreshToken) { _, _ in model.refresh() }
    }
}

/// The reading: one figure, its tolerance, and where the day sits.
///
/// **The number is what is left, and it is allowed to be negative.** Going past
/// the band is a normal outcome of a normal day, so a day that has gone over
/// changes the eyebrow and the sign — not the colour. There is no error colour
/// for logged intake in the token set, which is §10 S5 written as an absence
/// rather than as a review note.
private struct BandHeadline: View {
    let model: MatchdayModel

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.md) {
            if let band = model.band, let room = model.roomLeftKcal, let state = model.bandState {
                reading(band: band, room: room, state: state)
                pitch
            } else {
                // No band means Pre-Season has not produced one. A sentence
                // saying what has to happen first, never a zero.
                HoldingNote(
                    eyebrow: MatchdayCopy.stillToPlayWith,
                    headline: MatchdayCopy.noBand,
                    detail: MatchdayCopy.noBandDetail
                )
            }
        }
    }

    @ViewBuilder
    private func reading(band: CalorieBand, room: Int, state: BandState) -> some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xs) {
            Text(room < 0 ? MatchdayCopy.aboveYourBandBy : MatchdayCopy.stillToPlayWith)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: Ninety.Space.sm) {
                Text(Figure.kcal(abs(room)))
                    .ninetyType(.metricXL)
                    .foregroundStyle(Ninety.Colour.textPrimary)

                VStack(alignment: .leading, spacing: Ninety.Space.hair) {
                    // The tolerance, on the figure it belongs to. A range is a
                    // figure and a tolerance, never two numbers joined by a
                    // dash — `DESIGN.md` § Numbers, checked by
                    // `SafetyCopyTests.rangesAreNeverDashed`.
                    Text("±\(Figure.kcal(band.tolerance))")
                        .ninetyType(.metricS)
                        .foregroundStyle(Ninety.Colour.accent)
                    Text(MatchdayCopy.kcalUnit)
                        .ninetyType(.label)
                        .foregroundStyle(Ninety.Colour.textTertiary)
                }
            }

            Text(state.label)
                .ninetyType(.label)
                .foregroundStyle(state.tone.colour)

            Text(MatchdayCopy.inAndBand(logged: model.loggedTodayKcal, band: band))
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)

            // §10's rewrite rule: a state that names a shortfall answers "what
            // now?". Only `.below` has one, and it is the direction §10 cares
            // about — the sentence is on the screen rather than in a colour.
            if let note = state.note {
                Text(note)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.safety)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var pitch: some View {
        if let progress = model.pitchProgress, let span = model.bandSpan {
            VStack(alignment: .leading, spacing: Ninety.Space.xs) {
                PitchMeter(progress: progress, band: span)
                PitchMeterLegend()
            }
        }
    }
}

/// The one control the masthead carries.
///
/// A system glyph rather than an authored chalk one: it has to hold at every
/// size class and at accessibility sizes, which is the same reason the tab bar
/// uses SF Symbols. Its label names what is behind it rather than the icon —
/// "settings" is what a screen reader user is looking for, and §10 requires the
/// support signposting inside to be findable.
struct SettingsButton: View {
    var action: () -> Void

    /// 44pt is Apple's minimum tap target and a glyph does not reach it on its
    /// own.
    @ScaledMetric(relativeTo: .title3)
    private var target: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .ninetyType(.title3)
                .foregroundStyle(Ninety.Colour.textTertiary)
                .frame(minWidth: target, minHeight: target, alignment: .trailing)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings, support and your consent")
    }
}
