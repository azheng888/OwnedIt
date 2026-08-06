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

    /// Price per unit, preferring the tracked current value over the original purchase price.
    var unitValue: Double? {
        currentValue ?? purchasePrice
    }

    /// Total value for this line item — unit value × quantity.
    var displayValue: Double? {
        unitValue.map { $0 * Double(quantity) }
    }
}

// MARK: - Undo Support

struct DeletedItemMemento {
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
    let photoData: [Data]
    let receiptData: [(data: Data, filename: String)]
    let reminderData: [(title: String, notes: String, intervalDays: Int, nextDueDate: Date)]

    init(from item: Item) {
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
        self.photoData = (item.photos ?? []).compactMap { $0.imageData }
        self.receiptData = (item.receipts ?? []).compactMap {
            guard let data = $0.fileData else { return nil }
            return (data, $0.filename)
        }
        self.reminderData = (item.reminders ?? []).map {
            ($0.title, $0.notes, $0.intervalDays, $0.nextDueDate)
        }
    }
}

func restoreItem(from memento: DeletedItemMemento, in context: ModelContext) {
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
    context.insert(item)
    for data in memento.photoData {
        let photo = Photo(imageData: data)
        photo.item = item
        context.insert(photo)
    }
    for entry in memento.receiptData {
        let receipt = Receipt(fileData: entry.data, filename: entry.filename)
        receipt.item = item
        context.insert(receipt)
    }
    for entry in memento.reminderData {
        let reminder = Reminder(title: entry.title, notes: entry.notes, intervalDays: entry.intervalDays, nextDueDate: entry.nextDueDate)
        reminder.item = item
        context.insert(reminder)
        if entry.nextDueDate > Date() {
            NotificationManager.shared.schedule(reminder, itemName: item.name)
        }
    }
}
