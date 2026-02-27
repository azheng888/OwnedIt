import UIKit
import SwiftData

struct ExportManager {

    // MARK: - CSV

    static func csvData(from items: [Item]) -> Data {
        var rows: [String] = [
            "Name,Category,Room,Make,Model,Serial Number,Condition,Purchase Price,Purchase Date,Current Value,Warranty Expires,Store,Notes,Date Added"
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        for item in items.sorted(by: { $0.name < $1.name }) {
            let fields: [String] = [
                csvEscape(item.name),
                csvEscape((item.category ?? .other).rawValue),
                csvEscape(item.room?.name ?? ""),
                csvEscape(item.make),
                csvEscape(item.model),
                csvEscape(item.serialNumber),
                csvEscape((item.condition ?? .good).rawValue),
                item.purchasePrice.map { String(format: "%.2f", $0) } ?? "",
                item.purchaseDate.map { dateFormatter.string(from: $0) } ?? "",
                item.currentValue.map { String(format: "%.2f", $0) } ?? "",
                item.warrantyExpiration.map { dateFormatter.string(from: $0) } ?? "",
                csvEscape(item.purchaseStore),
                csvEscape(item.notes),
                item.dateAdded.map { dateFormatter.string(from: $0) } ?? ""
            ]
            rows.append(fields.joined(separator: ","))
        }

        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private static func csvEscape(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }

    // MARK: - PDF

    static func pdfData(from items: [Item], rooms: [Room]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = drawHeader(in: pageRect, y: 48, items: items)

            // Group items by room (ungrouped items first)
            var groups: [(title: String, items: [Item])] = []

            let unassigned = items.filter { $0.room == nil }.sorted { $0.name < $1.name }
            if !unassigned.isEmpty { groups.append(("Unassigned", unassigned)) }

            for room in rooms.sorted(by: { $0.name < $1.name }) {
                let roomItems = items.filter { $0.room?.persistentModelID == room.persistentModelID }.sorted { $0.name < $1.name }
                if !roomItems.isEmpty { groups.append((room.name, roomItems)) }
            }

            let margin: CGFloat = 48
            let rowH: CGFloat = 22
            let col = columnLayout(in: pageRect, margin: margin)

            for group in groups {
                // Section header
                y += 16
                if y + 30 > pageRect.height - 48 {
                    ctx.beginPage()
                    y = 48
                }
                drawSectionHeader(group.title, y: y, margin: margin, width: pageRect.width - margin * 2)
                y += 24

                // Table header
                if y + rowH > pageRect.height - 48 {
                    ctx.beginPage()
                    y = 48
                }
                drawTableHeader(col: col, y: y)
                y += rowH

                for item in group.items {
                    if y + rowH > pageRect.height - 48 {
                        ctx.beginPage()
                        y = 48
                        drawTableHeader(col: col, y: y)
                        y += rowH
                    }
                    drawTableRow(item: item, col: col, y: y)
                    y += rowH
                }
            }

            // Totals footer
            let total = items.compactMap { $0.displayValue }.reduce(0, +)
            if total > 0 {
                y += 20
                if y + 24 > pageRect.height - 48 { ctx.beginPage(); y = 48 }
                let totalStr = total.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.label
                ]
                let text = "Total Inventory Value: \(totalStr)" as NSString
                text.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
            }
        }
    }

    // MARK: - PDF Helpers

    private struct ColumnLayout {
        let name: CGFloat
        let category: CGFloat
        let condition: CGFloat
        let value: CGFloat
        let warranty: CGFloat
        let margin: CGFloat
    }

    private static func columnLayout(in pageRect: CGRect, margin: CGFloat) -> ColumnLayout {
        let w = pageRect.width - margin * 2
        return ColumnLayout(
            name: margin,
            category: margin + w * 0.32,
            condition: margin + w * 0.55,
            value: margin + w * 0.70,
            warranty: margin + w * 0.84,
            margin: margin
        )
    }

