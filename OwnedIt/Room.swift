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

    init(name: String, icon: String = "house", colorName: String = "blue") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.items = []
        self.dateCreated = Date()
    }

    var color: Color {
        switch colorName {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return .green
        case "blue":   return .blue
        case "purple": return .purple
        case "pink":   return .pink
        case "teal":   return .teal
        default:       return .blue
        }
    }

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
        "house", "bed.double", "sofa", "fork.knife", "washer", "shower",
        "car.fill", "shippingbox", "tent", "building.2", "trash", "garage"
    ]
}
