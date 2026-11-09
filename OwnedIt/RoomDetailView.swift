import SwiftUI
import SwiftData

struct RoomDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let room: Room

    @State private var showingEditRoom = false
    @State private var showingAddItem = false
    @State private var showingDeleteConfirmation = false
    @State private var undoMementos: [DeletedItemMemento] = []

    private var sortedItems: [Item] {
        (room.items ?? []).sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
    }

    var body: some View {
        if room.isDeleted || room.modelContext == nil {
            ContentUnavailableView("Room Deleted", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        let items = sortedItems
        return List {
            Section {
                header
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if items.isEmpty {
                Section {
                    Button { showingAddItem = true } label: {
                        Label("Add the first item to \(room.name)", systemImage: "plus.circle.fill")
                    }
                }
            } else {
                Section {
                    ForEach(items) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRowView(item: item)
                        }
                    }
                    .onDelete { offsets in
                        undoMementos = ItemActions.delete(offsets.map { items[$0] }, in: modelContext)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedList()
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Item")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
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
                .accessibilityLabel("More")
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
        .undoDeleteToast($undoMementos)
        .confirmationDialog("Delete \"\(room.name)\"?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Room", role: .destructive) {
                dismiss()
                modelContext.delete(room)
            }
        } message: {
            Text("Items in this room won't be deleted — they'll move to Unassigned.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(systemName: room.icon, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(room.totalValue, format: AppFormat.wholeCurrency)
                    .font(.hero(28))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: room.totalValue))
                    .animation(Motion.snappy, value: room.totalValue)
                Text(room.itemCount.pluralized("item"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
