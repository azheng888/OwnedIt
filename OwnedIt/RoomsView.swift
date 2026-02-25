import SwiftUI
import SwiftData

struct RoomsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var showingAddRoom = false

    let columns = [GridItem(.adaptive(minimum: 155), spacing: 16)]

    var body: some View {
        Group {
            if rooms.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(rooms) { room in
                            NavigationLink(destination: RoomDetailView(room: room)) {
                                RoomCardView(room: room)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()

                    if !remainingSuggestions.isEmpty {
                        suggestionsSection
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
        }
        .navigationTitle("Rooms")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddRoom = true }) {
                    Image(systemName: "plus")
                }
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
        RoomSuggestion(name: "Living Room", icon: "sofa",         colorName: "blue"),
        RoomSuggestion(name: "Kitchen",     icon: "fork.knife",   colorName: "orange"),
        RoomSuggestion(name: "Bedroom",     icon: "bed.double",   colorName: "purple"),
        RoomSuggestion(name: "Bathroom",    icon: "shower",       colorName: "teal"),
        RoomSuggestion(name: "Garage",      icon: "car.fill",     colorName: "green"),
        RoomSuggestion(name: "Office",      icon: "building.2",   colorName: "blue"),
        RoomSuggestion(name: "Laundry",     icon: "washer",       colorName: "teal"),
        RoomSuggestion(name: "Storage",     icon: "shippingbox",  colorName: "yellow"),
    ]

    private var remainingSuggestions: [RoomSuggestion] {
        let existingNames = Set(rooms.map { $0.name })
        return suggestedRooms.filter { !existingNames.contains($0.name) }
    }

    private func addSuggestion(_ suggestion: RoomSuggestion) {
        let room = Room(name: suggestion.name, icon: suggestion.icon, colorName: suggestion.colorName)
        modelContext.insert(room)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Common rooms")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(remainingSuggestions, id: \.name) { suggestion in
                        Button {
                            addSuggestion(suggestion)
                        } label: {
                            Label(suggestion.name, systemImage: suggestion.icon)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "house")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No Rooms Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Organize your items by adding rooms")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Add Room") {
                showingAddRoom = true
            }
            .buttonStyle(.borderedProminent)

            suggestionsSection
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Room Card

struct RoomCardView: View {
    let room: Room
    @Query private var roomItems: [Item]

    init(room: Room) {
        self.room = room
        let roomID = room.persistentModelID
        _roomItems = Query(filter: #Predicate<Item> { item in
            item.room?.persistentModelID == roomID
        })
    }

    private var totalValue: Double {
        roomItems.compactMap { $0.displayValue }.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(room.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: room.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(room.color)
                }
                Spacer()
                Text("\(roomItems.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(room.color)
            }

            Text(room.name)
                .font(.headline)
                .lineLimit(1)

            if totalValue > 0 {
                Text(totalValue, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(roomItems.count == 1 ? "1 item" : "\(roomItems.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
