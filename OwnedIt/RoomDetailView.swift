import SwiftUI
import SwiftData

struct RoomDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let room: Room

    @State private var showingEditRoom = false
    @State private var showingAddItem = false
    @State private var showingDeleteConfirmation = false

    private var sortedItems: [Item] {
        (room.items ?? []).sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
    }

    private var totalValue: Double {
        (room.items ?? []).compactMap { $0.displayValue }.reduce(0, +)
    }

    var body: some View {
        Group {
            if (room.items ?? []).isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(sortedItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRowView(item: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                    Button(action: { showingEditRoom = true }) {
                        Label("Edit Room", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Room", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !(room.items ?? []).isEmpty && totalValue > 0 {
                HStack {
                    Text("\((room.items ?? []).count) items")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Total: \(totalValue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .sheet(isPresented: $showingEditRoom) {
            NavigationStack {
                AddEditRoomView(room: room)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                AddEditItemView(preselectedRoom: room)
            }
        }
        .confirmationDialog("Delete \"\(room.name)\"?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Room", role: .destructive) {
                modelContext.delete(room)
                dismiss()
            }
        } message: {
            Text("Items in this room will not be deleted, but will be unassigned from the room.")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: room.icon)
                .font(.system(size: 64))
                .foregroundStyle(room.color.opacity(0.5))
            Text("No Items in \(room.name)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Button("Add Item") {
                showingAddItem = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedItems[index])
        }
    }
}
