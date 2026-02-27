import SwiftUI

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var showingEditItem = false
    @State private var showingDeleteConfirmation = false
    @State private var shareFile: ShareableFile?

    private struct ShareableFile: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var selectedPhotoIndex = 0
    @State private var selectedReceipt: Receipt?

    private var photos: [Photo] { item.photos ?? [] }
    private var receipts: [Receipt] { item.receipts ?? [] }
    private var category: ItemCategory { item.category ?? .other }
    private var condition: ItemCondition { item.condition ?? .good }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                if !photos.isEmpty {
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 280)
                                    .clipped()
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 280)
                } else {
                    ZStack {
                        Color(.secondarySystemBackground)
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                }

                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Label(category.rawValue, systemImage: category.icon)
                                .badgeStyle(color: .accentColor)
                            Label(condition.rawValue, systemImage: "circle.fill")
                                .badgeStyle(color: condition.color)
                        }
                        if !item.itemDescription.isEmpty {
                            Text(item.itemDescription)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let room = item.room {
                        DetailSection(title: "Location") {
                            DetailRow(label: "Room", value: room.name, icon: room.icon)
                        }
                    }

                    if !item.make.isEmpty || !item.model.isEmpty || !item.serialNumber.isEmpty {
                        DetailSection(title: "Identification") {
                            if !item.make.isEmpty {
                                DetailRow(label: "Make", value: item.make, icon: "tag")
                            }
                            if !item.model.isEmpty {
                                DetailRow(label: "Model", value: item.model, icon: "tag.fill")
                            }
                            if !item.serialNumber.isEmpty {
                                DetailRow(label: "Serial #", value: item.serialNumber, icon: "number")
                            }
                        }
                    }

                    if item.purchasePrice != nil || item.purchaseDate != nil || !item.purchaseStore.isEmpty {
                        DetailSection(title: "Purchase") {
                            if let price = item.purchasePrice {
                                DetailRow(
                                    label: "Price",
                                    value: price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                                    icon: "dollarsign.circle"
                                )
                            }
                            if let date = item.purchaseDate {
                                DetailRow(label: "Date", value: date.formatted(date: .long, time: .omitted), icon: "calendar")
                            }
                            if !item.purchaseStore.isEmpty {
                                DetailRow(label: "Store", value: item.purchaseStore, icon: "storefront")
                            }
                        }
                    }

                    if let value = item.currentValue {
                        DetailSection(title: "Current Value") {
                            DetailRow(
                                label: "Value",
                                value: value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                                icon: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }

                    if item.warrantyExpiration != nil || !item.warrantyProvider.isEmpty {
                        DetailSection(title: "Warranty") {
                            if let expiration = item.warrantyExpiration {
                                let isExpired = expiration < Date()
                                DetailRow(
                                    label: "Expires",
                                    value: expiration.formatted(date: .long, time: .omitted),
                                    icon: isExpired ? "exclamationmark.circle.fill" : "checkmark.shield",
                                    valueColor: isExpired ? .red : .primary
                                )
                            }
                            if !item.warrantyProvider.isEmpty {
                                DetailRow(label: "Provider", value: item.warrantyProvider, icon: "building.2")
                            }
                        }
                    }

                    if !item.notes.isEmpty {
                        DetailSection(title: "Notes") {
                            Text(item.notes)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !receipts.isEmpty {
                        DetailSection(title: "Receipts & Documents") {
                            ForEach(receipts) { receipt in
                                Button { selectedReceipt = receipt } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: receipt.isPDF ? "doc.richtext.fill" : "photo.fill")
                                            .foregroundStyle(receipt.isPDF ? .red : .blue)
                                            .frame(width: 24)
                                        Text(receipt.filename.isEmpty ? "Document" : receipt.filename)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let added = item.dateAdded {
                        Text("Added \(added.formatted(date: .long, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(item.name.isEmpty ? "Item" : item.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditItem = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: duplicateItem) {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(action: shareItemAsPDF) {
                        Label("Share as PDF", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditItem) {
            NavigationStack {
                AddEditItemView(item: item)
            }
        }
        .sheet(item: $selectedReceipt) { receipt in
            DocumentViewerView(receipt: receipt)
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(url: file.url)
        }
        .confirmationDialog("Delete \"\(item.name)\"?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Item", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func shareItemAsPDF() {
        let data = ExportManager.itemPDFData(from: item)
        let filename = "\(item.name.isEmpty ? "Item" : item.name)-Report.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        shareFile = ShareableFile(url: url)
    }

    private func duplicateItem() {
        let copy = Item(
            name: item.name.isEmpty ? "(Copy)" : "\(item.name) (Copy)",
            itemDescription: item.itemDescription,
            category: item.category ?? .other,
            room: item.room,
            make: item.make,
            model: item.model,
            serialNumber: "",
            condition: item.condition ?? .good,
            purchasePrice: item.purchasePrice,
            purchaseDate: item.purchaseDate,
            purchaseStore: item.purchaseStore,
            currentValue: item.currentValue,
            warrantyExpiration: item.warrantyExpiration,
            warrantyProvider: item.warrantyProvider,
            notes: item.notes
        )
        modelContext.insert(copy)
        for photo in item.photos ?? [] {
            guard let data = photo.imageData else { continue }
            let photoCopy = Photo(imageData: data)
            photoCopy.item = copy
            modelContext.insert(photoCopy)
        }
        for receipt in item.receipts ?? [] {
            guard let data = receipt.fileData else { continue }
            let receiptCopy = Receipt(fileData: data, filename: receipt.filename)
            receiptCopy.item = copy
            modelContext.insert(receiptCopy)
        }
    }
}

// MARK: - Supporting Views

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 10) { content }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(label).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Text(value).foregroundStyle(valueColor).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }
}

private struct BadgeStyle: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private extension View {
    func badgeStyle(color: Color) -> some View { modifier(BadgeStyle(color: color)) }
}
