import SwiftUI
import PDFKit

struct DocumentViewerView: View {
    let receipt: Receipt

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if receipt.isPDF, let data = receipt.fileData {
                    PDFKitView(data: data)
                } else if let data = receipt.fileData, let uiImage = UIImage(data: data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                } else {
                    ContentUnavailableView("No Content", systemImage: "doc.slash")
                }
            }
            .navigationTitle(receipt.filename.isEmpty ? "Document" : receipt.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                if let data = receipt.fileData {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(
                            item: data,
                            preview: SharePreview(
                                receipt.filename.isEmpty ? "Document" : receipt.filename,
                                image: Image(systemName: receipt.isPDF ? "doc.richtext.fill" : "photo.fill")
                            )
                        )
                    }
                }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        return view
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}
