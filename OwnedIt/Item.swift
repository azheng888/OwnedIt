import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var name: String
    var itemDescription: String
    var category: ItemCategory
    var room: Room?
    var make: String
    var model: String
    var serialNumber: String
    var condition: ItemCondition
    var purchasePrice: Double?
    var purchaseDate: Date?
    var purchaseStore: String
    var currentValue: Double?
    var warrantyExpiration: Date?
    var warrantyProvider: String
    var photos: [Data]
    var notes: String
    var dateAdded: Date

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
        photos: [Data] = [],
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
        self.photos = photos
        self.notes = notes
        self.dateAdded = Date()
    }

    // Returns current value if set, otherwise falls back to purchase price
    var displayValue: Double? {
        currentValue ?? purchasePrice
    }
}
