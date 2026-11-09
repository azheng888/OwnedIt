import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// All editable state for the item form, kept in one value so we can detect unsaved changes.
private struct ItemForm: Equatable {
    var name = ""
    var itemDescription = ""
    var quantity = 1
    var category: ItemCategory = .other
    var condition: ItemCondition?
    var room: Room?
    var make = ""
    var model = ""
    var serialNumber = ""
    var hasPurchasePrice = false
    var purchasePrice = 0.0
    var hasPurchaseDate = false
    var purchaseDate = Date()
    var purchaseStore = ""
    var hasCurrentValue = false
    var currentValue = 0.0
    var hasWarranty = false
    var warrantyExpiration = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var warrantyProvider = ""
    var notes = ""
    var photos: [EditablePhoto] = []
    var documents: [EditableDocument] = []

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}

private struct EditablePhoto: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let preview: UIImage?
    /// The stored photo this came from, if any — lets save() keep it instead of re-creating it.
    let existing: Photo?

    init(data: Data, existing: Photo? = nil) {
        self.data = data
        self.existing = existing
        let previewData = existing?.thumbnailData ?? ImageProcessing.thumbnailData(from: data) ?? data
        self.preview = UIImage(data: previewData)
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

private struct EditableDocument: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let filename: String
    let existing: Receipt?

    var isPDF: Bool { Receipt.isPDF(data) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

struct AddEditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query private var allItems: [Item]

    var item: Item? = nil
    var preselectedRoom: Room? = nil

    @State private var form = ItemForm()
    @State private var initialForm = ItemForm()
    @State private var didLoad = false

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var showingCamera = false
    @State private var showingDocumentPicker = false
    @State private var showingDocumentScanner = false
    @State private var showingBarcodeScanner = false
    @State private var isLookingUpBarcode = false
    @State private var showingDuplicateAlert = false
    @State private var showingDiscardConfirmation = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?
    private enum Field { case name, purchasePrice, currentValue }

    private static let maxPhotos = 10

    private var isEditing: Bool { item != nil }
    private var hasChanges: Bool { form != initialForm }
    private var canAddPhotos: Bool { form.photos.count < Self.maxPhotos }

    var body: some View {
        Form {
            photosSection
            basicInfoSection
            locationSection
            identificationSection
            purchaseSection
            valueSection
            warrantySection
            notesSection
            documentsSection
        }
        .themedList()
        .navigationTitle(isEditing ? "Edit Item" : "New Item")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(hasChanges)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges { showingDiscardConfirmation = true } else { dismiss() }
                }
                .confirmationDialog("Discard changes?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
                    Button("Discard Changes", role: .destructive) { dismiss() }
                    Button("Keep Editing", role: .cancel) {}
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { attemptSave() }
                    .fontWeight(.semibold)
                    .disabled(form.trimmedName.isEmpty || isProcessingPhotos)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                    dismissKeyboard()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear(perform: loadIfNeeded)
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            importPickedPhotos(newItems)
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerSheet { barcode in
                showingBarcodeScanner = false
                lookUpBarcode(barcode)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in addPhoto(image) }
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingDocumentScanner) {
            DocumentScanner { pdf, pages in
                let stamp = Date().formatted(.dateTime.year().month().day())
                let base = form.trimmedName.isEmpty ? "Scan" : "\(form.trimmedName) Receipt"
                form.documents.append(EditableDocument(data: pdf, filename: "\(base) \(stamp).pdf", existing: nil))
                _ = pages
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            handleDocumentImport(result)
        }
        .overlay {
            if isLookingUpBarcode {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Looking up product…")
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .messageAlert("Something Went Wrong", message: $errorMessage)
        .alert("Duplicate Item", isPresented: $showingDuplicateAlert) {
            Button("Save Anyway") { save() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("An item named \"\(form.trimmedName)\" already exists. Tip: use Quantity for multiples of the same thing.")
        }
    }

    // MARK: - Sections

    private var photosSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if canAddPhotos {
                        Menu {
                            if CameraPicker.isAvailable {
                                Button { showingCamera = true } label: {
                                    Label("Take Photo", systemImage: "camera")
                                }
                            }
                            // PhotosPicker can't live inside a Menu reliably, so the library
                            // option is a separate tile below.
                        } label: {
                            photoTile(icon: "camera.fill", title: "Camera")
                        } primaryAction: {
                            if CameraPicker.isAvailable { showingCamera = true }
                        }
                        .disabled(!CameraPicker.isAvailable)

                        PhotosPicker(selection: $selectedPhotos,
                                     maxSelectionCount: Self.maxPhotos - form.photos.count,
                                     matching: .images) {
                            photoTile(icon: "photo.on.rectangle", title: "Library")
                        }
                    }

                    if isProcessingPhotos {
                        ProgressView()
                            .frame(width: 80, height: 80)
                    }

                    ForEach(form.photos) { photo in
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let preview = photo.preview {
                                    Image(uiImage: preview).resizable().scaledToFill()
                                } else {
                                    Color(.tertiarySystemBackground)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .bottomLeading) {
                                if photo.id == form.photos.first?.id && form.photos.count > 1 {
                                    Text("Cover")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(.black.opacity(0.55), in: Capsule())
                                        .foregroundStyle(.white)
                                        .padding(4)
                                }
                            }

                            Button {
                                withAnimation { form.photos.removeAll { $0.id == photo.id } }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.black.opacity(0.6))
                                    .font(.system(size: 20))
                            }
                            .padding(3)
                            .accessibilityLabel("Remove photo")
                        }
                        .contextMenu {
                            if photo.id != form.photos.first?.id {
                                Button {
                                    movePhoto(photo.id, toIndex: 0)
                                } label: {
                                    Label("Make Cover Photo", systemImage: "star")
                                }
                            }
                            Button(role: .destructive) {
                                form.photos.removeAll { $0.id == photo.id }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .draggable(photo.id.uuidString)
                        .dropDestination(for: String.self) { ids, _ in
                            guard let source = ids.first.flatMap(UUID.init(uuidString:)),
                                  let target = form.photos.firstIndex(where: { $0.id == photo.id }) else { return false }
                            movePhoto(source, toIndex: target)
                            return true
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Photos")
        } footer: {
            if form.photos.count > 1 {
                Text("Drag to reorder. The first photo is used as the cover.")
            }
        }
    }

    private func photoTile(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
            Text(title)
                .font(.caption)
        }
        .foregroundStyle(Theme.secondaryText)
        .frame(width: 80, height: 80)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var basicInfoSection: some View {
        Section("Basic Info") {
            HStack {
                TextField("Name", text: $form.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.done)
                Button {
                    showingBarcodeScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Scan barcode")
            }

            TextField("Description", text: $form.itemDescription, axis: .vertical)
                .lineLimit(1...4)

            Stepper("Quantity: \(form.quantity)", value: $form.quantity, in: 1...999)

            Picker("Category", selection: $form.category) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }

            Picker("Condition", selection: $form.condition) {
                Text("Not Set").tag(ItemCondition?.none)
                ForEach(ItemCondition.allCases, id: \.self) { cond in
                    Text(cond.rawValue).tag(ItemCondition?.some(cond))
                }
            }
        }
    }

    private var locationSection: some View {
        Section("Location") {
            Picker("Room", selection: $form.room) {
                Text("None").tag(Room?.none)
                ForEach(rooms) { room in
                    Label(room.name, systemImage: room.icon).tag(Room?.some(room))
                }
            }
        }
    }

    private var identificationSection: some View {
        Section("Identification") {
            TextField("Make (e.g. Apple, IKEA)", text: $form.make)
            TextField("Model", text: $form.model)
            TextField("Serial Number", text: $form.serialNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .fontDesign(.monospaced)
        }
    }

    private var purchaseSection: some View {
        Section("Purchase") {
            Toggle(form.quantity > 1 ? "Purchase Price (per unit)" : "Purchase Price",
                   isOn: $form.hasPurchasePrice.animation())
            if form.hasPurchasePrice {
                currencyField(value: $form.purchasePrice, field: .purchasePrice)
                if form.quantity > 1 {
                    totalRow(form.purchasePrice)
                }
            }

            Toggle("Purchase Date", isOn: $form.hasPurchaseDate.animation())
            if form.hasPurchaseDate {
                DatePicker("Date", selection: $form.purchaseDate, in: ...Date(), displayedComponents: .date)
            }

            TextField("Store / Retailer", text: $form.purchaseStore)
        }
    }

    private var valueSection: some View {
        Section {
            Toggle(form.quantity > 1 ? "Track Current Value (per unit)" : "Track Current Value",
                   isOn: $form.hasCurrentValue.animation())
            if form.hasCurrentValue {
                currencyField(value: $form.currentValue, field: .currentValue)
                if form.quantity > 1 {
                    totalRow(form.currentValue)
                }
            }
        } header: {
            Text("Current Value")
        } footer: {
            Text(form.hasCurrentValue
                 ? "Totals use the current value instead of the purchase price."
                 : "Optional. Useful for items that have depreciated or appreciated.")
        }
        .onChange(of: form.hasCurrentValue) { _, isOn in
            // Start from the purchase price, which is usually a better guess than zero.
            if isOn && form.currentValue == 0 && form.hasPurchasePrice {
                form.currentValue = form.purchasePrice
            }
        }
    }

    private func currencyField(value: Binding<Double>, field: Field) -> some View {
        HStack {
            Text(Locale.current.currencySymbol ?? "$").foregroundStyle(Theme.secondaryText)
            TextField("0.00", value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
        }
    }

    private func totalRow(_ unit: Double) -> some View {
        HStack {
            Text("Total for \(form.quantity)")
            Spacer()
            Text((unit * Double(form.quantity)).currencyString)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.secondaryText)
    }

    private var warrantySection: some View {
        Section("Warranty") {
            Toggle("Has Warranty", isOn: $form.hasWarranty.animation())
            if form.hasWarranty {
                DatePicker("Expires", selection: $form.warrantyExpiration, displayedComponents: .date)
                HStack(spacing: 8) {
                    Text(form.hasPurchaseDate ? "From purchase:" : "From today:")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    ForEach([1, 2, 3, 5], id: \.self) { years in
                        Button("\(years)y") { setWarranty(years: years) }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    }
                }
                TextField("Provider (e.g. AppleCare)", text: $form.warrantyProvider)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Add notes…", text: $form.notes, axis: .vertical)
                .lineLimit(2...8)
        }
    }

    private var documentsSection: some View {
        Section {
            ForEach(form.documents) { doc in
                HStack(spacing: 12) {
                    Image(systemName: doc.isPDF ? "doc.richtext.fill" : "photo.fill")
                        .foregroundStyle(doc.isPDF ? .red : .blue)
                        .frame(width: 24)
                    Text(doc.filename.isEmpty ? "Document" : doc.filename)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onDelete { form.documents.remove(atOffsets: $0) }

            if DocumentScanner.isAvailable {
                Button {
                    showingDocumentScanner = true
                } label: {
                    Label("Scan Receipt or Document", systemImage: "doc.viewfinder")
                }
            }
            Button {
                showingDocumentPicker = true
            } label: {
                Label("Import from Files…", systemImage: "doc.badge.plus")
            }
        } header: {
            Text("Receipts & Documents")
        } footer: {
            if !form.documents.isEmpty {
                Text("Swipe left on a document to remove it.")
            }
        }
    }

    // MARK: - Photos

    private func importPickedPhotos(_ pickerItems: [PhotosPickerItem]) {
        isProcessingPhotos = true
        Task {
            for pickerItem in pickerItems {
                guard canAddPhotos,
                      let raw = try? await pickerItem.loadTransferable(type: Data.self) else { continue }
                let prepared = await Task.detached(priority: .userInitiated) {
                    ImageProcessing.preparedPhotoData(from: raw)
                }.value
                if let prepared {
                    form.photos.append(EditablePhoto(data: prepared))
                }
            }
            selectedPhotos = []
            isProcessingPhotos = false
        }
    }

    private func addPhoto(_ image: UIImage) {
        guard canAddPhotos else { return }
        isProcessingPhotos = true
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                ImageProcessing.preparedPhotoData(from: image)
            }.value
            if let prepared { form.photos.append(EditablePhoto(data: prepared)) }
            isProcessingPhotos = false
        }
    }

    private func movePhoto(_ id: UUID, toIndex target: Int) {
        guard let source = form.photos.firstIndex(where: { $0.id == id }), source != target else { return }
        withAnimation {
            form.photos.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
        }
    }

    private func setWarranty(years: Int) {
        let base = form.hasPurchaseDate ? form.purchaseDate : Date()
        form.warrantyExpiration = Calendar.current.date(byAdding: .year, value: years, to: base) ?? base
    }

    // MARK: - Document Import

    private func handleDocumentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var failed: [String] = []
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    failed.append(url.lastPathComponent)
                    continue
                }
                form.documents.append(EditableDocument(data: data, filename: url.lastPathComponent, existing: nil))
            }
            if !failed.isEmpty {
                errorMessage = "Couldn't read \(ListFormatter.localizedString(byJoining: failed))."
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Barcode Lookup

    private func lookUpBarcode(_ barcode: String) {
        isLookingUpBarcode = true
        Task {
            defer { isLookingUpBarcode = false }
            do {
                let info = try await ProductLookup.lookUp(barcode)
                if form.name.isEmpty, let title = info.title { form.name = title }
                if form.make.isEmpty, let brand = info.brand { form.make = brand }
                if form.model.isEmpty, let model = info.model { form.model = model }
                if form.itemDescription.isEmpty, let description = info.description {
                    form.itemDescription = String(description.prefix(500))
                }
                if form.photos.isEmpty, let image = await ProductLookup.fetchImage(from: info.imageURLs) {
                    form.photos.append(EditablePhoto(data: image))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Load / Save

    private func loadIfNeeded() {
        // onAppear can fire again after covers (camera, scanner) dismiss; don't clobber edits.
        guard !didLoad else { return }
        didLoad = true

        var f = ItemForm()
        if let item {
            f.name = item.name
            f.itemDescription = item.itemDescription
            f.quantity = item.quantity
            f.category = item.category ?? .other
            f.condition = item.condition
            f.room = item.room
            f.make = item.make
            f.model = item.model
            f.serialNumber = item.serialNumber
            f.purchaseStore = item.purchaseStore
            f.warrantyProvider = item.warrantyProvider
            f.notes = item.notes
            f.photos = item.sortedPhotos.compactMap { photo in
                photo.imageData.map { EditablePhoto(data: $0, existing: photo) }
            }
            f.documents = (item.receipts ?? []).compactMap { receipt in
                receipt.fileData.map { EditableDocument(data: $0, filename: receipt.filename, existing: receipt) }
            }
            if let price = item.purchasePrice { f.hasPurchasePrice = true; f.purchasePrice = price }
            if let date = item.purchaseDate { f.hasPurchaseDate = true; f.purchaseDate = date }
            if let value = item.currentValue { f.hasCurrentValue = true; f.currentValue = value }
            if let expiry = item.warrantyExpiration { f.hasWarranty = true; f.warrantyExpiration = expiry }
        } else {
            f.room = preselectedRoom
        }
        form = f
        initialForm = f
        if item == nil { focusedField = .name }
    }

    private func attemptSave() {
        let trimmed = form.trimmedName
        let nameChanged = trimmed.lowercased() != item?.name.lowercased()
        let isDuplicate = nameChanged && allItems.contains {
            $0.persistentModelID != item?.persistentModelID &&
            $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if isDuplicate {
            showingDuplicateAlert = true
        } else {
            save()
        }
    }

    private func save() {
        let target: Item
        if let existing = item {
            target = existing
        } else {
            target = Item()
            modelContext.insert(target)
        }

        target.name = form.trimmedName
        target.itemDescription = form.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        target.quantity = form.quantity
        target.category = form.category
        target.condition = form.condition
        target.room = form.room
        target.make = form.make.trimmingCharacters(in: .whitespaces)
        target.model = form.model.trimmingCharacters(in: .whitespaces)
        target.serialNumber = form.serialNumber.trimmingCharacters(in: .whitespaces)
        target.purchasePrice = form.hasPurchasePrice ? max(0, form.purchasePrice) : nil
        target.purchaseDate = form.hasPurchaseDate ? form.purchaseDate : nil
        target.purchaseStore = form.purchaseStore.trimmingCharacters(in: .whitespaces)
        target.currentValue = form.hasCurrentValue ? max(0, form.currentValue) : nil
        target.warrantyExpiration = form.hasWarranty ? form.warrantyExpiration : nil
        target.warrantyProvider = form.hasWarranty ? form.warrantyProvider.trimmingCharacters(in: .whitespaces) : ""
        target.notes = form.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Photos: keep existing records (avoids re-uploading to iCloud), delete removed, add new.
        let keptPhotoIDs = Set(form.photos.compactMap { $0.existing?.persistentModelID })
        for photo in target.photos ?? [] where !keptPhotoIDs.contains(photo.persistentModelID) {
            modelContext.delete(photo)
        }
        for (index, editable) in form.photos.enumerated() {
            if let existing = editable.existing {
                if existing.sortIndex != index { existing.sortIndex = index }
            } else {
                let photo = Photo(imageData: editable.data, sortIndex: index)
                photo.item = target
                modelContext.insert(photo)
            }
        }

        // Documents: same approach.
        let keptDocIDs = Set(form.documents.compactMap { $0.existing?.persistentModelID })
        for receipt in target.receipts ?? [] where !keptDocIDs.contains(receipt.persistentModelID) {
            modelContext.delete(receipt)
        }
        for doc in form.documents where doc.existing == nil {
            let receipt = Receipt(fileData: doc.data, filename: doc.filename)
            receipt.item = target
            modelContext.insert(receipt)
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            return
        }
        dismiss()
    }
}
