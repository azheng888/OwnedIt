import SwiftUI
import SwiftData
import UIKit

struct AddEditReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: Item
    var reminder: Reminder? = nil

    @State private var title = ""
    @State private var notes = ""
    @State private var intervalOption: IntervalOption = .monthly
    @State private var customDays = 30
    @State private var nextDueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var showingPermissionAlert = false

    private var isEditing: Bool { reminder != nil }

    private var effectiveIntervalDays: Int {
        intervalOption == .custom ? customDays : intervalOption.rawValue
    }

    var body: some View {
        Form {
            Section("Reminder") {
                TextField("Title (e.g. Change air filter)", text: $title)
            }

            Section("Repeats") {
                Picker("Interval", selection: $intervalOption) {
                    ForEach(IntervalOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                if intervalOption == .custom {
                    Stepper(
                        "Every \(customDays) day\(customDays == 1 ? "" : "s")",
                        value: $customDays, in: 1...365
                    )
                }
            }

            Section("Next Due") {
                DatePicker("Date", selection: $nextDueDate, displayedComponents: .date)
            }

            Section("Notes") {
                TextField("Optional notes…", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: false)
            }
        }
        .navigationTitle(isEditing ? "Edit Reminder" : "Add Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let reminder {
                title = reminder.title
                notes = reminder.notes
                intervalOption = IntervalOption.from(days: reminder.intervalDays)
                if intervalOption == .custom { customDays = reminder.intervalDays }
                nextDueDate = reminder.nextDueDate
            }
            NotificationManager.shared.requestPermission { granted in
                if !granted {
                    showingPermissionAlert = true
                }
            }
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("This reminder will be saved, but you won't get an alert when it's due until notifications are enabled in Settings.")
        }
    }

    private func save() {
        let days = effectiveIntervalDays
        if let existing = reminder {
            NotificationManager.shared.cancel(existing.notificationID)
            existing.title = title.trimmingCharacters(in: .whitespaces)
            existing.notes = notes
            existing.intervalDays = days
            existing.nextDueDate = nextDueDate
            NotificationManager.shared.schedule(existing, itemName: item.name)
        } else {
            let newReminder = Reminder(
                title: title.trimmingCharacters(in: .whitespaces),
                notes: notes,
                intervalDays: days,
                nextDueDate: nextDueDate
            )
            newReminder.item = item
            modelContext.insert(newReminder)
            NotificationManager.shared.schedule(newReminder, itemName: item.name)
        }
        dismiss()
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
        return allCases.first { $0.rawValue == days } ?? .custom
    }
}