    @discardableResult
    private static func drawHeader(in pageRect: CGRect, y: CGFloat, items: [Item]) -> CGFloat {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.label
        ]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]
        ("OwnedIt – Inventory Report" as NSString).draw(at: CGPoint(x: 48, y: y), withAttributes: titleAttrs)

        let dateStr = "Generated \(Date().formatted(date: .long, time: .omitted))  ·  \(items.count) items"
        (dateStr as NSString).draw(at: CGPoint(x: 48, y: y + 28), withAttributes: subtitleAttrs)

        // Separator line
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 48, y: y + 48))
        path.addLine(to: CGPoint(x: pageRect.width - 48, y: y + 48))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        return y + 60
    }

    private static func drawSectionHeader(_ title: String, y: CGFloat, margin: CGFloat, width: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
    }

    private static func drawTableHeader(col: ColumnLayout, y: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.secondaryLabel
        ]
        for (text, x) in [("ITEM", col.name), ("CATEGORY", col.category),
                           ("CONDITION", col.condition), ("VALUE", col.value), ("WARRANTY", col.warranty)] {
            (text as NSString).draw(at: CGPoint(x: x, y: y + 3), withAttributes: attrs)
        }
        let path = UIBezierPath()
        path.move(to: CGPoint(x: col.margin, y: y + 18))
        path.addLine(to: CGPoint(x: col.margin + 516, y: y + 18))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private static func drawTableRow(item: Item, col: ColumnLayout, y: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.label
        ]
        let secondaryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]

        var warrantyStr = "—"
        if let exp = item.warrantyExpiration {
            warrantyStr = exp.formatted(.dateTime.month(.abbreviated).year())
        }

        let valueStr = item.displayValue
            .map { $0.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) } ?? "—"

        (truncate(item.name, to: 28) as NSString).draw(at: CGPoint(x: col.name, y: y + 4), withAttributes: attrs)
        ((item.category ?? .other).rawValue as NSString).draw(at: CGPoint(x: col.category, y: y + 4), withAttributes: secondaryAttrs)
        ((item.condition ?? .good).rawValue as NSString).draw(at: CGPoint(x: col.condition, y: y + 4), withAttributes: secondaryAttrs)
        (valueStr as NSString).draw(at: CGPoint(x: col.value, y: y + 4), withAttributes: secondaryAttrs)
        (warrantyStr as NSString).draw(at: CGPoint(x: col.warranty, y: y + 4), withAttributes: secondaryAttrs)
    }

    private static func truncate(_ string: String, to length: Int) -> String {
        guard string.count > length else { return string }
        return String(string.prefix(length - 1)) + "…"
    }

    // MARK: - CSV Import

    static func importItems(from data: Data, into context: ModelContext, existingRooms: [Room]) -> (imported: Int, skipped: Int) {
        guard let text = String(data: data, encoding: .utf8) else { return (0, 0) }

        let rows = parseCSV(text: text)
        guard rows.count > 1 else { return (0, 0) }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        var roomCache = Dictionary(uniqueKeysWithValues: existingRooms.map { ($0.name.lowercased(), $0) })
        var imported = 0
        var skipped = 0

        for row in rows.dropFirst() {
            guard row.count >= 13, !row[0].isEmpty else { skipped += 1; continue }

            let category = ItemCategory(rawValue: row[1]) ?? .other

            var room: Room? = nil
            let roomName = row[2]
            if !roomName.isEmpty {
                if let existing = roomCache[roomName.lowercased()] {
                    room = existing
                } else {
                    let newRoom = Room(name: roomName)
                    context.insert(newRoom)
                    roomCache[roomName.lowercased()] = newRoom
                    room = newRoom
                }
            }

            let item = Item(
                name: row[0],
                category: category,
                room: room,
                make: row[3],
                model: row[4],
                serialNumber: row[5],
                condition: ItemCondition(rawValue: row[6]) ?? .good,
                purchasePrice: Double(row[7]),
                purchaseDate: row[8].isEmpty ? nil : dateFormatter.date(from: row[8]),
                purchaseStore: row[11],
                currentValue: Double(row[9]),
                warrantyExpiration: row[10].isEmpty ? nil : dateFormatter.date(from: row[10]),
                notes: row[12]
            )
            if row.count >= 14, let dateAdded = dateFormatter.date(from: row[13]) {
                item.dateAdded = dateAdded
            }
            context.insert(item)
            imported += 1
        }

        return (imported, skipped)
    }

    private static func parseCSV(text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]
            let next = text.index(after: i)

            if c == "\"" {
                if inQuotes && next < text.endIndex && text[next] == "\"" {
                    field.append("\"")
                    i = text.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                row.append(field)
                field = ""
            } else if c == "\r" && !inQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
                if next < text.endIndex && text[next] == "\n" {
                    i = text.index(after: next)
                    continue
                }
            } else if c == "\n" && !inQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(c)
            }

            i = text.index(after: i)
        }

        if !row.isEmpty || !field.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    // MARK: - Single Item PDF

    static func itemPDFData(from item: Item) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let margin: CGFloat = 48
        let contentWidth: CGFloat = pageRect.width - margin * 2

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // Header
            let h1: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.label]
            let h2: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.label]
            let sub: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.secondaryLabel]

            ("OwnedIt – Item Report" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: h1)
            y += 28
            (truncate(item.name.isEmpty ? "Untitled Item" : item.name, to: 60) as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: h2)
            y += 22
            ("Generated \(Date().formatted(date: .long, time: .omitted))" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: sub)
            y += 18

            let sep = UIBezierPath()
            sep.move(to: CGPoint(x: margin, y: y))
            sep.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            UIColor.separator.setStroke(); sep.lineWidth = 0.5; sep.stroke()
            y += 14

            // First photo
            if let photoData = item.photos?.first?.imageData, let image = UIImage(data: photoData) {
                let maxH: CGFloat = 200
                let scale = min(contentWidth / image.size.width, maxH / image.size.height)
                let imgRect = CGRect(x: margin, y: y, width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: imgRect)
                y += imgRect.height + 16
            }

            // Section drawing helper
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.secondaryLabel]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.label]
            let sectionTitleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 13), .foregroundColor: UIColor.label]

            func drawSection(title: String, rows: [(String, String)]) {
                guard !rows.isEmpty else { return }
                if y + 20 > pageRect.height - margin { ctx.beginPage(); y = margin }
                (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: sectionTitleAttrs)
                y += 20
                for (label, value) in rows {
                    if y + 18 > pageRect.height - margin { ctx.beginPage(); y = margin }
                    (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                    (value as NSString).draw(at: CGPoint(x: margin + 130, y: y), withAttributes: valueAttrs)
                    y += 18
                }
                y += 10
            }

            let df = DateFormatter()
            df.dateStyle = .long; df.timeStyle = .none
            let currency = Locale.current.currency?.identifier ?? "USD"

            var overview: [(String, String)] = [
                ("Category", (item.category ?? .other).rawValue),
                ("Condition", (item.condition ?? .good).rawValue)
            ]
            if let room = item.room { overview.append(("Room", room.name)) }
            if !item.itemDescription.isEmpty { overview.append(("Description", item.itemDescription)) }
            drawSection(title: "Overview", rows: overview)

            var identification: [(String, String)] = []
            if !item.make.isEmpty { identification.append(("Make", item.make)) }
            if !item.model.isEmpty { identification.append(("Model", item.model)) }
            if !item.serialNumber.isEmpty { identification.append(("Serial #", item.serialNumber)) }
            drawSection(title: "Identification", rows: identification)

            var purchase: [(String, String)] = []
            if let price = item.purchasePrice { purchase.append(("Price", price.formatted(.currency(code: currency)))) }
            if let date = item.purchaseDate { purchase.append(("Date", df.string(from: date))) }
            if !item.purchaseStore.isEmpty { purchase.append(("Store", item.purchaseStore)) }
            drawSection(title: "Purchase", rows: purchase)

            if let value = item.currentValue {
                drawSection(title: "Current Value", rows: [("Value", value.formatted(.currency(code: currency)))])
            }

            var warranty: [(String, String)] = []
            if let exp = item.warrantyExpiration { warranty.append(("Expires", df.string(from: exp))) }
            if !item.warrantyProvider.isEmpty { warranty.append(("Provider", item.warrantyProvider)) }
            drawSection(title: "Warranty", rows: warranty)

            if !item.notes.isEmpty {
                drawSection(title: "Notes", rows: [("", item.notes)])
            }
        }
    }
}
