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
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selectedIcon == icon ? Theme.onAccent : Theme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(selectedIcon == icon ? Theme.ink : Theme.surfaceMuted,
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(icon)
                        .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .themedList()
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
