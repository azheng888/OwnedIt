import Foundation
import SwiftData

@Model
final class Reminder {
    /// Identifies the pending local notification; regenerated each time the reminder advances.
    var notificationID: String = ""
    var title: String = ""
    var notes: String = ""
    var intervalDays: Int = 30
    var nextDueDate: Date = Date()
    var isActive: Bool = true
    var lastCompletedDate: Date?
    var item: Item?

    init(title: String, notes: String = "", intervalDays: Int, nextDueDate: Date) {
        self.notificationID = UUID().uuidString
        self.title = title
        self.notes = notes
        self.intervalDays = max(1, intervalDays)
        self.nextDueDate = nextDueDate
        self.isActive = true
    }

    /// Due any time today counts as due.
    var isDue: Bool {
        nextDueDate < Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
    }

    var isOverdue: Bool {
        nextDueDate < Calendar.current.startOfDay(for: Date())
    }

    var intervalLabel: String {
        switch intervalDays {
        case 1:   return "Daily"
        case 7:   return "Weekly"
        case 14:  return "Every 2 weeks"
        case 30:  return "Monthly"
        case 60:  return "Every 2 months"
        case 90:  return "Every 3 months"
        case 180: return "Every 6 months"
        case 365: return "Yearly"
        default:  return "Every \(intervalDays) days"
        }
    }

    /// "Due today · Monthly", "Overdue since Mar 6 · Weekly", "Paused".
    var statusLine: String {
        guard isActive else { return "Paused · \(intervalLabel)" }
        let calendar = Calendar.current
        let date: String
        if calendar.isDateInToday(nextDueDate) {
            date = "Due today"
        } else if calendar.isDateInTomorrow(nextDueDate) {
            date = "Due tomorrow"
        } else if isOverdue {
            date = "Overdue since \(AppFormat.shortDate(nextDueDate))"
        } else {
            date = "Due \(AppFormat.shortDate(nextDueDate))"
        }
        return "\(date) · \(intervalLabel)"
    }

    /// Records completion and schedules the next occurrence from today (if late) or the due date.
    func markDone(on date: Date = Date()) {
        lastCompletedDate = date
        let base = nextDueDate < date ? date : nextDueDate
        nextDueDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: base) ?? base
        notificationID = UUID().uuidString
    }
}
