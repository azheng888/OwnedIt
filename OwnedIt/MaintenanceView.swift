import SwiftUI
import SwiftData

struct MaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.nextDueDate) private var reminders: [Reminder]

    private var overdue: [Reminder] {
        reminders.filter { $0.isActive && $0.isDue }
    }

    private var upcoming: [Reminder] {
        let threshold = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return reminders.filter { $0.isActive && !$0.isDue && $0.nextDueDate <= threshold }
    }

    private var scheduled: [Reminder] {
        let threshold = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return reminders.filter { $0.isActive && $0.nextDueDate > threshold }
    }

    var body: some View {
        List {
            if !overdue.isEmpty {
                Section("Overdue") {
                    ForEach(overdue) { reminder in
                        ReminderRow(reminder: reminder) {
                            markDone(reminder)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(reminder) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { markDone(reminder) } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }

            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { reminder in
                        ReminderRow(reminder: reminder) {
                            markDone(reminder)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(reminder) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { markDone(reminder) } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }

            if !scheduled.isEmpty {
                Section("Scheduled") {
                    ForEach(scheduled) { reminder in
                        ReminderRow(reminder: reminder) {
                            markDone(reminder)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(reminder) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { markDone(reminder) } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }

            if reminders.isEmpty {
                ContentUnavailableView(
                    "No Reminders",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Add maintenance reminders from an item's detail view.")
                )
            }
        }
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.large)
    }

    private func markDone(_ reminder: Reminder) {
        NotificationManager.shared.cancel(reminder.notificationID)
        reminder.advance()
        NotificationManager.shared.schedule(reminder, itemName: reminder.item?.name ?? "")
    }

    private func delete(_ reminder: Reminder) {
        NotificationManager.shared.cancel(reminder.notificationID)
        modelContext.delete(reminder)
    }
}

// MARK: - Reminder Row

private struct ReminderRow: View {
    let reminder: Reminder
    let onMarkDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let itemName = reminder.item?.name, !itemName.isEmpty {
                    Text(itemName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Due \(reminder.nextDueDate.formatted(.dateTime.month(.abbreviated).day().year())) · \(reminder.intervalLabel)")
                    .font(.caption)
                    .foregroundStyle(reminder.isDue ? .red : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onMarkDone) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }
}
