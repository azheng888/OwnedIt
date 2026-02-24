import SwiftUI

enum ItemCategory: String, CaseIterable, Codable {
    case electronics = "Electronics"
    case furniture = "Furniture"
    case appliances = "Appliances"
    case clothing = "Clothing"
    case jewelry = "Jewelry"
    case tools = "Tools"
    case sports = "Sports"
    case books = "Books"
    case art = "Art"
    case kitchen = "Kitchen"
    case outdoor = "Outdoor"
    case other = "Other"

    var icon: String {
        switch self {
        case .electronics: return "tv"
        case .furniture: return "sofa"
        case .appliances: return "washer"
        case .clothing: return "tshirt"
        case .jewelry: return "sparkles"
        case .tools: return "wrench.and.screwdriver"
        case .sports: return "figure.run"
        case .books: return "books.vertical"
        case .art: return "paintpalette"
        case .kitchen: return "fork.knife"
        case .outdoor: return "leaf"
        case .other: return "archivebox"
        }
    }
}

enum ItemCondition: String, CaseIterable, Codable {
    case new = "New"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var color: Color {
        switch self {
        case .new: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}
