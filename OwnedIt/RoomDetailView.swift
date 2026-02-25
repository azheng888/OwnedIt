import SwiftUI
import SwiftData

struct RoomDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let room: Room

    @State private var showingEditRoom = false
    @State private var showingAddItem = false
    @State private var showingDeleteConfirmation = false
    @State private var undoMemento: DeletedItemMemento?
    @State private var undoTask: Task<Void, Never>?

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
        .overlay(alignment: .bottom) {
            if let memento = undoMemento {
                HStack {
                    Text("Deleted \"\(memento.name)\"")
                    Spacer()
                    Button("Undo") {
                        undoTask?.cancel()
                        restoreItem(from: memento, in: modelContext)
                        undoMemento = nil
                    }
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring, value: undoMemento != nil)
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
        undoTask?.cancel()
        let toDelete = offsets.map { sortedItems[$0] }
        undoMemento = toDelete.count == 1 ? DeletedItemMemento(from: toDelete[0]) : nil
        for item in toDelete { modelContext.delete(item) }
        if undoMemento != nil {
            undoTask = Task {
                try? await Task.sleep(for: .seconds(4))
                if !Task.isCancelled {
                    await MainActor.run { undoMemento = nil }
                }
            }
        }
    }
}
