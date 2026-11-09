#if DEBUG
import SwiftUI
import SwiftData

/// Debug-only demo data. Launch with `-seedSampleData YES` to populate an empty store
/// (useful for simulator testing and App Store screenshots).
enum SampleData {
    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedSampleData") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Item>())) ?? 0
        guard existing == 0 else { return }

        let living = Room(name: "Living Room", icon: "sofa", colorName: "blue")
        let kitchen = Room(name: "Kitchen", icon: "fork.knife", colorName: "orange")
        let bedroom = Room(name: "Bedroom", icon: "bed.double", colorName: "purple")
        let office = Room(name: "Office", icon: "desktopcomputer", colorName: "teal")
        let garage = Room(name: "Garage", icon: "door.garage.closed", colorName: "green")
        [living, kitchen, bedroom, office, garage].forEach(context.insert)

        let cal = Calendar.current
        func ago(_ months: Int) -> Date { cal.date(byAdding: .month, value: -months, to: Date())! }
        func ahead(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: Date())! }

        struct Spec {
            let name: String, cat: ItemCategory, room: Room, make: String, price: Double
            var value: Double? = nil, months: Int = 12, warrantyDays: Int? = nil, serial: String = ""
            var condition: ItemCondition = .good, qty: Int = 1, color: UIColor = .systemGray
        }

        let specs: [Spec] = [
            Spec(name: "OLED Television 65\"", cat: .electronics, room: living, make: "LG", price: 1899, value: 1400, months: 14, warrantyDays: 45, serial: "LG65C3PUA8842", color: .systemIndigo),
            Spec(name: "Linen Sofa", cat: .furniture, room: living, make: "Article", price: 2450, months: 30, condition: .good, color: .systemBrown),
            Spec(name: "Turntable", cat: .electronics, room: living, make: "Technics", price: 549, months: 8, serial: "SL1500C-0193", condition: .new, color: .systemTeal),
            Spec(name: "Espresso Machine", cat: .appliances, room: kitchen, make: "Breville", price: 699, value: 550, months: 18, warrantyDays: 120, serial: "BES878BSS1", color: .systemOrange),
            Spec(name: "Stand Mixer", cat: .kitchen, room: kitchen, make: "KitchenAid", price: 449, months: 40, color: .systemRed),
            Spec(name: "Chef's Knife Set", cat: .kitchen, room: kitchen, make: "Wüsthof", price: 120, months: 22, qty: 3, color: .systemGray),
            Spec(name: "Engagement Ring", cat: .jewelry, room: bedroom, make: "Tiffany & Co.", price: 6200, value: 6800, months: 36, condition: .new, color: .systemPink),
            Spec(name: "Wool Coat", cat: .clothing, room: bedroom, make: "Everlane", price: 298, months: 10, color: .systemBrown),
            Spec(name: "MacBook Pro 14\"", cat: .electronics, room: office, make: "Apple", price: 2399, value: 1900, months: 11, warrantyDays: 20, serial: "C02XK1Y4MD6T", condition: .new, color: .systemGray),
            Spec(name: "Standing Desk", cat: .furniture, room: office, make: "Fully", price: 699, months: 26, color: .systemBrown),
            Spec(name: "Cordless Drill", cat: .tools, room: garage, make: "DeWalt", price: 179, months: 30, serial: "DCD791-2231", condition: .fair, color: .systemYellow),
            Spec(name: "Road Bike", cat: .sports, room: garage, make: "Trek", price: 1850, value: 1300, months: 28, color: .systemGreen),
        ]

        var created: [Item] = []
        for (index, s) in specs.enumerated() {
            let item = Item(name: s.name, quantity: s.qty, category: s.cat, room: s.room, make: s.make,
                            serialNumber: s.serial, condition: s.condition, purchasePrice: s.price,
                            purchaseDate: ago(s.months), currentValue: s.value,
                            warrantyExpiration: s.warrantyDays.map(ahead))
            item.dateAdded = cal.date(byAdding: .hour, value: -index * 20, to: Date())
            context.insert(item)
            // Leave a few without photos so Claim Readiness has something to show.
            if index % 4 != 3, let data = placeholderPhoto(symbol: s.cat.icon, color: s.color) {
                let photo = Photo(imageData: data)
                photo.item = item
                context.insert(photo)
            }
            if index % 3 == 0, let receipt = "%PDF-1.4\n%sample".data(using: .utf8) {
                let r = Receipt(fileData: receipt, filename: "\(s.make) receipt.pdf")
                r.item = item
                context.insert(r)
            }
            created.append(item)
        }

        let reminders: [(String, Int, Int, Int)] = [
            ("Descale", 3, 30, 0), ("Clean filter", 9, 90, 3), ("Tune-up", 10, 180, 40), ("Sharpen", 5, 60, -2),
        ]
        for (title, itemIndex, interval, dueIn) in reminders {
            let r = Reminder(title: title, intervalDays: interval, nextDueDate: ahead(dueIn))
            r.item = created[itemIndex]
            context.insert(r)
        }
        try? context.save()
    }

    /// Neutral warm tile with a soft glyph — stands in for a real photo.
    private static func placeholderPhoto(symbol: String, color: UIColor) -> Data? {
        let size = CGSize(width: 800, height: 800)
        let tones: [UInt32] = [0xE2DCCF, 0xDAD4C6, 0xE6E0D4, 0xD8D2C4]
        let tone = UIColor(hex: tones[abs(symbol.hashValue) % tones.count])
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            tone.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let config = UIImage.SymbolConfiguration(pointSize: 220, weight: .light)
            if let glyph = UIImage(systemName: symbol, withConfiguration: config)?
                .withTintColor(UIColor(hex: 0x77715F).withAlphaComponent(0.55), renderingMode: .alwaysOriginal) {
                let rect = CGRect(x: (size.width - glyph.size.width) / 2, y: (size.height - glyph.size.height) / 2,
                                  width: glyph.size.width, height: glyph.size.height)
                glyph.draw(in: rect)
            }
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
#endif
