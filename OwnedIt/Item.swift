import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID?
    var name: String = ""
    var itemDescription: String = ""
    var quantity: Int = 1
    var category: ItemCategory?
    var room: Room?
    var make: String = ""
    var model: String = ""
    var serialNumber: String = ""
    var condition: ItemCondition?
    var purchasePrice: Double?
    var purchaseDate: Date?
    var purchaseStore: String = ""
    var currentValue: Double?
    var warrantyExpiration: Date?
    var warrantyProvider: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Photo.item)
    var photos: [Photo]?
    @Relationship(deleteRule: .cascade, inverse: \Receipt.item)
    var receipts: [Receipt]?
    @Relationship(deleteRule: .cascade, inverse: \Reminder.item)
    var reminders: [Reminder]?
    var notes: String = ""
    var dateAdded: Date?

    init(
        name: String = "",
        itemDescription: String = "",
        quantity: Int = 1,
        category: ItemCategory = .other,
        room: Room? = nil,
        make: String = "",
        model: String = "",
        serialNumber: String = "",
        condition: ItemCondition? = nil,
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        purchaseStore: String = "",
        currentValue: Double? = nil,
        warrantyExpiration: Date? = nil,
        warrantyProvider: String = "",
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.itemDescription = itemDescription
        self.quantity = max(1, quantity)
        self.category = category
        self.room = room
        self.make = make
        self.model = model
        self.serialNumber = serialNumber
        self.condition = condition
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.purchaseStore = purchaseStore
        self.currentValue = currentValue
        self.warrantyExpiration = warrantyExpiration
        self.warrantyProvider = warrantyProvider
        self.photos = []
        self.receipts = []
        self.reminders = []
        self.notes = notes
        self.dateAdded = Date()
    }

    var displayName: String { name.isEmpty ? "Unnamed Item" : name }

    /// Price per unit, preferring the tracked current value over the original purchase price.
    var unitValue: Double? {
        currentValue ?? purchasePrice
    }

    /// Total value for this line item — unit value × quantity.
    var displayValue: Double? {
        unitValue.map { $0 * Double(quantity) }
    }

    var sortedPhotos: [Photo] {
        (photos ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var thumbnailData: Data? {
        sortedPhotos.first.flatMap { $0.thumbnailData ?? $0.imageData }
    }

    var hasPhotos: Bool { !(photos ?? []).isEmpty }
    var hasReceipts: Bool { !(receipts ?? []).isEmpty }

    var isWarrantyExpired: Bool {
        guard let exp = warrantyExpiration else { return false }
        return exp < Calendar.current.startOfDay(for: Date())
    }

    func matches(search query: String) -> Bool {
        let fields = [name, make, model, serialNumber, itemDescription, notes, purchaseStore,
                      warrantyProvider, room?.name ?? "", (category ?? .other).rawValue]
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

// MARK: - Undo Support

/// A value snapshot of an item (and its children) so a delete can be undone.
struct DeletedItemMemento {
    let id: UUID?
    let name: String
    let itemDescription: String
    let quantity: Int
    let category: ItemCategory?
    let room: Room?
    let make: String
    let model: String
    let serialNumber: String
    let condition: ItemCondition?
    let purchasePrice: Double?
    let purchaseDate: Date?
    let purchaseStore: String
    let currentValue: Double?
    let warrantyExpiration: Date?
    let warrantyProvider: String
    let notes: String
    let dateAdded: Date?
    let photoData: [Data]
    let receiptData: [(data: Data, filename: String)]
    let reminderData: [(title: String, notes: String, intervalDays: Int, nextDueDate: Date, isActive: Bool)]

    init(from item: Item) {
        self.id = item.id
        self.name = item.name
        self.itemDescription = item.itemDescription
        self.quantity = item.quantity
        self.category = item.category
        self.room = item.room
        self.make = item.make
        self.model = item.model
        self.serialNumber = item.serialNumber
        self.condition = item.condition
        self.purchasePrice = item.purchasePrice
        self.purchaseDate = item.purchaseDate
        self.purchaseStore = item.purchaseStore
        self.currentValue = item.currentValue
        self.warrantyExpiration = item.warrantyExpiration
        self.warrantyProvider = item.warrantyProvider
        self.notes = item.notes
        self.dateAdded = item.dateAdded
        self.photoData = item.sortedPhotos.compactMap { $0.imageData }
        self.receiptData = (item.receipts ?? []).compactMap {
            guard let data = $0.fileData else { return nil }
            return (data, $0.filename)
        }
        self.reminderData = (item.reminders ?? []).map {
            ($0.title, $0.notes, $0.intervalDays, $0.nextDueDate, $0.isActive)
        }
    }
}

enum ItemActions {
    /// Deletes items and returns mementos that can restore them.
    @discardableResult
    static func delete(_ items: [Item], in context: ModelContext) -> [DeletedItemMemento] {
        let mementos = items.map(DeletedItemMemento.init(from:))
        for item in items { context.delete(item) }
        return mementos
    }

    static func restore(_ memento: DeletedItemMemento, in context: ModelContext) {
        let item = Item(
            name: memento.name,
            itemDescription: memento.itemDescription,
            quantity: memento.quantity,
            category: memento.category ?? .other,
            room: memento.room,
            make: memento.make,
            model: memento.model,
            serialNumber: memento.serialNumber,
            condition: memento.condition,
            purchasePrice: memento.purchasePrice,
            purchaseDate: memento.purchaseDate,
            purchaseStore: memento.purchaseStore,
            currentValue: memento.currentValue,
            warrantyExpiration: memento.warrantyExpiration,
            warrantyProvider: memento.warrantyProvider,
            notes: memento.notes
        )
        item.id = memento.id ?? UUID()
        item.dateAdded = memento.dateAdded ?? Date()
        context.insert(item)
        attachChildren(to: item, photos: memento.photoData, receipts: memento.receiptData, in: context)
        for entry in memento.reminderData {
            let reminder = Reminder(title: entry.title, notes: entry.notes, intervalDays: entry.intervalDays, nextDueDate: entry.nextDueDate)
            reminder.isActive = entry.isActive
            reminder.item = item
            context.insert(reminder)
        }
    }

    /// Creates a copy of an item (minus serial number, which is unique per physical object).
    @discardableResult
    static func duplicate(_ source: Item, in context: ModelContext) -> Item {
        let copy = Item(
            name: source.name.isEmpty ? "(Copy)" : "\(source.name) (Copy)",
            itemDescription: source.itemDescription,
            quantity: source.quantity,
            category: source.category ?? .other,
            room: source.room,
            make: source.make,
            model: source.model,
            serialNumber: "",
            condition: source.condition,
            purchasePrice: source.purchasePrice,
            purchaseDate: source.purchaseDate,
            purchaseStore: source.purchaseStore,
            currentValue: source.currentValue,
            warrantyExpiration: source.warrantyExpiration,
            warrantyProvider: source.warrantyProvider,
            notes: source.notes
        )
        context.insert(copy)
        let receipts: [(data: Data, filename: String)] = (source.receipts ?? []).compactMap {
            guard let data = $0.fileData else { return nil }
            return (data, $0.filename)
        }
        attachChildren(to: copy, photos: source.sortedPhotos.compactMap(\.imageData), receipts: receipts, in: context)
        for reminder in source.reminders ?? [] {
            let r = Reminder(title: reminder.title, notes: reminder.notes,
                             intervalDays: reminder.intervalDays, nextDueDate: reminder.nextDueDate)
            r.isActive = reminder.isActive
            r.item = copy
            context.insert(r)
        }
        return copy
    }

    private static func attachChildren(to item: Item, photos: [Data], receipts: [(data: Data, filename: String)], in context: ModelContext) {
        for (index, data) in photos.enumerated() {
            let photo = Photo(imageData: data, sortIndex: index)
            photo.item = item
            context.insert(photo)
        }
        for entry in receipts {
            let receipt = Receipt(fileData: entry.data, filename: entry.filename)
            receipt.item = item
            context.insert(receipt)
        }
    }
}
