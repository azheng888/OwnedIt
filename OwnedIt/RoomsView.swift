import SwiftUI
import SwiftData

struct RoomsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(filter: #Predicate<Item> { item in item.room == nil }) private var unassignedItems: [Item]

    @State private var showingAddRoom = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        Group {
            if rooms.isEmpty && unassignedItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(rooms.enumerated()), id: \.element.persistentModelID) { index, room in
                            NavigationLink(destination: RoomDetailView(room: room)) {
                                RoomCardView(name: room.name, icon: room.icon, color: room.color,
                                             items: room.items ?? [])
                            }
                            .buttonStyle(.pressable)
                            .appearEffect(index: index)
                        }
                        if !unassignedItems.isEmpty {
                            NavigationLink(destination: UnassignedItemsView()) {
                                RoomCardView(name: "Unassigned", icon: "tray", color: Theme.secondaryText,
                                             items: unassignedItems)
                            }
                            .buttonStyle(.pressable)
                            .appearEffect(index: rooms.count)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    if !remainingSuggestions.isEmpty {
                        suggestionsSection
                            .padding()
                    }
                }
            }
        }
        .themedScreen()
        .navigationTitle("Rooms")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddRoom = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Room")
            }
        }
        .sheet(isPresented: $showingAddRoom) {
            NavigationStack {
                AddEditRoomView()
            }
        }
    }

    private struct RoomSuggestion {
        let name: String
        let icon: String
        let colorName: String
    }

    private let suggestedRooms: [RoomSuggestion] = [
        RoomSuggestion(name: "Living Room", icon: "sofa",               colorName: "blue"),
        RoomSuggestion(name: "Kitchen",     icon: "fork.knife",         colorName: "orange"),
        RoomSuggestion(name: "Bedroom",     icon: "bed.double",         colorName: "purple"),
        RoomSuggestion(name: "Bathroom",    icon: "shower",             colorName: "teal"),
        RoomSuggestion(name: "Office",      icon: "desktopcomputer",    colorName: "blue"),
        RoomSuggestion(name: "Garage",      icon: "door.garage.closed", colorName: "green"),
        RoomSuggestion(name: "Laundry",     icon: "washer",             colorName: "teal"),
        RoomSuggestion(name: "Storage",     icon: "shippingbox",        colorName: "yellow"),
    ]

    private var remainingSuggestions: [RoomSuggestion] {
        let existing = Set(rooms.map { $0.name.lowercased() })
        return suggestedRooms.filter { !existing.contains($0.name.lowercased()) }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick add").font(.subheadline).foregroundStyle(Theme.secondaryText)
            FlowLayout(spacing: 8) {
                ForEach(remainingSuggestions, id: \.name) { suggestion in
                    Button {
                        withAnimation(Motion.snappy) {
                            modelContext.insert(Room(name: suggestion.name, icon: suggestion.icon,
                                                     colorName: suggestion.colorName))
                        }
                    } label: {
                        Label(suggestion.name, systemImage: suggestion.icon)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(Theme.ink)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.hairline))
                    }
                    .buttonStyle(.pressable)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ContentUnavailableView {
                Label("No Rooms Yet", systemImage: "house")
            } description: {
                Text("Group your things by where they live.")
            } actions: {
                Button("Add Room") { showingAddRoom = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.ink)
            }
            .frame(maxHeight: 320)
            suggestionsSection
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Unassigned Items View

struct UnassignedItemsView: View {
    @Query(filter: #Predicate<Item> { item in item.room == nil }, sort: \Item.name)
    private var items: [Item]

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ItemRowView(item: item)
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedList()
        .navigationTitle("Unassigned")
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("Everything Has a Place", systemImage: "checkmark.circle")
            }
        }
    }
}

// MARK: - Room Card

struct RoomCardView: View {
    let name: String
    let icon: String
    let color: Color
    let items: [Item]

    private var totalValue: Double { items.compactMap(\.displayValue).reduce(0, +) }
    private var previewItems: [Item] {
        Array(items.filter(\.hasPhotos)
            .sorted { ($0.displayValue ?? 0) > ($1.displayValue ?? 0) }
            .prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                IconTile(systemName: icon, size: 40)
                Spacer()
                Text("\(items.count)")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(items.count)))
            }

            Spacer(minLength: 0)

            // Overlapping photo stack of the room's most valuable items.
            if !previewItems.isEmpty {
                HStack(spacing: -10) {
                    ForEach(previewItems) { item in
                        ItemThumbnailView(item: item, size: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30 * 0.23)
                                    .strokeBorder(Theme.surface, lineWidth: 2)
                            )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(totalValue > 0 ? totalValue.wholeCurrencyString : items.count.pluralized("item"))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(minHeight: 150, alignment: .topLeading)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(items.count.pluralized("item"))\(totalValue > 0 ? ", \(totalValue.wholeCurrencyString)" : "")")
    }
}

// MARK: - Flow layout

/// Wraps children onto multiple lines (used for chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
