import SwiftUI

struct ItemRowView: View {
    let item: Item
    /// Hide the room when the list is already grouped by room.
    var showsRoom: Bool = true

    private var meta: String {
        var parts: [String] = []
        parts.append(item.make.isEmpty ? (item.category ?? .other).rawValue : item.make)
        if showsRoom, let room = item.room { parts.append(room.name) }
        if item.quantity > 1 { parts.append("×\(item.quantity)") }
        if let condition = item.condition { parts.append(condition.rawValue) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            ItemThumbnailView(item: item, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(.footnote)
                    .foregroundStyle(item.condition == .poor ? Theme.critical : Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let value = item.displayValue {
                Text(value, format: AppFormat.currency(for: value))
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
