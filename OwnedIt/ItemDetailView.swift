import SwiftUI

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var showingEditItem = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedPhotoIndex = 0

    private var photos: [Photo] { item.photos ?? [] }
    private var category: ItemCategory { item.category ?? .other }
    private var condition: ItemCondition { item.condition ?? .good }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                if !photos.isEmpty {
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 280)
                                    .clipped()
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 280)
                }

                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Label(category.rawValue, systemImage: category.icon)
                                .badgeStyle(color: .accentColor)
                            Label(condition.rawValue, systemImage: "circle.fill")
                                .badgeStyle(color: condition.color)
                        }
                        if !item.itemDescription.isEmpty {
                            Text(item.itemDescription)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let room = item.room {
                        DetailSection(title: "Location") {
                            DetailRow(label: "Room", value: room.name, icon: room.icon)
                        }
                    }

                    if !item.make.isEmpty || !item.model.isEmpty || !item.serialNumber.isEmpty {
                        DetailSection(title: "Identification") {
                            if !item.make.isEmpty {
                                DetailRow(label: "Make", value: item.make, icon: "tag")
                            }
                            if !item.model.isEmpty {
                                DetailRow(label: "Model", value: item.model, icon: "tag.fill")
                            }
                            if !item.serialNumber.isEmpty {
                                DetailRow(label: "Serial #", value: item.serialNumber, icon: "number")
                            }
                        }
                    }

                    if item.purchasePrice != nil || item.purchaseDate != nil || !item.purchaseStore.isEmpty {
                        DetailSection(title: "Purchase") {
                            if let price = item.purchasePrice {
                                DetailRow(
                                    label: "Price",
                                    value: price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                                    icon: "dollarsign.circle"
                                )
                            }
                            if let date = item.purchaseDate {
                                DetailRow(label: "Date", value: date.formatted(date: .long, time: .omitted), icon: "calendar")
                            }
                            if !item.purchaseStore.isEmpty {
                                DetailRow(label: "Store", value: item.purchaseStore, icon: "storefront")
                            }
                        }
                    }

                    if let value = item.currentValue {
                        DetailSection(title: "Current Value") {
                            DetailRow(
                                label: "Value",
                                value: value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                                icon: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }

                    if item.warrantyExpiration != nil || !item.warrantyProvider.isEmpty {
                        DetailSection(title: "Warranty") {
                            if let expiration = item.warrantyExpiration {
                                let isExpired = expiration < Date()
                                DetailRow(
                                    label: "Expires",
                                    value: expiration.formatted(date: .long, time: .omitted),
                                    icon: isExpired ? "exclamationmark.circle.fill" : "checkmark.shield",
                                    valueColor: isExpired ? .red : .primary
                                )
                            }
                            if !item.warrantyProvider.isEmpty {
                                DetailRow(label: "Provider", value: item.warrantyProvider, icon: "building.2")
                            }
                        }
                    }

                    if !item.notes.isEmpty {
                        DetailSection(title: "Notes") {
                            Text(item.notes)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let added = item.dateAdded {
                        Text("Added \(added.formatted(date: .long, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(item.name.isEmpty ? "Item" : item.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditItem = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditItem) {
            NavigationStack {
                AddEditItemView(item: item)
            }
        }
        .confirmationDialog("Delete \"\(item.name)\"?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Item", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Supporting Views

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 10) { content }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(label).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Text(value).foregroundStyle(valueColor).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }
}

private struct BadgeStyle: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private extension View {
    func badgeStyle(color: Color) -> some View { modifier(BadgeStyle(color: color)) }
}
