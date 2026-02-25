import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID?
    var name: String = ""
    var itemDescription: String = ""
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
    var notes: String = ""
    var dateAdded: Date?

    init(
        name: String = "",
        itemDescription: String = "",
        category: ItemCategory = .other,
        room: Room? = nil,
        make: String = "",
        model: String = "",
        serialNumber: String = "",
        condition: ItemCondition = .good,
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
        self.notes = notes
        self.dateAdded = Date()
    }

    var displayValue: Double? {
        currentValue ?? purchasePrice
    }
}

// MARK: - Undo Support

struct DeletedItemMemento {
    let name: String
    let itemDescription: String
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

    init(from item: Item) {
        self.name = item.name
        self.itemDescription = item.itemDescription
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
    }
}

func restoreItem(from memento: DeletedItemMemento, in context: ModelContext) {
    let item = Item(
        name: memento.name,
        itemDescription: memento.itemDescription,
        category: memento.category ?? .other,
        room: memento.room,
        make: memento.make,
        model: memento.model,
        serialNumber: memento.serialNumber,
        condition: memento.condition ?? .good,
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
}
