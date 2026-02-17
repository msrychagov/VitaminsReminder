import Foundation
import UserNotifications

final class ReminderNotificationScheduler {
    static let shared = ReminderNotificationScheduler()

    private let center: UNUserNotificationCenter
    private let requestIDPrefix = "vitamins.reminder."
    private let maxPendingRequests = 60

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func schedule(from reminders: [ReminderRemote]) async {
        await requestAuthorizationIfNeeded()

        let settings = await center.notificationSettingsAsync()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let requests = buildRequests(from: reminders)
        await removeScheduledReminderNotifications()

        for request in requests.prefix(maxPendingRequests) {
            try? await center.addAsync(request)
        }
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettingsAsync()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    private func removeScheduledReminderNotifications() async {
        let pendingIDs = await center.pendingNotificationRequestsAsync()
            .map(\.identifier)
            .filter { $0.hasPrefix(requestIDPrefix) }
        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }

        let deliveredIDs = await center.deliveredNotificationsAsync()
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(requestIDPrefix) }
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }

    private func buildRequests(from reminders: [ReminderRemote]) -> [UNNotificationRequest] {
        reminders
            .filter { $0.isActive }
            .flatMap { reminder in
                let name = reminderNotificationName(for: reminder)
                let dayCodes = normalizedDayCodes(reminder.schedule?.days)
                let times = normalizedTimes(reminder.schedule?.times)
                let timezone = reminder.course?.timezone.flatMap(TimeZone.init(identifier:))

                return dayCodes.flatMap { dayCode in
                    times.compactMap { time in
                        makeRequest(
                            reminderID: reminder.id,
                            vitaminName: name,
                            dayCode: dayCode,
                            time: time,
                            timezone: timezone
                        )
                    }
                }
            }
    }

    private func makeRequest(
        reminderID: Int,
        vitaminName: String,
        dayCode: String,
        time: (hour: Int, minute: Int),
        timezone: TimeZone?
    ) -> UNNotificationRequest? {
        guard let weekday = weekdayNumber(for: dayCode) else { return nil }

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute
        dateComponents.second = 0
        dateComponents.timeZone = timezone

        let titleName: String = {
            let lowered = vitaminName.lowercased()
            if lowered.contains("витамин") {
                return vitaminName
            }
            return "Витамин \(vitaminName)"
        }()

        let content = UNMutableNotificationContent()
        content.title = "Примите \(titleName) !"
        content.body = "Удерживайте, чтобы отметить прием\nи увидеть дополнительную информацию"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "\(requestIDPrefix)\(reminderID).\(dayCode).\(time.hour).\(time.minute)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func reminderNotificationName(for reminder: ReminderRemote) -> String {
        if let displayName = reminder.catalog?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }

        let trimmed = reminder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Витамин" : trimmed
    }

    private func normalizedDayCodes(_ source: [String]?) -> [String] {
        let normalized = source?.map { $0.lowercased() } ?? []
        if normalized.isEmpty {
            return ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        }
        return normalized
    }

    private func normalizedTimes(_ source: [String]?) -> [(hour: Int, minute: Int)] {
        let parsed = (source ?? []).compactMap(parseTime)
        if parsed.isEmpty {
            return [(9, 0)]
        }
        return parsed
    }

    private func parseTime(_ raw: String) -> (hour: Int, minute: Int)? {
        let components = raw.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func weekdayNumber(for code: String) -> Int? {
        switch code {
        case "sun": return 1
        case "mon": return 2
        case "tue": return 3
        case "wed": return 4
        case "thu": return 5
        case "fri": return 6
        case "sat": return 7
        default: return nil
        }
    }
}

private extension UNUserNotificationCenter {
    func addAsync(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func notificationSettingsAsync() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    func pendingNotificationRequestsAsync() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    func deliveredNotificationsAsync() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }
}
