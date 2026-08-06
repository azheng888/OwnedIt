import SwiftUI

struct ItemRowView: View {
    let item: Item

    private var category: ItemCategory { item.category ?? .other }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name.isEmpty ? "Unnamed Item" : item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let room = item.room {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(room.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let value = item.displayValue {
                    Text(value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                if let condition = item.condition {
                    Text(condition.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(condition.color.opacity(0.15))
                        .foregroundStyle(condition.color)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
