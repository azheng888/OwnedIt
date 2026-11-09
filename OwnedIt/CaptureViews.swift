import SwiftUI
import UIKit
import VisionKit

// MARK: - Camera

/// Takes a single photo with the device camera.
struct CameraPicker: UIViewControllerRepresentable {
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Scanner

/// Scans paper documents (receipts, manuals) with edge detection and returns a multi-page PDF.
struct DocumentScanner: UIViewControllerRepresentable {
    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    let onScan: (_ pdfData: Data, _ pageCount: Int) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            if !images.isEmpty {
                parent.onScan(Self.pdf(from: images), images.count)
            }
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }

        /// Renders pages onto US Letter, JPEG-compressing each so scans stay small for iCloud.
        static func pdf(from images: [UIImage]) -> Data {
            let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
            return UIGraphicsPDFRenderer(bounds: pageRect).pdfData { ctx in
                for image in images {
                    ctx.beginPage()
                    let resized = ImageProcessing.resized(image, maxDimension: 1800)
                    let compressed = resized.jpegData(compressionQuality: 0.7).flatMap(UIImage.init(data:)) ?? resized
                    let scale = min(pageRect.width / compressed.size.width, pageRect.height / compressed.size.height)
                    let size = CGSize(width: compressed.size.width * scale, height: compressed.size.height * scale)
                    let origin = CGPoint(x: (pageRect.width - size.width) / 2, y: (pageRect.height - size.height) / 2)
                    compressed.draw(in: CGRect(origin: origin, size: size))
                }
            }
        }
    }
}
