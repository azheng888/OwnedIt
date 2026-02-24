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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Room Card

struct RoomCardView: View {
    let room: Room

    private var totalValue: Double {
        room.items.compactMap { $0.displayValue }.reduce(0, +)
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
                Text("\(room.items.count)")
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
                Text(room.items.count == 1 ? "1 item" : "\(room.items.count) items")
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
