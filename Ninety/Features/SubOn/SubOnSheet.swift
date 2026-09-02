import SwiftUI

/// Logging, as a sheet.
///
/// A sheet rather than a tab because logging a meal has a beginning and an end
/// and returns you to where you started — Apple's rule is that tabs are
/// sections, not actions. It keeps the app inside §1.6's three-tab cap without
/// spending one of the three on a control.
///
/// P1-F fills this in: manual, search, barcode and photo, plus the Squad and
/// the Bench. The Under Review confirm-and-correct screen is mandatory on the
/// photo route and is not optional polish (ADR 0010).
struct SubOnSheet: View {
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            Screen(title: "Sub On") {
                HoldingNote(
                    eyebrow: "Four routes",
                    headline: "Logging lands with P1‑F.",
                    detail: """
                        Manual, search, barcode and photo. Manual comes first because it \
                        works offline by construction, and it is the route that starts \
                        the 21-day clock.
                        """
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            // Hidden rather than tinted: a filled bar above the masthead reads
            // as two competing headers. Close floats over the pitch instead.
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(Ninety.Colour.accent)
        .presentationDragIndicator(.visible)
    }
}

#Preview("Sub On") {
    SubOnSheet()
}
