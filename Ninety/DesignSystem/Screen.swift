import SwiftUI

/// The frame every screen is built in: pitch, masthead, content.
///
/// Holding the gutter and the masthead in one place is what keeps the spine
/// landing in the same position on all three tabs — the thing that makes a tab
/// change read as turning a page rather than as loading a different app.
struct Screen<Content: View, Accessory: View>: View {
    let title: String
    let meta: String?
    /// Handed straight to `Masthead`. See the note there for why exactly one
    /// control is allowed up here and what it is for.
    let accessory: Accessory
    let content: () -> Content

    init(
        title: String,
        meta: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.meta = meta
        self.accessory = accessory()
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.xl) {
            Masthead(title: title, meta: meta) { accessory }
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Ninety.Space.xl)
        .padding(.top, Ninety.Space.md)
        // Both axes: without maxHeight the pitch stops where the content does
        // and the rest of the tab falls back to the system background.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Pitch())
        .foregroundStyle(Ninety.Colour.textPrimary)
    }
}
