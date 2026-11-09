import SwiftUI
import SwiftData
import UserNotifications

/// Owns all local notifications.
///
/// Rather than scheduling/cancelling ad hoc from every screen, the app *reconciles*: the full
/// set of desired notifications is derived from the data store and replaces whatever is pending.
/// This keeps notifications correct after deletes, undo, edits on another device via iCloud, etc.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    static let reminderHour = 9
    static let warrantyLeadDays = 30
    /// iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 60

    /// Called on the main thread when the user taps a notification.
    var onOpenNotification: ((_ kind: Kind) -> Void)?

    enum Kind: String { case reminder, warranty }

    private override init() { super.init() }

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Requests notification permission (prompts only if not yet determined) and reports
    /// whether alerts are actually authorized, on the main thread.
    func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Current authorization status, without prompting the user.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Reconciliation

    struct Planned: Equatable {
        let id: String
        let kind: Kind
        let title: String
        let body: String
        let fireDate: Date
    }

    /// Pure function: what *should* be scheduled for the given data. Must be called on the main
    /// actor because it reads SwiftData models.
    static func plan(reminders: [Reminder], warrantyItems: [Item], includeWarranties: Bool, now: Date = Date()) -> [Planned] {
        let calendar = Calendar.current
        func fireDate(onDayOf date: Date) -> Date? {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = reminderHour
            components.minute = 0
            return calendar.date(from: components)
        }

        var planned: [Planned] = []

        for reminder in reminders where reminder.isActive {
            guard let fire = fireDate(onDayOf: reminder.nextDueDate), fire > now else { continue }
            let itemName = reminder.item?.name ?? ""
            planned.append(Planned(
                id: "reminder-\(reminder.notificationID)",
                kind: .reminder,
                title: reminder.title,
                body: itemName.isEmpty ? "Maintenance is due." : "Maintenance due for \(itemName).",
                fireDate: fire
            ))
        }

        if includeWarranties {
            for item in warrantyItems {
                guard let expiration = item.warrantyExpiration,
                      let leadDate = calendar.date(byAdding: .day, value: -warrantyLeadDays, to: expiration),
                      let fire = fireDate(onDayOf: leadDate), fire > now else { continue }
                let key = item.id?.uuidString ?? String(describing: item.persistentModelID.hashValue)
                planned.append(Planned(
                    id: "warranty-\(key)-\(Int(expiration.timeIntervalSince1970))",
                    kind: .warranty,
                    title: "Warranty expiring soon",
                    body: "The warranty for \(item.displayName) expires \(expiration.formatted(date: .long, time: .omitted)).",
                    fireDate: fire
                ))
            }
        }

        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    func apply(_ planned: [Planned]) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let pending = await center.pendingNotificationRequests()
        let desiredIDs = Set(planned.map(\.id))
        let stale = pending.map(\.identifier).filter { !desiredIDs.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let pendingByID = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { a, _ in a })
        for plan in planned {
            if let existing = pendingByID[plan.id],
               existing.content.title == plan.title,
               existing.content.body == plan.body,
               (existing.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() == plan.fireDate {
                continue
            }
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.userInfo = ["kind": plan.kind.rawValue]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
            } catch {
                print("NotificationManager: failed to schedule \(plan.id) – \(error.localizedDescription)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let raw = response.notification.request.content.userInfo["kind"] as? String
        let kind = raw.flatMap(Kind.init(rawValue:)) ?? .reminder
        await MainActor.run { onOpenNotification?(kind) }
    }
}

// MARK: - Keeping notifications in sync

enum SettingsKeys {
    static let warrantyAlertsEnabled = "warrantyAlertsEnabled"
    static let hasSeenOnboarding = "hasSeenOnboarding"
}

/// Watches the store and re-plans notifications whenever relevant data changes
/// (locally or via iCloud) and whenever the app becomes active.
private struct NotificationSyncModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var reminders: [Reminder]
    @Query(filter: #Predicate<Item> { $0.warrantyExpiration != nil }) private var warrantyItems: [Item]
    @AppStorage(SettingsKeys.warrantyAlertsEnabled) private var warrantyAlertsEnabled = true
    @State private var activationCount = 0

    private var signature: Int {
        var hasher = Hasher()
        for r in reminders {
            hasher.combine(r.notificationID)
            hasher.combine(r.title)
            hasher.combine(r.nextDueDate)
            hasher.combine(r.isActive)
            hasher.combine(r.item?.name)
        }
        for i in warrantyItems {
            hasher.combine(i.id)
            hasher.combine(i.name)
            hasher.combine(i.warrantyExpiration)
        }
        hasher.combine(warrantyAlertsEnabled)
        hasher.combine(activationCount)
        return hasher.finalize()
    }

    func body(content: Content) -> some View {
        content
            .task(id: signature) {
                // Debounce bursts of changes (e.g. an iCloud import).
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                let plan = NotificationManager.plan(reminders: reminders,
                                                    warrantyItems: warrantyItems,
                                                    includeWarranties: warrantyAlertsEnabled)
                await NotificationManager.shared.apply(plan)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { activationCount += 1 }
            }
    }
}

extension View {
    func keepsNotificationsInSync() -> some View { modifier(NotificationSyncModifier()) }
}
