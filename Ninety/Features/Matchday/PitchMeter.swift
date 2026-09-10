import SwiftUI

/// The day's intake, drawn as a pitch.
///
/// `Main.dc.html`'s central device: the halfway line and the centre circle mark
/// the pitch out, the box at the far end is the band you are aiming into, and
/// possession is how far today's total has got up it. It is a progress bar with
/// a target zone, dressed as the world the app is built in — and the dressing is
/// what makes a bar somebody would otherwise ignore into the thing they read
/// first.
///
/// **The pitch runs past the band, not up to it.** It ends a whole band's width
/// beyond the top of the box, so a day that has gone over has somewhere to be
/// rather than a bar pinned at full — a meter that saturates says the same thing
/// about 2,000 kcal and 4,000, and the second is the one worth noticing.
///
/// **No error colour, and there is none to reach for.** Going past the band is a
/// normal outcome of a normal day (§10 S5, `BandState.above` is `.neutral`), so
/// the marker is drawn in the same chalk wherever it lands. The box keeps the
/// gold because the band is the target, not the verdict.
struct PitchMeter: View {
    /// How far up, `0...1`.
    let progress: Double
    /// Where the band's box sits, as a `0...1` span of the same pitch.
    let band: ClosedRange<Double>

    /// Grows with the type. A fixed 46pt box at `.accessibility5` is a strip of
    /// chalk with the labels underneath it falling off the screen.
    @ScaledMetric(relativeTo: .body)
    private var height: CGFloat = 52

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                markings
                box(width: width)
                possession(width: width)
            }
        }
        .frame(height: height)
        .overlay {
            Rectangle().strokeBorder(Ninety.Colour.strokeStrong, lineWidth: Chalk.strong)
        }
        // One element, described in words. Seven chalk lines and a circle are
        // decoration to a screen reader; the figure above the meter is the
        // number, and this says where it sits.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }

    /// The halfway line and the centre circle. Chalk at the faint weight — they
    /// are the pitch, not the data.
    private var markings: some View {
        ZStack {
            Rectangle()
                .fill(Ninety.Colour.stroke)
                .frame(width: Chalk.strong)
            Circle()
                .strokeBorder(Ninety.Colour.stroke, lineWidth: Chalk.strong)
                .frame(width: height * 0.62, height: height * 0.62)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The band, as the box you are aiming into. Gold, because the band is the
    /// division's business and gold is the division's colour.
    private func box(width: CGFloat) -> some View {
        Rectangle()
            .fill(Ninety.Colour.accent.opacity(0.16))
            .overlay {
                Rectangle().strokeBorder(Ninety.Colour.accent, lineWidth: Chalk.strong)
            }
            .frame(width: max(width * (band.upperBound - band.lowerBound), 1))
            .offset(x: width * band.lowerBound)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How far the day has got, and the ball at the end of it.
    private func possession(width: CGFloat) -> some View {
        let x = width * min(max(progress, 0), 1)
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Ninety.Colour.textPrimary.opacity(0.14))
                .frame(width: max(x, 0))
            Rectangle()
                .fill(Ninety.Colour.textPrimary)
                .frame(width: Chalk.strong)
                .offset(x: max(x - Chalk.strong / 2, 0))
            Circle()
                .fill(Ninety.Colour.textPrimary)
                .frame(width: height * 0.25, height: height * 0.25)
                .offset(x: max(x - height * 0.125, 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The two ends of the pitch, named. `Main.dc.html` puts three labels under it —
/// KICK OFF, the halfway figure, THE BAND — and the middle one is dropped here
/// because the figure it repeats is already the largest thing on the screen.
struct PitchMeterLegend: View {
    var body: some View {
        HStack {
            Text(MatchdayCopy.kickOff)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.textTertiary)
            Spacer(minLength: Ninety.Space.sm)
            Text(MatchdayCopy.theBand)
                .ninetyType(.label)
                .foregroundStyle(Ninety.Colour.accent)
        }
        .accessibilityHidden(true)
    }
}
