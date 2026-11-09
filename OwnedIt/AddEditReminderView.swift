import SwiftUI
import SwiftData
import UIKit

struct AddEditReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Item.name) private var allItems: [Item]

    /// The item to attach to. When nil (adding from the Maintenance tab) the user picks one.
    var item: Item? = nil
    var reminder: Reminder? = nil

    @State private var selectedItem: Item?
    @State private var title = ""
    @State private var notes = ""
    @State private var intervalOption: IntervalOption = .monthly
    @State private var customDays = 30
    @State private var nextDueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isActive = true
    @State private var showingPermissionAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var didLoad = false

    private var isEditing: Bool { reminder != nil }

    private var effectiveIntervalDays: Int {
        intervalOption == .custom ? customDays : intervalOption.rawValue
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (selectedItem != nil)
    }

    private static let suggestions = [
        "Replace air filter", "Clean filter", "Descale", "Check batteries",
        "Service", "Clean coils", "Replace water filter", "Software update",
    ]

    var body: some View {
        Form {
            if item == nil && reminder == nil {
                Section("Item") {
                    Picker("Item", selection: $selectedItem) {
                        Text("Choose…").tag(Item?.none)
                        ForEach(allItems) { item in
                            Text(item.displayName).tag(Item?.some(item))
                        }
                    }
                }
            }

            Section {
                TextField("Title (e.g. Change air filter)", text: $title)
                if title.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.suggestions, id: \.self) { suggestion in
                                Button(suggestion) { title = suggestion }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            } header: {
                Text("Reminder")
            }

            Section("Repeats") {
                Picker("Interval", selection: $intervalOption) {
                    ForEach(IntervalOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                if intervalOption == .custom {
                    Stepper(
                        "Every \(customDays.pluralized("day"))",
                        value: $customDays, in: 1...730
                    )
                }
            }

            Section {
                DatePicker("Next Due", selection: $nextDueDate, displayedComponents: .date)
            } footer: {
                Text("You'll get a notification at \(NotificationManager.reminderHour) AM on the due date.")
            }

            Section("Notes") {
                TextField("Optional notes…", text: $notes, axis: .vertical)
                    .lineLimit(1...5)
            }

            if isEditing {
                Section {
                    Toggle("Active", isOn: $isActive)
                } footer: {
                    Text("Paused reminders stay on the item but don't notify you.")
                }

                if let last = reminder?.lastCompletedDate {
                    Section {
                        LabeledContent("Last Done", value: last.formatted(date: .long, time: .omitted))
                    }
                }

                Section {
                    Button("Delete Reminder", role: .destructive) { showingDeleteConfirmation = true }
                }
            }
        }
        .themedList()
        .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            selectedItem = item ?? reminder?.item
            if let reminder {
                title = reminder.title
                notes = reminder.notes
                intervalOption = IntervalOption.from(days: reminder.intervalDays)
                if intervalOption == .custom { customDays = reminder.intervalDays }
                nextDueDate = reminder.nextDueDate
                isActive = reminder.isActive
            }
        }
        .onChange(of: intervalOption) { _, option in
            // For new reminders, keep the due date one interval out as the user changes it.
            guard !isEditing, option != .custom else { return }
            nextDueDate = Calendar.current.date(byAdding: .day, value: option.rawValue, to: Date()) ?? nextDueDate
        }
        .confirmationDialog("Delete this reminder?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let reminder { modelContext.delete(reminder) }
                dismiss()
            }
        }
        .alert("Notifications Are Off", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Your reminder was saved, but you won't be alerted when it's due until notifications are enabled for OwnedIt in Settings.")
        }
    }

    private func save() {
        guard let target = selectedItem else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = reminder {
            if existing.nextDueDate != nextDueDate || existing.intervalDays != effectiveIntervalDays {
                existing.notificationID = UUID().uuidString
            }
            existing.title = trimmedTitle
            existing.notes = trimmedNotes
            existing.intervalDays = effectiveIntervalDays
            existing.nextDueDate = nextDueDate
            existing.isActive = isActive
        } else {
            let newReminder = Reminder(
                title: trimmedTitle,
                notes: trimmedNotes,
                intervalDays: effectiveIntervalDays,
                nextDueDate: nextDueDate
            )
            newReminder.item = target
            modelContext.insert(newReminder)
        }

        // Ask for permission at the moment it's clearly useful, not on screen open.
        NotificationManager.shared.requestPermission { granted in
            if granted || !isActive {
                dismiss()
            } else {
                showingPermissionAlert = true
            }
        }
    }
}

// MARK: - Interval Options

private enum IntervalOption: Int, CaseIterable, Identifiable {
    case daily = 1
    case weekly = 7
    case biweekly = 14
    case monthly = 30
    case quarterly = 90
    case biannual = 180
    case yearly = 365
    case custom = -1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .daily:     return "Daily"
        case .weekly:    return "Weekly"
        case .biweekly:  return "Every 2 Weeks"
        case .monthly:   return "Monthly"
        case .quarterly: return "Every 3 Months"
        case .biannual:  return "Every 6 Months"
        case .yearly:    return "Yearly"
        case .custom:    return "Custom"
        }
    }

    static func from(days: Int) -> IntervalOption {
        allCases.first { $0.rawValue == days } ?? .custom
    }
}
