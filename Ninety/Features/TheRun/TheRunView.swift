import SwiftUI

/// Weight and trend against the pace chosen at onboarding.
///
/// P1-A builds the frame only. The 7-day EWMA, the four-week baseline and the
/// pace corridor are P1‑G. The raw daily line stays behind a toggle and off by
/// default whenever it does arrive — a jagged daily weight makes a good week
/// look like a bad one, which §1.5 names as a main reason people abandon
/// weight-loss apps in the first fortnight.
struct TheRunView: View {
    var body: some View {
        Screen(title: Destination.theRun.title, meta: "No readings") {
            HoldingNote(
                eyebrow: "Weight",
                headline: "No weight yet.",
                detail: """
                    The 7-day average and the pace you signed up for land with P1‑G. \
                    A trend needs a week of readings before it is a trend, so there is \
                    nothing to draw here until there is.
                    """
            )
        }
    }
}

#Preview("The Run") {
    TheRunView()
}

#Preview("The Run · accessibility 5") {
    TheRunView().dynamicTypeSize(.accessibility5)
}
