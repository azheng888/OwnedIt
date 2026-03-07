import Foundation
import SwiftData

@Model
final class Reminder {
    var notificationID: String = ""
    var title: String = ""
    var notes: String = ""
    var intervalDays: Int = 30
    var nextDueDate: Date = Date()
    var isActive: Bool = true
    var item: Item?

    init(title: String, notes: String = "", intervalDays: Int, nextDueDate: Date) {
        self.notificationID = UUID().uuidString
        self.title = title
        self.notes = notes
        self.intervalDays = intervalDays
        self.nextDueDate = nextDueDate
        self.isActive = true
    }

    var isDue: Bool { nextDueDate <= Date() }

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

    /// Advances nextDueDate by intervalDays. Starts from today if overdue.
    func advance() {
        let base = isDue ? Date() : nextDueDate
        nextDueDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: base) ?? base
        notificationID = UUID().uuidString
    }
}
