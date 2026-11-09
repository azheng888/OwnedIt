import UIKit
import SwiftData

enum ExportManager {

    // MARK: - CSV

    /// Column order for export. Import matches by header name, so order changes stay compatible.
    private enum Column: String, CaseIterable {
        case name = "Name"
        case category = "Category"
        case room = "Room"
        case make = "Make"
        case model = "Model"
        case serial = "Serial Number"
        case condition = "Condition"
        case purchasePrice = "Purchase Price"
        case purchaseDate = "Purchase Date"
        case currentValue = "Current Value"
        case warrantyExpires = "Warranty Expires"
        case store = "Store"
        case notes = "Notes"
        case dateAdded = "Date Added"
        case quantity = "Quantity"
        case description = "Description"
        case warrantyProvider = "Warranty Provider"
    }

    /// ISO dates so files round-trip across devices with different locales.
    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Older builds exported locale "short" dates; still accept them on import.
    private static let legacyDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    static func csvData(from items: [Item]) -> Data {
        var rows = [Column.allCases.map(\.rawValue).joined(separator: ",")]

        for item in items.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let fields: [String] = Column.allCases.map { column in
                switch column {
                case .name: return csvEscape(item.name)
                case .category: return csvEscape((item.category ?? .other).rawValue)
                case .room: return csvEscape(item.room?.name ?? "")
                case .make: return csvEscape(item.make)
                case .model: return csvEscape(item.model)
                case .serial: return csvEscape(item.serialNumber)
                case .condition: return csvEscape(item.condition?.rawValue ?? "")
                case .purchasePrice: return item.purchasePrice.map { String(format: "%.2f", $0) } ?? ""
                case .purchaseDate: return item.purchaseDate.map(isoDate.string(from:)) ?? ""
                case .currentValue: return item.currentValue.map { String(format: "%.2f", $0) } ?? ""
                case .warrantyExpires: return item.warrantyExpiration.map(isoDate.string(from:)) ?? ""
                case .store: return csvEscape(item.purchaseStore)
                case .notes: return csvEscape(item.notes)
                case .dateAdded: return item.dateAdded.map(isoDate.string(from:)) ?? ""
                case .quantity: return String(item.quantity)
                case .description: return csvEscape(item.itemDescription)
                case .warrantyProvider: return csvEscape(item.warrantyProvider)
                }
            }
            rows.append(fields.joined(separator: ","))
        }

