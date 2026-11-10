import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var showingEditItem = false
    @State private var showingDeleteConfirmation = false
    @State private var shareFile: ShareableFile?
    @State private var selectedPhotoIndex = 0
    @State private var photoViewerStart: PhotoViewerStart?
    @State private var selectedReceipt: Receipt?
    @State private var showingAddReminder = false
    @State private var selectedReminder: Reminder?
    @State private var exportError: String?

    private struct PhotoViewerStart: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private var photoImages: [UIImage] {
        item.sortedPhotos.compactMap { $0.imageData.flatMap(UIImage.init(data:)) }
    }
    private var receipts: [Receipt] {
        (item.receipts ?? []).sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
    }
    private var reminders: [Reminder] { (item.reminders ?? []).sorted { $0.nextDueDate < $1.nextDueDate } }
    private var category: ItemCategory { item.category ?? .other }

    private var subtitle: String {
        var parts = [category.rawValue]
        if let room = item.room { parts.append(room.name) }
        if let condition = item.condition { parts.append(condition.rawValue) }
        if item.quantity > 1 { parts.append("×\(item.quantity)") }
        return parts.joined(separator: " · ")
    }

    /// Label/value rows for the Details card. A non-nil color marks a semantic state.
    private var details: [(label: String, value: String, color: Color?)] {
        var rows: [(String, String, Color?)] = []
        if !item.make.isEmpty { rows.append(("Make", item.make, nil)) }
        if !item.model.isEmpty { rows.append(("Model", item.model, nil)) }
        if !item.serialNumber.isEmpty { rows.append(("Serial", item.serialNumber, nil)) }
        if let date = item.purchaseDate {
            let store = item.purchaseStore.isEmpty ? "" : " · \(item.purchaseStore)"
            rows.append(("Purchased", date.formatted(date: .abbreviated, time: .omitted) + store, nil))
        } else if !item.purchaseStore.isEmpty {
            rows.append(("Store", item.purchaseStore, nil))
        }
        if let price = item.purchasePrice, item.quantity > 1 {
            rows.append(("Price each", price.currencyString, nil))
        }
        if let exp = item.warrantyExpiration {
            let soon = exp < (Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date())
            let value = item.isWarrantyExpired ? "Expired \(AppFormat.shortDate(exp))" : "Ends \(AppFormat.shortDate(exp))"
            rows.append(("Warranty", value, item.isWarrantyExpired ? Theme.critical : (soon ? Theme.warning : nil)))
        }
        if !item.warrantyProvider.isEmpty { rows.append(("Coverage", item.warrantyProvider, nil)) }
        return rows
    }

    /// Things an insurer typically asks for that this item is missing.
    private var missingDocumentation: [String] {
        var missing: [String] = []
        if !item.hasPhotos { missing.append("photo") }
        if item.unitValue == nil { missing.append("value") }
        if !item.hasReceipts { missing.append("receipt") }
        if item.serialNumber.isEmpty && [.electronics, .appliances, .tools, .jewelry].contains(category) {
            missing.append("serial number")
        }
        return missing
    }

    var body: some View {
        // The item can be deleted out from under us (e.g. on another device via iCloud).
        if item.isDeleted || item.modelContext == nil {
            ContentUnavailableView("Item Deleted", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        let images = photoImages
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photoHeader(images)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }

                if let total = item.displayValue {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(total, format: AppFormat.currency(for: total))
                            .font(.hero(32))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText(value: total))
                        Text(valueCaption)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                if !item.itemDescription.isEmpty {
                    Text(item.itemDescription)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                }

                if !missingDocumentation.isEmpty {
                    Button { showingEditItem = true } label: {
                        HStack(spacing: 10) {
                            Text("Add a \(ListFormatter.localizedString(byJoining: missingDocumentation)) for insurance.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .card(padding: 14)
                    }
                    .buttonStyle(.pressable)
                }

                if !details.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        CardHeader("Details")
                        VStack(spacing: 0) {
                            ForEach(Array(details.enumerated()), id: \.offset) { index, row in
                                if index > 0 { Divider().overlay(Theme.divider) }
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(row.label).foregroundStyle(Theme.secondaryText)
                                    Spacer(minLength: 12)
                                    Text(row.value)
                                        .foregroundStyle(row.color ?? Theme.ink)
                                        .multilineTextAlignment(.trailing)
                                        .monospacedDigit()
                                        .textSelection(.enabled)
                                }
                                .font(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .card(padding: 0)
                    }
                }

                if !receipts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        CardHeader("Documents")
                        VStack(spacing: 0) {
                            ForEach(Array(receipts.enumerated()), id: \.element.persistentModelID) { index, receipt in
                                if index > 0 { Divider().overlay(Theme.divider) }
                                Button { selectedReceipt = receipt } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: receipt.isPDF ? "doc.text" : "photo")
                                            .foregroundStyle(Theme.secondaryText)
                                            .frame(width: 20)
                                        Text(receipt.displayName)
                                            .foregroundStyle(Theme.ink)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Theme.tertiaryText)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                        .card(padding: 0)
                    }
                }

                if !item.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        CardHeader("Notes")
                        Text(item.notes)
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                            .card(padding: 14)
                    }
                }

                maintenanceSection

                if let added = item.dateAdded {
                    Text("Added \(added.formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .themedScreen()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditItem = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        ItemActions.duplicate(item, in: modelContext)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(action: shareItemAsPDF) {
                        Label("Share as PDF", systemImage: "square.and.arrow.up")
                    }
                    Button(action: { showingAddReminder = true }) {
                        Label("Add Maintenance Reminder", systemImage: "bell")
                    }
                    Divider()
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
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
        .sheet(isPresented: $showingAddReminder) {
            NavigationStack { AddEditReminderView(item: item) }
        }
        .sheet(item: $selectedReminder) { reminder in
            NavigationStack { AddEditReminderView(item: item, reminder: reminder) }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(url: file.url)
        }
        .fullScreenCover(item: $photoViewerStart) { start in
            PhotoViewerView(images: images, selection: start.index)
        }
        .messageAlert("Couldn't Create PDF", message: $exportError)
        .confirmationDialog("Delete \"\(item.displayName)\"?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Item", role: .destructive) {
                dismiss()
                modelContext.delete(item)
            }
        } message: {
            Text("Its photos, documents and reminders will also be deleted. This can't be undone.")
        }
    }

    private var valueCaption: String {
        var parts: [String] = [item.currentValue != nil ? "current value" : "purchase price"]
        if item.currentValue != nil, let paid = item.purchasePrice {
            parts.append("paid \((paid * Double(item.quantity)).currencyString)")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func photoHeader(_ images: [UIImage]) -> some View {
        if !images.isEmpty {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { photoViewerStart = PhotoViewerStart(index: index) }
                        .tag(index)
                        .accessibilityLabel("Photo \(index + 1) of \(images.count)")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: Theme.photoRadius, style: .continuous))
            .padding(.top, 4)
        } else {
            Button { showingEditItem = true } label: {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 26))
                    Text("Add photos")
                        .font(.subheadline)
                }
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.photoRadius, style: .continuous))
            }
            .buttonStyle(.pressable)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var maintenanceSection: some View {
        if !reminders.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(title: "Maintenance") {
                    Button("Add") { showingAddReminder = true }
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
                VStack(spacing: 0) {
                    ForEach(Array(reminders.enumerated()), id: \.element.persistentModelID) { index, reminder in
                        if index > 0 { Divider().overlay(Theme.divider) }
                        HStack(spacing: 10) {
                            Button { selectedReminder = reminder } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.title)
                                        .foregroundStyle(reminder.isActive ? Theme.ink : Theme.secondaryText)
                                    Text(reminder.statusLine)
                                        .font(.footnote)
                                        .foregroundStyle(reminder.isActive && reminder.isDue ? Theme.warning : Theme.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if reminder.isActive {
                                Button { reminder.markDone() } label: {
                                    Image(systemName: "checkmark.circle")
                                        .font(.title3)
                                        .foregroundStyle(Theme.ink)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.pressable)
                                .accessibilityLabel("Mark \(reminder.title) done")
                                .sensoryFeedback(.success, trigger: reminder.lastCompletedDate)
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 4)
                        .padding(.vertical, 4)
                    }
                }
                .card(padding: 0)
            }
        }
    }

    private func shareItemAsPDF() {
        let data = ExportManager.itemPDFData(from: item)
        guard let url = TempFile.write(data, preferredName: "\(item.displayName) Report", ext: "pdf") else {
            exportError = "The report couldn't be saved. Please try again."
            return
        }
        shareFile = ShareableFile(url: url)
    }
}
