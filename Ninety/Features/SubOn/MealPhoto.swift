import SwiftUI
import UIKit

/// Getting a photograph down to something worth uploading.
///
/// §1.3: downscale to about 1,024 px on the longest edge before upload — it
/// *"materially cuts cost and latency, accuracy barely moves"*. Phase 0 turned
/// that from an assumption into a measurable one (ADR 0010 records that Opus 5
/// accepts up to 2,576 px, so 1,024 is a choice rather than a limit), and the
/// harness takes `--max-edge` so the claim can be checked against real meals.
/// Until it is, 1,024 is what the brief says and what this does.
///
/// The number is here rather than in the Edge Function on purpose: the bytes
/// that cost the user time are the ones going *up*, over the connection that is
/// usually the problem, so the shrink has to happen before the upload rather
/// than after it.
enum MealPhoto {
    static let maxEdge: CGFloat = 1_024

    /// 0.8. Above this the file grows faster than anything visible in it; below
    /// it, JPEG artefacts start to look like texture on food, which is the one
    /// thing this image is being read for.
    static let jpegQuality: CGFloat = 0.8

    /// The size an image becomes, preserving aspect ratio.
    ///
    /// **Never upscales.** A 600 px photo scaled up to 1,024 is more bytes
    /// carrying no more information — the model sees the same picture and the
    /// upload takes twice as long.
    ///
    /// Pure and separate from the rendering so the arithmetic can be tested
    /// without a `UIImage`, a screen or a run loop.
    static func fittedSize(for size: CGSize, maxEdge: CGFloat = maxEdge) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxEdge, longest > 0 else { return size }
        let scale = maxEdge / longest
        return CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )
    }

    /// Downscale and encode.
    ///
    /// `UIGraphicsImageRenderer` with an explicit scale of 1 — the default is the
    /// screen's, which on a 3× phone would quietly produce a 3,072 px image from
    /// a 1,024 pt request and undo the whole point of this function.
    static func jpeg(from image: UIImage, maxEdge: CGFloat = maxEdge) -> Data? {
        let target = fittedSize(for: image.size, maxEdge: maxEdge)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: jpegQuality)
    }
}

/// The camera, as a sheet.
///
/// `UIImagePickerController` rather than a custom `AVCaptureSession`: the app
/// needs one still image and nothing else, and the system camera brings the
/// shutter, the flash control, the review step and every accessibility
/// affordance Apple has added to it. The same reasoning as `BarcodeScanner`
/// declining to hand-roll AVFoundation.
struct MealCamera: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // `.originalImage`, not `.editedImage`: editing is off, and asking
            // for a key that was never produced returns nil and looks like a
            // camera that silently does nothing.
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
