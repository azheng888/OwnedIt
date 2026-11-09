import SwiftUI
import SwiftData

@Model
final class Room {
    var id: UUID?
    var name: String = ""
    var icon: String = "house"
    var colorName: String = "blue"
    @Relationship(deleteRule: .nullify, inverse: \Item.room)
    var items: [Item]?
    var dateCreated: Date?

    var itemCount: Int { (items ?? []).count }
    var totalValue: Double { (items ?? []).compactMap(\.displayValue).reduce(0, +) }

    init(name: String, icon: String = "house", colorName: String = "blue") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.items = []
        self.dateCreated = Date()
    }

    /// Rooms no longer use decorative colors (single neutral icon style); kept for API compatibility.
    var color: Color { Theme.secondaryText }

    static let colorOptions: [(name: String, color: Color)] = [
        ("blue",   .blue),
        ("green",  .green),
        ("orange", .orange),
        ("red",    .red),
        ("purple", .purple),
        ("pink",   .pink),
        ("teal",   .teal),
        ("yellow", .yellow)
    ]

    static let iconOptions = [
        "house", "sofa", "bed.double", "fork.knife", "refrigerator", "shower",
        "washer", "desktopcomputer", "lamp.desk", "tv", "books.vertical", "figure.and.child.holdinghands",
        "door.garage.closed", "car.fill", "wrench.and.screwdriver", "shippingbox", "archivebox", "stairs",
        "tree", "tent", "dumbbell", "pawprint", "building.2", "suitcase"
    ]
}
