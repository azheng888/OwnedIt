import SwiftUI
import SwiftData

struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory?
    @State private var selectedRoom: Room?
    @State private var sortOrder: SortOrder = .dateAdded
    @State private var showingAddItem = false

    // Bulk select
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var showingMoveSheet = false

    // Undo toast
    @State private var undoMementos: [DeletedItemMemento] = []
    @State private var undoTask: Task<Void, Never>?

    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case name = "Name"
        case value = "Value"
        case condition = "Condition"
        case room = "Room"
    }

    var filteredItems: [Item] {
        var result = items

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.make.localizedCaseInsensitiveContains(searchText) ||
                $0.model.localizedCaseInsensitiveContains(searchText) ||
                $0.serialNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.itemDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if let room = selectedRoom {
            result = result.filter { $0.room?.persistentModelID == room.persistentModelID }
        }

        switch sortOrder {
        case .dateAdded:
            result.sort { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .value:
            result.sort { ($0.displayValue ?? 0) > ($1.displayValue ?? 0) }
        case .condition:
            result.sort { ($0.condition?.rawValue ?? "") < ($1.condition?.rawValue ?? "") }
        case .room:
            result.sort {
                let lhs = $0.room?.name ?? ""
                let rhs = $1.room?.name ?? ""
                if lhs.isEmpty && rhs.isEmpty { return false }
                if lhs.isEmpty { return false }
                if rhs.isEmpty { return true }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        }

        return result
    }

    var activeFilterCount: Int {
        (selectedCategory != nil ? 1 : 0) + (selectedRoom != nil ? 1 : 0)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredItems) { item in
                        if isSelectMode {
                            Button {
                                if selectedIDs.contains(item.persistentModelID) {
                                    selectedIDs.remove(item.persistentModelID)
                                } else {
                                    selectedIDs.insert(item.persistentModelID)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedIDs.contains(item.persistentModelID)
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .foregroundStyle(selectedIDs.contains(item.persistentModelID)
                                                         ? Color.accentColor : Color.secondary)
                                        .font(.title3)
                                    ItemRowView(item: item)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                ItemRowView(item: item)
                            }
                        }
                    }
                    .onDelete(perform: isSelectMode ? nil : deleteItems)
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if filteredItems.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if isSelectMode && !selectedIDs.isEmpty {
                        HStack(spacing: 16) {
                            Button(role: .destructive) {
                                bulkDelete()
                            } label: {
                                Text("Delete \(selectedIDs.count) Item\(selectedIDs.count == 1 ? "" : "s")")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)

                            Button {
                                showingMoveSheet = true
                            } label: {
                                Text("Move to Room…")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.bar)
                    }
                }
            }
        }
        .navigationTitle("Items")
        .searchable(text: $searchText, prompt: "Search items…")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isSelectMode {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if isSelectMode {
                    Button("Cancel") {
                        isSelectMode = false
                        selectedIDs.removeAll()
                    }
                } else {
                    filterMenu
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !items.isEmpty && !isSelectMode {
                    Button("Select") {
                        isSelectMode = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                AddEditItemView()
            }
        }
        .sheet(isPresented: $showingMoveSheet) {
            moveToRoomSheet
        }
        .overlay(alignment: .bottom) {
            if !undoMementos.isEmpty {
                HStack {
                    Text(undoMementos.count == 1
                         ? "Deleted \"\(undoMementos[0].name)\""
                         : "Deleted \(undoMementos.count) items")
                    Spacer()
                    Button("Undo") {
                        undoTask?.cancel()
                        for memento in undoMementos {
                            restoreItem(from: memento, in: modelContext)
                        }
                        undoMementos = []
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
        .animation(.spring, value: undoMementos.isEmpty)
        .onChange(of: searchText) { _, _ in
            if isSelectMode { isSelectMode = false; selectedIDs.removeAll() }
        }
        .onChange(of: selectedCategory) { _, _ in
            if isSelectMode { isSelectMode = false; selectedIDs.removeAll() }
        }
        .onChange(of: selectedRoom) { _, _ in
            if isSelectMode { isSelectMode = false; selectedIDs.removeAll() }
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Sort By") {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button(action: { sortOrder = order }) {
                        if sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            }

            Section("Filter by Category") {
                Button {
                    selectedCategory = nil
                } label: {
                    if selectedCategory == nil { Label("All Categories", systemImage: "checkmark") }
                    else { Text("All Categories") }
                }
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        if selectedCategory == category { Label(category.rawValue, systemImage: "checkmark") }
                        else { Text(category.rawValue) }
                    }
                }
            }

            if !rooms.isEmpty {
                Section("Filter by Room") {
                    Button {
                        selectedRoom = nil
                    } label: {
                        if selectedRoom == nil { Label("All Rooms", systemImage: "checkmark") }
                        else { Text("All Rooms") }
                    }
                    ForEach(rooms) { room in
                        Button(action: { selectedRoom = room }) {
                            if selectedRoom?.persistentModelID == room.persistentModelID {
                                Label(room.name, systemImage: "checkmark")
                            } else {
                                Text(room.name)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: activeFilterCount > 0
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder
    private var moveToRoomSheet: some View {
        NavigationStack {
            List {
                Button {
                    moveSelected(to: nil)
                    showingMoveSheet = false
                } label: {
                    Label("No Room", systemImage: "xmark.circle")
                        .foregroundStyle(.primary)
                }

                ForEach(rooms) { room in
                    Button {
                        moveSelected(to: room)
                        showingMoveSheet = false
                    } label: {
                        Label(room.name, systemImage: room.icon)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Move to Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingMoveSheet = false }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No Items Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to add your first item")
                .foregroundStyle(.secondary)
            Button("Add Item") { showingAddItem = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteItems(offsets: IndexSet) {
        undoTask?.cancel()
        let toDelete = offsets.map { filteredItems[$0] }
        undoMementos = toDelete.map { DeletedItemMemento(from: $0) }
        for item in toDelete { modelContext.delete(item) }
        scheduleUndoDismissal()
    }

    private func bulkDelete() {
        undoTask?.cancel()
        let toDelete = filteredItems.filter { selectedIDs.contains($0.persistentModelID) }
        undoMementos = toDelete.map { DeletedItemMemento(from: $0) }
        for item in toDelete { modelContext.delete(item) }
        selectedIDs.removeAll()
        isSelectMode = false
        scheduleUndoDismissal()
    }

    private func scheduleUndoDismissal() {
        undoTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                await MainActor.run { undoMementos = [] }
            }
        }
    }

    private func moveSelected(to room: Room?) {
        for id in selectedIDs {
            if let item = filteredItems.first(where: { $0.persistentModelID == id }) {
                item.room = room
            }
        }
        selectedIDs.removeAll()
        isSelectMode = false
    }
}
