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
    @State private var photos: [Data] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []

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
                        photos.append(compressed)
                    }
                }
                selectedPhotos = []
            }
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

                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                        if let uiImage = UIImage(data: photoData) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    photos.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.6))
                                        .font(.system(size: 20))
                                }
                                .padding(3)
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
            TextField("Name", text: $name)
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
                    Text(Locale.current.currencySymbol ?? "$")
                        .foregroundStyle(.secondary)
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
                    Text(Locale.current.currencySymbol ?? "$")
                        .foregroundStyle(.secondary)
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

    // MARK: - Helpers

    private func loadFrom(_ item: Item) {
        name = item.name
        itemDescription = item.itemDescription
        category = item.category
        condition = item.condition
        selectedRoom = item.room
        make = item.make
        model = item.model
        serialNumber = item.serialNumber
        purchaseStore = item.purchaseStore
        warrantyProvider = item.warrantyProvider
        notes = item.notes
        photos = item.photos

        if let price = item.purchasePrice {
            hasPurchasePrice = true
            purchasePrice = price
        }
        if let date = item.purchaseDate {
            hasPurchaseDate = true
            purchaseDate = date
        }
        if let value = item.currentValue {
            hasCurrentValue = true
            currentValue = value
        }
        if let expiry = item.warrantyExpiration {
            hasWarranty = true
            warrantyExpiration = expiry
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
        target.photos = photos

        dismiss()
    }
}