        // BOM so Excel opens UTF-8 (accents, emoji) correctly.
        return Data([0xEF, 0xBB, 0xBF]) + (rows.joined(separator: "\r\n").data(using: .utf8) ?? Data())
    }

    private static func csvEscape(_ string: String) -> String {
        var value = string
        // Neutralize spreadsheet formula injection (=, +, -, @ at the start of a cell).
        if let first = value.first, "=+-@".contains(first) {
            value = "'" + value
        }
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - CSV Import

    struct ImportResult {
        var imported = 0
        var skipped = 0
        var roomsCreated = 0
    }

    static func importItems(from data: Data, into context: ModelContext, existingRooms: [Room]) -> ImportResult {
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return ImportResult()
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        let rows = parseCSV(text: text)
        guard let header = rows.first, rows.count > 1 else { return ImportResult() }

        // Map header names to indices (case-insensitive). Fall back to the legacy fixed order.
        let normalized = header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var index: [Column: Int] = [:]
        for column in Column.allCases {
            if let i = normalized.firstIndex(of: column.rawValue.lowercased()) { index[column] = i }
        }
        if index[.name] == nil {
            for (i, column) in Column.allCases.enumerated() where i < header.count { index[column] = i }
        }

        var roomCache = Dictionary(existingRooms.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        var result = ImportResult()

        for row in rows.dropFirst() {
            func value(_ column: Column) -> String {
                guard let i = index[column], i < row.count else { return "" }
                var v = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if v.hasPrefix("'"), let second = v.dropFirst().first, "=+-@".contains(second) { v.removeFirst() }
                return v
            }

            let name = value(.name)
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            guard !name.isEmpty else { result.skipped += 1; continue }

            var room: Room?
            let roomName = value(.room)
            if !roomName.isEmpty {
                if let existing = roomCache[roomName.lowercased()] {
                    room = existing
                } else {
                    let newRoom = Room(name: roomName)
                    context.insert(newRoom)
                    roomCache[roomName.lowercased()] = newRoom
                    room = newRoom
                    result.roomsCreated += 1
                }
            }

            let item = Item(
                name: name,
                itemDescription: value(.description),
                quantity: max(1, Int(value(.quantity)) ?? 1),
                category: ItemCategory.allCases.first { $0.rawValue.lowercased() == value(.category).lowercased() } ?? .other,
                room: room,
                make: value(.make),
                model: value(.model),
                serialNumber: value(.serial),
                condition: ItemCondition.allCases.first { $0.rawValue.lowercased() == value(.condition).lowercased() },
                purchasePrice: parseNumber(value(.purchasePrice)),
                purchaseDate: parseDate(value(.purchaseDate)),
                purchaseStore: value(.store),
                currentValue: parseNumber(value(.currentValue)),
                warrantyExpiration: parseDate(value(.warrantyExpires)),
                warrantyProvider: value(.warrantyProvider),
                notes: value(.notes)
            )
            if let added = parseDate(value(.dateAdded)) {
                item.dateAdded = added
            }
            context.insert(item)
            result.imported += 1
        }

        return result
    }

    /// Accepts "1299", "1,299.00", "$1,299.00", "1299.5 USD".
    static func parseNumber(_ raw: String) -> Double? {
        let cleaned = raw.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    static func parseDate(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }
        return isoDate.date(from: raw) ?? legacyDate.date(from: raw)
    }

    static func parseCSV(text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text).makeIterator()
        var pending: Character? = nil

        func nextChar() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let c = nextChar() {
            if inQuotes {
                if c == "\"" {
                    if let n = nextChar() {
                        if n == "\"" { field.append("\"") } else { inQuotes = false; pending = n }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\r\n", "\n", "\r":
                    row.append(field); rows.append(row); row = []; field = ""
                default: field.append(c)
                }
            }
        }

        if !row.isEmpty || !field.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    // MARK: - PDF (shared drawing)

    /// PDFs are always light: never use dynamic colors (UIColor.label is white in Dark Mode).
    private enum Ink {
        static let primary = UIColor(white: 0.08, alpha: 1)
        static let secondary = UIColor(white: 0.42, alpha: 1)
        static let rule = UIColor(white: 0.85, alpha: 1)
        static let accent = UIColor(red: 0x1F / 255, green: 0x6E / 255, blue: 0x52 / 255, alpha: 1)
    }

    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
    private static let margin: CGFloat = 48

    private static func serif(_ size: CGFloat, bold: Bool = true) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        return UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
    }

    private static func attrs(_ font: UIFont, _ color: UIColor, align: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byTruncatingTail
        return [.font: font, .foregroundColor: color, .paragraphStyle: style]
    }

    private static func rule(at y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        Ink.rule.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private static func drawFooter(page: Int) {
        let text = "OwnedIt · Page \(page)" as NSString
        text.draw(in: CGRect(x: margin, y: pageRect.height - 32, width: pageRect.width - margin * 2, height: 12),
                  withAttributes: attrs(.systemFont(ofSize: 8), Ink.secondary, align: .center))
    }

    // MARK: - Inventory PDF

    static func pdfData(from items: [Item], rooms: [Room]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let rowH: CGFloat = 22
        let bottom = pageRect.height - 52
        let width = pageRect.width - margin * 2
        let cols: [(title: String, x: CGFloat, w: CGFloat, align: NSTextAlignment)] = [
            ("ITEM", margin, width * 0.36, .left),
            ("CATEGORY", margin + width * 0.37, width * 0.17, .left),
            ("CONDITION", margin + width * 0.55, width * 0.12, .left),
            ("WARRANTY", margin + width * 0.68, width * 0.14, .left),
            ("VALUE", margin + width * 0.82, width * 0.18, .right),
        ]

        return renderer.pdfData { ctx in
            var page = 0
            var y: CGFloat = 0

            func newPage() {
                if page > 0 { drawFooter(page: page) }
                ctx.beginPage()
                page += 1
                y = margin
            }

            func drawTableHeader() {
                for col in cols {
                    (col.title as NSString).draw(in: CGRect(x: col.x, y: y + 4, width: col.w, height: 12),
                                                 withAttributes: attrs(.systemFont(ofSize: 8, weight: .semibold), Ink.secondary, align: col.align))
                }
                rule(at: y + rowH - 2)
                y += rowH
            }

            newPage()

            // Title block
            ("Home Inventory" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(serif(24), Ink.primary))
            y += 32
            let total = items.compactMap(\.displayValue).reduce(0, +)
            let units = items.reduce(0) { $0 + $1.quantity }
            let subtitle = "Generated \(Date().formatted(date: .long, time: .omitted)) · \(units.pluralized("item"))"
            (subtitle as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(.systemFont(ofSize: 10), Ink.secondary))
            if total > 0 {
                let totalStr = "Total value  \(total.wholeCurrencyString)" as NSString
                totalStr.draw(in: CGRect(x: margin, y: y - 2, width: width, height: 16),
                              withAttributes: attrs(serif(13), Ink.accent, align: .right))
            }
            y += 22
            rule(at: y)
            y += 12

            var groups: [(title: String, items: [Item])] = []
            for room in rooms.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
                let roomItems = items.filter { $0.room?.persistentModelID == room.persistentModelID }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                if !roomItems.isEmpty { groups.append((room.name, roomItems)) }
            }
            let unassigned = items.filter { $0.room == nil }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            if !unassigned.isEmpty { groups.append(("Unassigned", unassigned)) }

            for group in groups {
                if y + 60 > bottom { newPage() }
                y += 10
                let groupTotal = group.items.compactMap(\.displayValue).reduce(0, +)
                (group.title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(serif(14), Ink.primary))
                if groupTotal > 0 {
                    (groupTotal.wholeCurrencyString as NSString).draw(in: CGRect(x: margin, y: y + 2, width: width, height: 14),
                                                                 withAttributes: attrs(.systemFont(ofSize: 10, weight: .medium), Ink.secondary, align: .right))
                }
                y += 22
                drawTableHeader()

                for item in group.items {
                    if y + rowH > bottom {
                        newPage()
                        drawTableHeader()
                    }
                    let name = item.quantity > 1 ? "\(item.displayName) (×\(item.quantity))" : item.displayName
                    let values = [
                        name,
                        (item.category ?? .other).rawValue,
                        item.condition?.rawValue ?? "—",
                        item.warrantyExpiration.map { $0.formatted(.dateTime.month(.abbreviated).year()) } ?? "—",
                        item.displayValue.map(\.currencyString) ?? "—",
                    ]
                    for (col, text) in zip(cols, values) {
                        let isName = col.title == "ITEM"
                        (text as NSString).draw(in: CGRect(x: col.x, y: y + 4, width: col.w, height: 14),
                                                withAttributes: attrs(.systemFont(ofSize: 9.5), isName ? Ink.primary : Ink.secondary, align: col.align))
                    }
                    y += rowH
                }
            }

            drawFooter(page: page)
        }
    }

    // MARK: - Single Item PDF

    static func itemPDFData(from item: Item) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let contentWidth = pageRect.width - margin * 2
        let bottom = pageRect.height - 52
        let labelWidth: CGFloat = 120

        return renderer.pdfData { ctx in
            var page = 0
            var y: CGFloat = 0
            func newPage() {
                if page > 0 { drawFooter(page: page) }
                ctx.beginPage()
                page += 1
                y = margin
            }
            newPage()

            ("Item Record" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(.systemFont(ofSize: 10, weight: .semibold), Ink.accent))
            y += 16
            let title = item.displayName as NSString
            let titleAttrs = attrs(serif(22), Ink.primary)
            let titleHeight = title.boundingRect(with: CGSize(width: contentWidth, height: 80), options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil).height
            title.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: ceil(titleHeight)), withAttributes: titleAttrs)
            y += ceil(titleHeight) + 4
            ("Generated \(Date().formatted(date: .long, time: .omitted))" as NSString)
                .draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(.systemFont(ofSize: 10), Ink.secondary))
            y += 20
            rule(at: y)
            y += 14

            // Photos: up to three, side by side.
            let images = item.sortedPhotos.prefix(3).compactMap { $0.imageData.flatMap(UIImage.init(data:)) }
            if !images.isEmpty {
                let gap: CGFloat = 8
                let cell = (contentWidth - gap * CGFloat(images.count - 1)) / CGFloat(images.count)
                let height = min(cell, 200)
                for (i, image) in images.enumerated() {
                    let rect = CGRect(x: margin + CGFloat(i) * (cell + gap), y: y, width: cell, height: height)
                    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
                    let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let drawRect = CGRect(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2,
                                          width: drawSize.width, height: drawSize.height)
                    ctx.cgContext.saveGState()
                    UIBezierPath(roundedRect: rect, cornerRadius: 6).addClip()
                    image.draw(in: drawRect)
                    ctx.cgContext.restoreGState()
                }
                y += height + 18
            }

            let labelAttrs = attrs(.systemFont(ofSize: 10), Ink.secondary)
            let valueStyle = NSMutableParagraphStyle()
            valueStyle.lineBreakMode = .byWordWrapping
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10.5), .foregroundColor: Ink.primary, .paragraphStyle: valueStyle]

            func drawSection(_ title: String, _ rows: [(String, String)]) {
                guard !rows.isEmpty else { return }
                if y + 40 > bottom { newPage() }
                (title.uppercased() as NSString).draw(at: CGPoint(x: margin, y: y),
                                                      withAttributes: attrs(.systemFont(ofSize: 8.5, weight: .semibold), Ink.secondary))
                y += 14
                rule(at: y)
                y += 6
                for (label, value) in rows {
                    let valueWidth = label.isEmpty ? contentWidth : contentWidth - labelWidth
                    let text = value as NSString
                    let height = ceil(text.boundingRect(with: CGSize(width: valueWidth, height: .greatestFiniteMagnitude),
                                                        options: .usesLineFragmentOrigin, attributes: valueAttrs, context: nil).height)
                    if y + min(height, 200) > bottom { newPage() }
                    if !label.isEmpty {
                        (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                    }
                    let x = label.isEmpty ? margin : margin + labelWidth
                    // Long values (notes) can exceed a page; draw what fits and continue on the next.
                    var remaining = value
                    while !remaining.isEmpty {
                        let available = bottom - y
                        let fitted = fit(remaining, width: valueWidth, height: available, attributes: valueAttrs)
                        (fitted as NSString).draw(with: CGRect(x: x, y: y, width: valueWidth, height: available),
                                                  options: .usesLineFragmentOrigin, attributes: valueAttrs, context: nil)
                        let used = ceil((fitted as NSString).boundingRect(with: CGSize(width: valueWidth, height: .greatestFiniteMagnitude),
                                                                          options: .usesLineFragmentOrigin, attributes: valueAttrs, context: nil).height)
                        remaining = String(remaining.dropFirst(fitted.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        y += used + 6
                        if !remaining.isEmpty { newPage() }
                    }
                }
                y += 12
            }

            var overview: [(String, String)] = [("Category", (item.category ?? .other).rawValue)]
            if let condition = item.condition { overview.append(("Condition", condition.rawValue)) }
            if item.quantity > 1 { overview.append(("Quantity", "\(item.quantity)")) }
            if let room = item.room { overview.append(("Room", room.name)) }
            if !item.itemDescription.isEmpty { overview.append(("Description", item.itemDescription)) }
            drawSection("Overview", overview)

            var identification: [(String, String)] = []
            if !item.make.isEmpty { identification.append(("Make", item.make)) }
            if !item.model.isEmpty { identification.append(("Model", item.model)) }
            if !item.serialNumber.isEmpty { identification.append(("Serial number", item.serialNumber)) }
            drawSection("Identification", identification)

            var value: [(String, String)] = []
            if let price = item.purchasePrice {
                value.append((item.quantity > 1 ? "Price (each)" : "Purchase price", price.currencyString))
            }
            if let date = item.purchaseDate { value.append(("Purchased", date.formatted(date: .long, time: .omitted))) }
            if !item.purchaseStore.isEmpty { value.append(("Store", item.purchaseStore)) }
            if let current = item.currentValue {
                value.append((item.quantity > 1 ? "Value (each)" : "Current value", current.currencyString))
            }
            if item.quantity > 1, let total = item.displayValue { value.append(("Total value", total.wholeCurrencyString)) }
            drawSection("Purchase & Value", value)

            var warranty: [(String, String)] = []
            if let exp = item.warrantyExpiration { warranty.append(("Expires", exp.formatted(date: .long, time: .omitted))) }
            if !item.warrantyProvider.isEmpty { warranty.append(("Provider", item.warrantyProvider)) }
            drawSection("Warranty", warranty)

            let documents = (item.receipts ?? []).map(\.displayName)
            if !documents.isEmpty {
                drawSection("Attached Documents", documents.map { ("", "• \($0)") })
            }

            if !item.notes.isEmpty {
                drawSection("Notes", [("", item.notes)])
            }

            drawFooter(page: page)
        }
    }

    /// Longest prefix of `text` (broken at a word boundary) that fits in the given box.
    private static func fit(_ text: String, width: CGFloat, height: CGFloat, attributes: [NSAttributedString.Key: Any]) -> String {
        func h(_ s: String) -> CGFloat {
            (s as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                         options: .usesLineFragmentOrigin, attributes: attributes, context: nil).height
        }
        if h(text) <= height { return text }
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        var low = 0, high = words.count
        while low < high {
            let mid = (low + high + 1) / 2
            if h(words[0..<mid].joined(separator: " ")) <= height { low = mid } else { high = mid - 1 }
        }
        return low == 0 ? String(text.prefix(1)) : words[0..<low].joined(separator: " ")
    }
}
