import SwiftUI
import SwiftData

struct AddEditRoomView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var room: Room? = nil

    @State private var name = ""
    @State private var selectedIcon = "house"
    @State private var selectedColor = "blue"

    var isEditing: Bool { room != nil }

    var body: some View {
        Form {
            Section("Room Name") {
                TextField("e.g. Living Room", text: $name)
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(Room.iconOptions, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon
                                          ? Color.accentColor.opacity(0.2)
                                          : Color(.tertiarySystemBackground))
                                Image(systemName: icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(selectedIcon == icon ? Color.accentColor : .secondary)
                            }
                            .frame(height: 48)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Color") {
                HStack(spacing: 14) {
                    ForEach(Room.colorOptions, id: \.name) { option in
                        Button {
                            selectedColor = option.name
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 32, height: 32)
                                if selectedColor == option.name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            // Preview
            Section("Preview") {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(previewColor.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: selectedIcon)
                            .font(.system(size: 22))
                            .foregroundStyle(previewColor)
                    }
                    Text(name.isEmpty ? "Room Name" : name)
                        .font(.headline)
                        .foregroundStyle(name.isEmpty ? .secondary : .primary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(isEditing ? "Edit Room" : "New Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let room {
                name = room.name
                selectedIcon = room.icon
                selectedColor = room.colorName
            }
        }
    }

    private var previewColor: Color {
        Room.colorOptions.first { $0.name == selectedColor }?.color ?? .blue
    }

    private func save() {
        if let room {
            room.name = name.trimmingCharacters(in: .whitespaces)
            room.icon = selectedIcon
            room.colorName = selectedColor
        } else {
            let newRoom = Room(
                name: name.trimmingCharacters(in: .whitespaces),
                icon: selectedIcon,
                colorName: selectedColor
            )
            modelContext.insert(newRoom)
        }
        dismiss()
    }
}
