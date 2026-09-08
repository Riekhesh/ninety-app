import SwiftUI
import VisionKit

/// `DataScannerViewController`, wrapped.
///
/// **About twenty lines, and that is the point.** §1.3: *"the fastest logging
/// path that exists for packaged food and it is close to free to implement —
/// prioritise it."* VisionKit owns the camera session, the preview layer, the
/// region of interest, the highlighting and the recognition; hand-rolling the
/// same thing over AVFoundation is a week of work and a worse scanner.
///
/// Two things it deliberately does not do. It does not ask for camera
/// permission itself — `isAvailable` and `isSupported` already answer "can this
/// phone scan", and the caller has an honest screen for when they say no. And it
/// does not debounce: the same barcode held in frame produces the same payload
/// repeatedly, so the *caller* stops after the first hit rather than this
/// filtering a stream it does not understand.
struct BarcodeScanner: UIViewControllerRepresentable {
    /// Called with the payload string, possibly many times for one barcode.
    var onScan: (String) -> Void

    /// Both halves are needed and they answer different questions. `isSupported`
    /// is about the hardware — a device without a Neural Engine cannot do this
    /// at all — and `isAvailable` is about right now, which includes the user
    /// having declined the camera.
    static var isUsable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            // Barcodes only, and only the symbologies packaged food actually
            // carries. Adding text recognition here would make every price
            // label in the aisle a candidate.
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        // `try?` rather than a thrown error: every failure this can produce is
        // one `isUsable` already answered, and the caller is showing the
        // unavailable screen in that case.
        if !controller.isScanning { try? controller.startScanning() }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for case .barcode(let barcode) in addedItems {
                guard let payload = barcode.payloadStringValue else { continue }
                onScan(payload)
            }
        }
    }
}
