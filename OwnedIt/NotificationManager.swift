import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

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

    func schedule(_ reminder: Reminder, itemName: String) {
        // Capture model values on the calling (main) thread before async work
        let id = reminder.notificationID
        let title = reminder.title
        let dueDate = reminder.nextDueDate
        let body = itemName.isEmpty ? "Maintenance is due." : "Maintenance due for \(itemName)."

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationManager: failed to schedule \(id) – \(error.localizedDescription)")
            }
        }
    }

    func cancel(_ notificationID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
