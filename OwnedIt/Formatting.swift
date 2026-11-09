import Foundation

/// Central place for app-wide formatting so the currency code and date styles stay consistent.
enum AppFormat {
    static var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    /// Shows cents only when there are any: $1,899 but $19.99.
    static func currency(for value: Double) -> FloatingPointFormatStyle<Double>.Currency {
        let hasCents = (value * 100).rounded() / 100 != value.rounded()
        return .currency(code: currencyCode).precision(.fractionLength(hasCents ? 2 : 0))
    }

    /// Totals and aggregates: always whole units.
    static var wholeCurrency: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: currencyCode).precision(.fractionLength(0))
    }

    /// "Mar 6" for this year, "Mar 6, 2025" otherwise.
    static func shortDate(_ date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

extension Double {
    /// Price-style: cents only when present.
    var currencyString: String { formatted(AppFormat.currency(for: self)) }
    /// Total-style: whole units.
    var wholeCurrencyString: String { formatted(AppFormat.wholeCurrency) }
}

extension Int {
    /// "1 item" / "3 items"
    func pluralized(_ singular: String, _ plural: String? = nil) -> String {
        "\(self) \(self == 1 ? singular : (plural ?? singular + "s"))"
    }
}

enum TempFile {
    /// Writes data to a uniquely-named temp file with a filesystem-safe name and returns its URL.
    static func write(_ data: Data, preferredName: String, ext: String) -> URL? {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        var base = preferredName.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        if base.isEmpty { base = "OwnedIt" }
        base = String(base.prefix(80))

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent(base).appendingPathExtension(ext)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
