import Foundation
import Combine

enum ReminderNotificationIdentifiers {
    static let category = "VITAMIN_REMINDER_CATEGORY"

    static let actionMarkTaken = "VITAMIN_REMINDER_MARK_TAKEN"
    static let actionSnooze15 = "VITAMIN_REMINDER_SNOOZE_15"
    static let actionSnooze60 = "VITAMIN_REMINDER_SNOOZE_60"
    static let actionOpenReminder = "VITAMIN_REMINDER_OPEN"

    static let userInfoReminderID = "reminder_id"
    static let userInfoReminderTime = "reminder_time"
    static let userInfoReminderDay = "reminder_day"

    static func parseReminderID(from userInfo: [AnyHashable: Any]) -> Int? {
        if let value = userInfo[userInfoReminderID] as? Int {
            return value
        }
        if let value = userInfo[userInfoReminderID] as? NSNumber {
            return value.intValue
        }
        if let value = userInfo[userInfoReminderID] as? String, let parsed = Int(value) {
            return parsed
        }
        return nil
    }

    static func parseReminderTime(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo[userInfoReminderTime] as? String
    }

    static func parseReminderDay(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo[userInfoReminderDay] as? String
    }
}

struct ReminderOpenContext: Equatable {
    let reminderID: Int
    let preferredTime: String?
    let dayCode: String?
}

@MainActor
final class ReminderNotificationRouter: ObservableObject {
    static let shared = ReminderNotificationRouter()

    @Published private(set) var pendingContext: ReminderOpenContext?

    func enqueue(_ context: ReminderOpenContext) {
        pendingContext = context
    }

    func consume() {
        pendingContext = nil
    }
}
