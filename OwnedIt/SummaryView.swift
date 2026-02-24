import SwiftUI
import SwiftData

struct SummaryView: View {
    @Query private var items: [Item]
    @Query(sort: \Room.name) private var rooms: [Room]

    private var totalValue: Double {
        items.compactMap { $0.displayValue }.reduce(0, +)
    }

    private var itemsByCategory: [(category: ItemCategory, count: Int, value: Double)] {
        ItemCategory.allCases.compactMap { category in
            let matches = items.filter { $0.category == category }
            guard !matches.isEmpty else { return nil }
            let value = matches.compactMap { $0.displayValue }.reduce(0, +)
            return (category, matches.count, value)
        }
        .sorted { $0.count > $1.count }
    }

    private var roomsWithItems: [(room: Room, count: Int, value: Double)] {
        rooms.compactMap { room in
            guard !room.items.isEmpty else { return nil }
            let value = room.items.compactMap { $0.displayValue }.reduce(0, +)
            return (room, room.items.count, value)
        }
        .sorted { $0.count > $1.count }
    }

    private var recentItems: [Item] {
        Array(items.sorted { $0.dateAdded > $1.dateAdded }.prefix(5))
    }

    private var warrantiesExpiringSoon: [Item] {
        guard let threshold = Calendar.current.date(byAdding: .month, value: 3, to: Date()) else {
            return []
        }
        return items
            .filter {
                if let exp = $0.warrantyExpiration {
                    return exp > Date() && exp <= threshold
                }
                return false
            }
            .sorted { $0.warrantyExpiration! < $1.warrantyExpiration! }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        overviewCards
                        warrantyAlertsSection
                        categoryBreakdown
                        roomBreakdown
                        recentSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Summary")
    }

    // MARK: - Sections

    private var overviewCards: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Items",
                value: "\(items.count)",
                icon: "archivebox.fill",
                color: .blue
            )
            StatCard(
                title: "Total Value",
                value: totalValue > 0
                    ? totalValue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                    : "—",
                icon: "dollarsign.circle.fill",
                color: .green
            )
        }
    }

    @ViewBuilder
    private var warrantyAlertsSection: some View {
        if !warrantiesExpiringSoon.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Warranties Expiring Soon", systemImage: "exclamationmark.shield.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(warrantiesExpiringSoon) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        HStack {
                            Image(systemName: item.category.icon)
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            Text(item.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let exp = item.warrantyExpiration {
                                Text(exp, format: .dateTime.month(.abbreviated).day().year())
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var categoryBreakdown: some View {
        if !itemsByCategory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("By Category")
                    .font(.headline)

                ForEach(itemsByCategory, id: \.category) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.category.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        Text(entry.category.rawValue)
                        Spacer()
                        Text("\(entry.count)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .frame(width: 28, alignment: .trailing)
                        if entry.value > 0 {
                            Text(entry.value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 90, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var roomBreakdown: some View {
        if !roomsWithItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("By Room")
                    .font(.headline)

                ForEach(roomsWithItems, id: \.room.id) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.room.icon)
                            .foregroundStyle(entry.room.color)
                            .frame(width: 24)
                        Text(entry.room.name)
                        Spacer()
                        Text("\(entry.count)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .frame(width: 28, alignment: .trailing)
                        if entry.value > 0 {
                            Text(entry.value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 90, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !recentItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recently Added")
                    .font(.headline)

                ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        ItemRowView(item: item)
                    }
                    .buttonStyle(.plain)

                    if index < recentItems.count - 1 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Data Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add items to see your inventory summary")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
