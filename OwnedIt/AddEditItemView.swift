import SwiftUI
import SwiftData
import PhotosUI

struct AddEditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.name) private var rooms: [Room]

    var item: Item? = nil
    var preselectedRoom: Room? = nil

    // Basic Info
    @State private var name = ""
    @State private var itemDescription = ""
    @State private var category: ItemCategory = .other
    @State private var condition: ItemCondition = .good

    // Location
    @State private var selectedRoom: Room?

    // Identification
    @State private var make = ""
    @State private var model = ""
    @State private var serialNumber = ""

    // Purchase
    @State private var hasPurchasePrice = false
    @State private var purchasePrice = 0.0
    @State private var hasPurchaseDate = false
    @State private var purchaseDate = Date()
    @State private var purchaseStore = ""

    // Value
    @State private var hasCurrentValue = false
    @State private var currentValue = 0.0

    // Warranty
    @State private var hasWarranty = false
    @State private var warrantyExpiration = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var warrantyProvider = ""

    // Notes & Photos
    @State private var notes = ""
    @State private var photoData: [Data] = []         // working copy of image bytes
    @State private var selectedPhotos: [PhotosPickerItem] = []

    // Barcode scanner
    @State private var showingBarcodeScanner = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeLookupError: String?

    var isEditing: Bool { item != nil }

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
        }
        .navigationTitle(isEditing ? "Edit Item" : "New Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let item {
                loadFrom(item)
            } else if let preselectedRoom {
                selectedRoom = preselectedRoom
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                for pickerItem in newItems {
                    if let data = try? await pickerItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let compressed = image.jpegData(compressionQuality: 0.75) {
                        photoData.append(compressed)
                    }
                }
                selectedPhotos = []
            }
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerSheet { barcode in
                showingBarcodeScanner = false
                lookUpBarcode(barcode)
            }
        }
        .overlay {
            if isLookingUpBarcode {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Looking up product…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Barcode Lookup Failed", isPresented: .constant(barcodeLookupError != nil)) {
            Button("OK") { barcodeLookupError = nil }
        } message: {
            Text(barcodeLookupError ?? "")
        }
    }

    // MARK: - Sections

    private var photosSection: some View {
        Section("Photos") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                            Text("Add Photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    ForEach(Array(photoData.enumerated()), id: \.offset) { index, data in
                        if let uiImage = UIImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    photoData.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.6))
                                        .font(.system(size: 20))
                                }
                                .padding(3)
                            }
                            .draggable(String(index))
                            .dropDestination(for: String.self) { items, _ in
                                guard let src = items.first.flatMap(Int.init) else { return false }
                                photoData.move(
                                    fromOffsets: IndexSet(integer: src),
                                    toOffset: index > src ? index + 1 : index
                                )
                                return true
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var basicInfoSection: some View {
        Section("Basic Info") {
            HStack {
                TextField("Name", text: $name)
                Button {
                    showingBarcodeScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(Color.accentColor)
                }
            }

            TextField("Description", text: $itemDescription, axis: .vertical)
                .lineLimit(3, reservesSpace: false)

            Picker("Category", selection: $category) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }

            Picker("Condition", selection: $condition) {
                ForEach(ItemCondition.allCases, id: \.self) { cond in
                    Text(cond.rawValue).tag(cond)
                }
            }
        }
    }

    private var locationSection: some View {
        Section("Location") {
            Picker("Room", selection: $selectedRoom) {
                Text("None").tag(Room?.none)
                ForEach(rooms) { room in
                    Label(room.name, systemImage: room.icon).tag(Room?.some(room))
                }
            }
        }
    }

    private var identificationSection: some View {
        Section("Identification") {
            TextField("Make (e.g. Apple, IKEA)", text: $make)
            TextField("Model", text: $model)
            TextField("Serial Number", text: $serialNumber)
        }
    }

    private var purchaseSection: some View {
        Section("Purchase") {
            Toggle("Purchase Price", isOn: $hasPurchasePrice.animation())
            if hasPurchasePrice {
                HStack {
                    Text(Locale.current.currencySymbol ?? "$").foregroundStyle(.secondary)
                    TextField("0.00", value: $purchasePrice, format: .number)
                        .keyboardType(.decimalPad)
                }
            }

            Toggle("Purchase Date", isOn: $hasPurchaseDate.animation())
            if hasPurchaseDate {
                DatePicker("", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
            }

            TextField("Store / Retailer", text: $purchaseStore)
        }
    }

    private var valueSection: some View {
        Section {
            Toggle("Track Current Value", isOn: $hasCurrentValue.animation())
            if hasCurrentValue {
                HStack {
                    Text(Locale.current.currencySymbol ?? "$").foregroundStyle(.secondary)
                    TextField("0.00", value: $currentValue, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
        } header: {
            Text("Current Value")
        } footer: {
            if hasCurrentValue {
                Text("Use this to track depreciation or appreciation over time.")
            }
        }
    }

    private var warrantySection: some View {
        Section("Warranty") {
            Toggle("Has Warranty", isOn: $hasWarranty.animation())
            if hasWarranty {
                DatePicker("Expires", selection: $warrantyExpiration, displayedComponents: .date)
                TextField("Provider (e.g. AppleCare)", text: $warrantyProvider)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Add notes…", text: $notes, axis: .vertical)
                .lineLimit(5, reservesSpace: false)
        }
    }

    // MARK: - Barcode Lookup

    private func lookUpBarcode(_ barcode: String) {
        serialNumber = barcode
        isLookingUpBarcode = true

        guard let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(encodedBarcode)") else {
            isLookingUpBarcode = false
            return
        }

        Task {
            defer { isLookingUpBarcode = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]],
                   let first = items.first {
                    await MainActor.run {
                        if name.isEmpty, let title = first["title"] as? String {
                            name = title
                        }
                        if make.isEmpty, let brand = first["brand"] as? String {
                            make = brand
                        }
                        if model.isEmpty, let mdl = first["model"] as? String {
                            model = mdl
                        }
                    }
                } else {
                    await MainActor.run {
                        barcodeLookupError = "No product found for barcode \(barcode). You can still enter details manually."
                    }
                }
            } catch {
                await MainActor.run {
                    barcodeLookupError = "Could not reach the product database. Check your connection."
                }
            }
        }
    }

    // MARK: - Load / Save

    private func loadFrom(_ item: Item) {
        name = item.name
        itemDescription = item.itemDescription
        category = item.category ?? .other
        condition = item.condition ?? .good
        selectedRoom = item.room
        make = item.make
        model = item.model
        serialNumber = item.serialNumber
        purchaseStore = item.purchaseStore
        warrantyProvider = item.warrantyProvider
        notes = item.notes
        photoData = (item.photos ?? []).compactMap { $0.imageData }

        if let price = item.purchasePrice { hasPurchasePrice = true; purchasePrice = price }
        if let date = item.purchaseDate   { hasPurchaseDate = true;  purchaseDate = date }
        if let value = item.currentValue  { hasCurrentValue = true;  currentValue = value }
        if let expiry = item.warrantyExpiration { hasWarranty = true; warrantyExpiration = expiry }
    }

    private func save() {
        let target: Item
        if let existing = item {
            target = existing
        } else {
            target = Item()
            modelContext.insert(target)
        }

        target.name = name.trimmingCharacters(in: .whitespaces)
        target.itemDescription = itemDescription
        target.category = category
        target.condition = condition
        target.room = selectedRoom
        target.make = make
        target.model = model
        target.serialNumber = serialNumber
        target.purchasePrice = hasPurchasePrice ? purchasePrice : nil
        target.purchaseDate = hasPurchaseDate ? purchaseDate : nil
        target.purchaseStore = purchaseStore
        target.currentValue = hasCurrentValue ? currentValue : nil
        target.warrantyExpiration = hasWarranty ? warrantyExpiration : nil
        target.warrantyProvider = warrantyProvider
        target.notes = notes

        // Replace photos
        for existing in target.photos ?? [] { modelContext.delete(existing) }
        for data in photoData {
            let photo = Photo(imageData: data)
            photo.item = target
            modelContext.insert(photo)
        }

        dismiss()
    }
}
