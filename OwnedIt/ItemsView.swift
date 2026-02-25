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

    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case name = "Name"
        case value = "Value"
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
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRowView(item: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if filteredItems.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
        .navigationTitle("Items")
        .searchable(text: $searchText, prompt: "Search items…")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                filterMenu
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                AddEditItemView()
            }
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
        for index in offsets {
            modelContext.delete(filteredItems[index])
        }
    }
}
