import SwiftUI
import SwiftData
import UIKit

struct MaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.nextDueDate) private var reminders: [Reminder]
    @Query private var items: [Item]
    @State private var notificationsDenied = false
    @State private var showingAdd = false
    @State private var editing: Reminder?
    @State private var completedCount = 0

    private var active: [Reminder] { reminders.filter { $0.isActive && $0.item != nil } }
    private var due: [Reminder] { active.filter(\.isDue) }
    private var soon: [Reminder] {
        let horizon = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return active.filter { !$0.isDue && $0.nextDueDate <= horizon }
    }
    private var later: [Reminder] {
        let horizon = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return active.filter { $0.nextDueDate > horizon }
    }
    private var paused: [Reminder] { reminders.filter { !$0.isActive && $0.item != nil } }

    var body: some View {
        List {
            if notificationsDenied && !active.isEmpty {
                Section { notificationsBanner }
                    .listRowBackground(Theme.warning.opacity(0.1))
            }

            if !active.isEmpty {
                Section {
                    summaryHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            section("Due", due, tint: Theme.critical)
            section("Next 30 Days", soon, tint: Theme.warning)
            section("Later", later, tint: nil)
            section("Paused", paused, tint: nil)
        }
        .listStyle(.insetGrouped)
        .themedList()
        .animation(Motion.snappy, value: reminders.map(\.nextDueDate))
        .overlay {
            if reminders.allSatisfy({ $0.item == nil }) {
                emptyState
            }
        }
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .disabled(items.isEmpty)
                    .accessibilityLabel("Add Reminder")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddEditReminderView() }
        }
        .sheet(item: $editing) { reminder in
            NavigationStack { AddEditReminderView(reminder: reminder) }
        }
        .sensoryFeedback(.success, trigger: completedCount)
        .task {
            notificationsDenied = await NotificationManager.shared.authorizationStatus() == .denied
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 12) {
            stat(value: due.count, label: "Due now", color: due.isEmpty ? .secondary : Theme.critical)
            stat(value: soon.count, label: "Next 30 days", color: soon.isEmpty ? .secondary : Theme.warning)
            stat(value: active.count, label: "Active", color: .primary)
        }
        .padding(.vertical, 4)
    }

    private func stat(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.hero(30))
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func section(_ title: String, _ list: [Reminder], tint: Color?) -> some View {
        if !list.isEmpty {
            Section {
                ForEach(list) { reminder in
                    ReminderRow(reminder: reminder, tint: tint) {
                        withAnimation(Motion.snappy) { reminder.markDone() }
                        completedCount += 1
                    } onOpen: {
                        editing = reminder
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation(Motion.snappy) { modelContext.delete(reminder) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            withAnimation(Motion.snappy) { reminder.isActive.toggle() }
                        } label: {
                            Label(reminder.isActive ? "Pause" : "Resume",
                                  systemImage: reminder.isActive ? "pause" : "play")
                        }
                        .tint(.gray)
                    }
                    .swipeActions(edge: .leading) {
                        if reminder.isActive {
                            Button {
                                withAnimation(Motion.snappy) { reminder.markDone() }
                                completedCount += 1
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(Theme.positive)
                        }
                    }
                }
            } header: {
                Text(title)
            }
        }
    }

    private var notificationsBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemName: "bell.slash.fill", color: Theme.warning, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are off")
                    .font(.subheadline.weight(.semibold))
                Text("You won't be alerted when maintenance is due.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button("Enable") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to Maintain", systemImage: "wrench.and.screwdriver")
        } description: {
            Text(items.isEmpty
                 ? "Add an item first, then set reminders for filters, servicing and more."
                 : "Set recurring reminders — air filters, smoke detector batteries, servicing.")
        } actions: {
            if !items.isEmpty {
                Button("Add Reminder") { showingAdd = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Reminder Row

private struct ReminderRow: View {
    let reminder: Reminder
    let tint: Color?
    let onMarkDone: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    if let item = reminder.item {
                        ItemThumbnailView(item: item, size: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(reminder.isActive ? .primary : .secondary)
                            .lineLimit(1)
                        if let name = reminder.item?.name, !name.isEmpty {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(1)
                        }
                        Text(reminder.statusLine)
                            .font(.caption)
                            .foregroundStyle(tint ?? .secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if reminder.isActive {
                Button(action: onMarkDone) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(Theme.positive)
                        .symbolEffect(.bounce, value: reminder.lastCompletedDate)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Mark \(reminder.title) done")
            }
        }
    }
}
