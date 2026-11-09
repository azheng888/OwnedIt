import SwiftUI
import VisionKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Start once the controller is in the hierarchy; starting in make can silently fail.
        if !uiViewController.isScanning && !context.coordinator.hasScanned {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private(set) var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            if case .barcode(let barcode) = addedItems.first,
               let value = barcode.payloadStringValue {
                hasScanned = true
                dataScanner.stopScanning()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onScan(value)
            }
        }
    }
}

// Wrapper that adds a Cancel button and unavailability fallback
struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    BarcodeScannerView(onScan: onScan)
                        .ignoresSafeArea()
                } else if DataScannerViewController.isSupported {
                    ContentUnavailableView(
                        "Camera Access Needed",
                        systemImage: "camera.fill",
                        description: Text("Allow camera access for OwnedIt in Settings to scan barcodes.")
                    )
                } else {
                    ContentUnavailableView(
                        "Scanner Unavailable",
                        systemImage: "barcode.viewfinder",
                        description: Text("Barcode scanning requires a device with a camera.")
                    )
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Product lookup

struct ProductInfo {
    var title: String?
    var brand: String?
    var model: String?
    var description: String?
    var imageURLs: [URL] = []
}

enum ProductLookupError: LocalizedError {
    case notFound(String)
    case rateLimited
    case network

    var errorDescription: String? {
        switch self {
        case .notFound(let code):
            return "No product found for barcode \(code). You can still enter details manually."
        case .rateLimited:
            return "The product database's free daily lookup limit was reached. Try again later or enter details manually."
        case .network:
            return "Couldn't reach the product database. Check your connection."
        }
    }
}

enum ProductLookup {
    static func lookUp(_ barcode: String) async throws -> ProductInfo {
        var components = URLComponents(string: "https://api.upcitemdb.com/prod/trial/lookup")!
        components.queryItems = [URLQueryItem(name: "upc", value: barcode)]
        guard let url = components.url else { throw ProductLookupError.notFound(barcode) }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProductLookupError.network
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw ProductLookupError.rateLimited }
            if http.statusCode == 404 || http.statusCode == 400 { throw ProductLookupError.notFound(barcode) }
            guard (200..<300).contains(http.statusCode) else { throw ProductLookupError.network }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["items"] as? [[String: Any]])?.first else {
            throw ProductLookupError.notFound(barcode)
        }

        func string(_ key: String) -> String? {
            (first[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }

        let images = (first["images"] as? [String] ?? [])
            .compactMap { raw -> URL? in
                // App Transport Security requires HTTPS.
                let https = raw.hasPrefix("http://") ? "https://" + raw.dropFirst(7) : raw
                return URL(string: https)
            }

        return ProductInfo(title: string("title"), brand: string("brand"), model: string("model"),
                           description: string("description"), imageURLs: images)
    }

    /// Best-effort download of the first usable product image.
    static func fetchImage(from urls: [URL]) async -> Data? {
        for url in urls.prefix(3) {
            guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10)),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                  let prepared = ImageProcessing.preparedPhotoData(from: data) else { continue }
            return prepared
        }
        return nil
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
