import SwiftUI

/// Path 2 — scan a barcode.
///
/// **An unknown barcode never dead-ends.** That is the acceptance criterion and
/// it is also the only interesting design question on this route: most of Open
/// Food Facts is European and a barcode genuinely absent from the mirror is the
/// common case rather than a failure. So a miss offers the two things that
/// always work — search by name, or add it as your own food, carrying the
/// barcode forward so the next scan of the same tin resolves locally.
struct BarcodeRouteView: View {
    let model: SubOnModel
    let catalogue: any FoodCatalogueProtocol

    @State private var lookup: Lookup = .scanning

    /// Named `Lookup` rather than `State`: a nested type called `State` inside
    /// a `View` shadows SwiftUI's property wrapper of that name, which turns
    /// `@State private var state: State` into something that does not mean what
    /// it reads as.
    private enum Lookup: Equatable {
        case scanning
        /// A payload is being resolved. Held so the scanner does not fire the
        /// same barcode twenty times while the lookup is in flight.
        case looking(String)
        case notFound(String)
    }

    var body: some View {
        Screen(title: SubOnCopy.barcodeRoute, meta: model.slot.title) {
            VStack(alignment: .leading, spacing: Ninety.Space.lg) {
                if BarcodeScanner.isUsable {
                    scanner
                } else {
                    unavailable
                }
                status
            }
        }
    }

    private var scanner: some View {
        VStack(alignment: .leading, spacing: Ninety.Space.sm) {
            Text(SubOnCopy.barcodePrompt)
                .ninetyType(.subhead)
                .foregroundStyle(Ninety.Colour.textSecondary)

            BarcodeScanner { payload in
                resolve(payload)
            }
            // A fixed aspect rather than filling the screen: the scanner is a
            // viewfinder inside a screen that still has to say what it is and
            // what to do when it misses.
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .ninetyCorners(Ninety.Radius.md)
            .overlay {
                RoundedRectangle(cornerRadius: Ninety.Radius.md, style: .continuous)
                    .strokeBorder(Ninety.Colour.strokeStrong, lineWidth: Chalk.strong)
            }
            .accessibilityLabel(SubOnCopy.barcodePrompt)
        }
    }

    private var unavailable: some View {
        HoldingNote(
            eyebrow: SubOnCopy.barcodeRoute,
            headline: SubOnCopy.barcodeUnavailable,
            detail: SubOnCopy.barcodeNoCamera
        )
    }

    @ViewBuilder private var status: some View {
        switch lookup {
        case .scanning:
            EmptyView()
        case .looking:
            Text(SubOnCopy.searchingNote)
                .ninetyType(.footnote)
                .foregroundStyle(Ninety.Colour.textTertiary)
        case .notFound(let payload):
            VStack(alignment: .leading, spacing: Ninety.Space.md) {
                Text(SubOnCopy.barcodeNotFound)
                    .ninetyType(.title3)
                    .foregroundStyle(Ninety.Colour.textPrimary)
                Text(SubOnCopy.catalogueNote)
                    .ninetyType(.footnote)
                    .foregroundStyle(Ninety.Colour.textTertiary)

                Button(SubOnCopy.barcodeSaveAsCustom) {
                    // The barcode travels with the draft. Saving it as a custom
                    // food is what makes the *second* scan of the same tin a
                    // local hit, which is the whole reason this offer exists
                    // rather than only "search by name".
                    model.portion = PortionPrefill(
                        food: FoodDraft(source: .custom, barcode: payload, name: "", kcalPer100g: 0),
                        // The scan found nothing; the user is about to type all
                        // of it. That is a manual entry that happens to know a
                        // barcode, and the entry method says so.
                        entryMethod: .manual
                    )
                }
                .buttonStyle(.primary)

                // Swaps the route rather than pushing a second copy of the
                // search screen underneath this one. The user asked for search,
                // not for search with a scanner behind it.
                Button(SubOnCopy.barcodeSearchInstead) { model.route = .search }
                    .ninetyType(.callout)
                    .foregroundStyle(Ninety.Colour.accent)
                    .frame(minHeight: 44)
            }
            .chalkPanel(padding: Ninety.Space.lg)
        }
    }

    /// Local first, then the mirror.
    ///
    /// A scan in a supermarket aisle is the case with the worst signal and the
    /// least patience, so a barcode the phone has already seen resolves without
    /// touching the network at all.
    private func resolve(_ payload: String) {
        // The scanner reports the same barcode on every frame it stays in view.
        // Anything already in flight or already answered is ignored here rather
        // than filtered inside the wrapper, which does not know what "the same
        // scan" means.
        guard lookup == .scanning else { return }
        lookup = .looking(payload)

        if let local = model.foods.food(withBarcode: payload) {
            log(
                FoodDraft(
                    id: local.id,
                    source: local.source,
                    barcode: local.barcode,
                    name: local.name,
                    brand: local.brand,
                    kcalPer100g: local.kcalPer100g,
                    proteinG: local.proteinG,
                    carbsG: local.carbsG,
                    fatG: local.fatG
                )
            )
            return
        }

        Task {
            let found = try? await catalogue.food(barcode: payload)
            guard case .looking(payload) = lookup else { return }
            if let found {
                model.cache(found)
                log(found.draft)
            } else {
                lookup = .notFound(payload)
            }
        }
    }

    /// A resolved barcode goes to the portion screen rather than logging itself.
    ///
    /// The catalogue knows kcal per 100 g and nothing about how much of it you
    /// ate, and a scanner that logged a whole packet on sight would be inventing
    /// the number that matters most.
    private func log(_ draft: FoodDraft) {
        model.portion = PortionPrefill(food: draft, entryMethod: .barcode)
        lookup = .scanning
    }
}
