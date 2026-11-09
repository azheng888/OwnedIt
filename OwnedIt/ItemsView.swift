import SwiftUI
import SwiftData

struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory?
    @State private var selectedRoom: Room?
    @AppStorage("items.sortOrder") private var sortOrder: SortOrder = .dateAdded
    @State private var showingAddItem = false

    // Bulk select
    @State private var isSelectMode = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var showingMoveSheet = false
    @State private var showingBulkDeleteConfirmation = false

    @State private var undoMementos: [DeletedItemMemento] = []

    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case name = "Name"
        case value = "Value"
        case condition = "Condition"
        case warranty = "Warranty Expiry"
    }

    private var filteredItems: [Item] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        var result = items.filter { item in
            (query.isEmpty || item.matches(search: query)) &&
            (selectedCategory == nil || item.category == selectedCategory) &&
            (selectedRoom == nil || item.room?.persistentModelID == selectedRoom?.persistentModelID)
        }

        func byName(_ a: Item, _ b: Item) -> Bool {
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        switch sortOrder {
        case .dateAdded:
            result.sort { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
        case .name:
            result.sort(by: byName)
        case .value:
            result.sort { ($0.displayValue ?? -1) > ($1.displayValue ?? -1) }
        case .condition:
            result.sort {
                let l = $0.condition?.rank ?? .max, r = $1.condition?.rank ?? .max
                return l == r ? byName($0, $1) : l < r
            }
        case .warranty:
            result.sort { ($0.warrantyExpiration ?? .distantFuture) < ($1.warrantyExpiration ?? .distantFuture) }
        }

        return result
    }

    /// Items grouped by room (alphabetical, Unassigned last), each group in the chosen sort order.
    private func grouped(_ items: [Item]) -> [(id: String, title: String, total: Double, items: [Item])] {
        let groups = Dictionary(grouping: items) { $0.room?.name }
        let names = groups.keys.compactMap { $0 }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        var result: [(id: String, title: String, total: Double, items: [Item])] = []
        for name in names {
            let members = groups[name] ?? []
            result.append((name, name, members.compactMap(\.displayValue).reduce(0, +), members))
        }
        if let unassigned = groups[nil], !unassigned.isEmpty {
            result.append(("__unassigned", "Unassigned", unassigned.compactMap(\.displayValue).reduce(0, +), unassigned))
        }
        return result
    }

    private var hasActiveFilters: Bool { selectedCategory != nil || selectedRoom != nil }

    var body: some View {
        let visible = filteredItems
        Group {
            if items.isEmpty {
                emptyStateView
            } else {
                List {
                    if hasActiveFilters {
                        activeFiltersBar(count: visible.count, value: visible.compactMap(\.displayValue).reduce(0, +))
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    }
                    ForEach(grouped(visible), id: \.id) { group in
                        Section {
                            ForEach(group.items) { item in
                                row(for: item).themedRow()
                            }
                            .onDelete(perform: isSelectMode ? nil : { offsets in
                                undoMementos = ItemActions.delete(offsets.map { group.items[$0] }, in: modelContext)
                            })
                        } header: {
                            CardHeader(title: group.title) {
                                if group.total > 0 { Text(group.total.wholeCurrencyString) }
                            }
                            .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .themedList()
                .overlay {
                    if visible.isEmpty {
                        if searchText.isEmpty {
                            ContentUnavailableView {
                                Label("No Matching Items", systemImage: "line.3.horizontal.decrease.circle")
                            } description: {
                                Text("No items match the current filters.")
                            } actions: {
                                Button("Clear Filters") { clearFilters() }
                            }
                        } else {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if isSelectMode && !selectedIDs.isEmpty {
                        bulkActionBar
                    }
                }
            }
        }
        .themedScreen()
        .navigationTitle("Items")
        .searchable(text: $searchText, prompt: "Name, brand, serial, notes…")
        .toolbar { toolbarContent(visible: visible) }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                AddEditItemView()
            }
        }
        .sheet(isPresented: $showingMoveSheet) {
            MoveToRoomSheet(rooms: rooms) { room in
                for item in items where selectedIDs.contains(item.persistentModelID) {
                    item.room = room
                }
                exitSelectMode()
            }
        }
        .confirmationDialog(
            "Delete \(selectedIDs.count.pluralized("item"))?",
            isPresented: $showingBulkDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                let toDelete = items.filter { selectedIDs.contains($0.persistentModelID) }
                undoMementos = ItemActions.delete(toDelete, in: modelContext)
                exitSelectMode()
            }
        }
        .undoDeleteToast($undoMementos)
        .onChange(of: searchText) { exitSelectMode() }
        .onChange(of: selectedCategory) { exitSelectMode() }
        .onChange(of: selectedRoom) { exitSelectMode() }
        .onChange(of: rooms) {
            // The filtered room was deleted (possibly on another device).
            if let selectedRoom, !rooms.contains(where: { $0.persistentModelID == selectedRoom.persistentModelID }) {
                self.selectedRoom = nil
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for item: Item) -> some View {
        if isSelectMode {
            let isSelected = selectedIDs.contains(item.persistentModelID)
            Button {
                if isSelected {
                    selectedIDs.remove(item.persistentModelID)
                } else {
                    selectedIDs.insert(item.persistentModelID)
                }
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Theme.ink : Theme.tertiaryText)
                        .font(.title3)
                    ItemRowView(item: item, showsRoom: false)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            NavigationLink(destination: ItemDetailView(item: item)) {
                ItemRowView(item: item, showsRoom: false)
            }
            .contextMenu {
                Button {
                    ItemActions.duplicate(item, in: modelContext)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Menu {
                    Button("No Room") { item.room = nil }
                    ForEach(rooms) { room in
                        Button(room.name) { item.room = room }
                    }
                } label: {
                    Label("Move to Room", systemImage: "arrow.right.square")
                }
                Divider()
                Button(role: .destructive) {
                    undoMementos = ItemActions.delete([item], in: modelContext)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func activeFiltersBar(count: Int, value: Double) -> some View {
        Section {
            HStack(spacing: 8) {
                if let selectedCategory {
                    filterChip(selectedCategory.rawValue, icon: selectedCategory.icon) { self.selectedCategory = nil }
                }
                if let selectedRoom {
                    filterChip(selectedRoom.name, icon: selectedRoom.icon) { self.selectedRoom = nil }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(count.pluralized("item"))
                    if value > 0 { Text(value.wholeCurrencyString).fontWeight(.semibold) }
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func filterChip(_ title: String, icon: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).lineLimit(1)
                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(Theme.ink)
            .background(Theme.surfaceMuted, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove filter \(title)")
    }

    private var bulkActionBar: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) {
                showingBulkDeleteConfirmation = true
            } label: {
                Text("Delete \(selectedIDs.count)")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.critical)

            Button {
                showingMoveSheet = true
            } label: {
                Text("Move to Room…")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(visible: [Item]) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelectMode {
                Button("Cancel") { exitSelectMode() }
            } else {
                filterMenu
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelectMode {
                let allSelected = !visible.isEmpty && visible.allSatisfy { selectedIDs.contains($0.persistentModelID) }
                Button(allSelected ? "Deselect All" : "Select All") {
                    selectedIDs = allSelected ? [] : Set(visible.map(\.persistentModelID))
                }
            } else {
                if !items.isEmpty {
                    Button("Select") { isSelectMode = true }
                }
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Item")
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)

            Picker("Category", selection: $selectedCategory) {
                Text("All Categories").tag(ItemCategory?.none)
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon).tag(ItemCategory?.some(category))
                }
            }
            .pickerStyle(.menu)

            if !rooms.isEmpty {
                Picker("Room", selection: $selectedRoom) {
                    Text("All Rooms").tag(Room?.none)
                    ForEach(rooms) { room in
                        Label(room.name, systemImage: room.icon).tag(Room?.some(room))
                    }
                }
                .pickerStyle(.menu)
            }

            if hasActiveFilters {
                Divider()
                Button("Clear Filters", role: .destructive) { clearFilters() }
            }
        } label: {
            Image(systemName: hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Sort and Filter")
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Items Yet", systemImage: "archivebox")
        } description: {
            Text("Add the things you own — photos, receipts and serial numbers make insurance claims painless.")
        } actions: {
            Button("Add Item") { showingAddItem = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ink)
        }
    }

    private func clearFilters() {
        selectedCategory = nil
        selectedRoom = nil
    }

    private func exitSelectMode() {
        isSelectMode = false
        selectedIDs.removeAll()
    }
}

// MARK: - Move to Room

struct MoveToRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    let rooms: [Room]
    let onSelect: (Room?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    Label("No Room", systemImage: "tray")
                        .foregroundStyle(.primary)
                }

                ForEach(rooms) { room in
                    Button {
                        onSelect(room)
                        dismiss()
                    } label: {
                        Label {
                            Text(room.name).foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: room.icon).foregroundStyle(room.color)
                        }
                    }
                }
            }
            .navigationTitle("Move to Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
