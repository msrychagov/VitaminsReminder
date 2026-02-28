import Foundation
import UIKit
import UserNotifications

final class ReminderNotificationScheduler {
    static let shared = ReminderNotificationScheduler()

    private let center: UNUserNotificationCenter
    private let requestIDPrefix = "vitamins.reminder."
    private let maxPendingRequests = 60
    private let notificationImageAssetCandidates = ["capsule2d", "capsule", "aptechka"]
    private var cachedNotificationAttachmentURL: URL?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func registerCategories() {
        let markTakenAction = UNNotificationAction(
            identifier: ReminderNotificationIdentifiers.actionMarkTaken,
            title: "Отметить прием",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "checkmark.circle")
        )

        let snooze15Action = UNNotificationAction(
            identifier: ReminderNotificationIdentifiers.actionSnooze15,
            title: "Напомнить через 15 мин",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock")
        )

        let snooze60Action = UNNotificationAction(
            identifier: ReminderNotificationIdentifiers.actionSnooze60,
            title: "Напомнить через 1 ч",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock")
        )

        let openReminderAction = UNNotificationAction(
            identifier: ReminderNotificationIdentifiers.actionOpenReminder,
            title: "Перейти к напоминанию",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.right")
        )

        let category = UNNotificationCategory(
            identifier: ReminderNotificationIdentifiers.category,
            actions: [markTakenAction, snooze15Action, snooze60Action, openReminderAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
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
            await addRequestWithAttachmentFallback(request)
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
                let bodyText = reminderNotificationBody(for: reminder, timesCount: max(1, times.count))

                return dayCodes.flatMap { dayCode in
                    times.compactMap { time in
                        makeRequest(
                            reminderID: reminder.id,
                            vitaminName: name,
                            bodyText: bodyText,
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
        bodyText: String,
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

        let content = UNMutableNotificationContent()
        content.title = reminderNotificationTitle(for: vitaminName)
        content.subtitle = "\u{00A0}"
        content.body = bodyText
        if let attachment = reminderNotificationAttachment() {
            content.attachments = [attachment]
        }
        content.sound = .default
        content.categoryIdentifier = ReminderNotificationIdentifiers.category
        content.userInfo = [
            ReminderNotificationIdentifiers.userInfoReminderID: reminderID,
            ReminderNotificationIdentifiers.userInfoReminderDay: dayCode,
            ReminderNotificationIdentifiers.userInfoReminderTime: String(format: "%02d:%02d", time.hour, time.minute)
        ]

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

    private func reminderNotificationTitle(for vitaminName: String) -> String {
        let trimmed = vitaminName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Примите витамин!" }

        if trimmed.lowercased().contains("витамин") {
            return trimmed.hasSuffix("!") ? "Примите \(trimmed)" : "Примите \(trimmed)!"
        }

        return trimmed.hasSuffix("!") ? "Примите витамин \(trimmed)" : "Примите витамин \(trimmed)!"
    }

    private func reminderNotificationBody(for reminder: ReminderRemote, timesCount: Int) -> String {
        let hint = "Удерживайте, чтобы отметить прием и увидеть дополнительную информацию"
        let dose = resolvedDoseText(for: reminder, timesCount: timesCount)
        let condition = resolvedConditionText(for: reminder)
        let interaction = resolvedInteractionText(for: reminder)
        let details = """
Дозировка: \(dose)

Условия приема: \(condition)

Взаимодействие: \(interaction)
"""
        return "\(hint)\n\n\n\n\(details)"
    }

    private func resolvedDoseText(for remote: ReminderRemote, timesCount: Int) -> String {
        let dose = remote.dose?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDose = (dose?.isEmpty == false ? dose! : "1 капсула")
        return "\(cleanDose) \(frequencyDescription(for: timesCount))"
    }

    private func resolvedConditionText(for remote: ReminderRemote) -> String {
        let prefix = humanConditionDescription(remote.condition)
        let details = remote.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [prefix, details].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? "Следуйте рекомендациям по приему." : parts.joined(separator: " ")
    }

    private func resolvedInteractionText(for remote: ReminderRemote) -> String {
        let candidates: [String?] = [
            remote.contentOverrides?.interactionTextOverride,
            remote.catalog?.interactionText,
            remote.contentOverrides?.compatibilityTextOverride,
            remote.catalog?.compatibilityText,
            remote.contentOverrides?.contraindicationsTextOverride,
            remote.catalog?.contraindicationsText
        ]

        for item in candidates {
            let trimmed = item?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Нет данных о взаимодействии."
    }

    private func humanConditionDescription(_ condition: String?) -> String? {
        switch condition?.lowercased() {
        case "before_meal":
            return "Принимать до еды."
        case "after_meal":
            return "Принимать после еды."
        case "during_meal":
            return "Принимать во время еды."
        case "any":
            return "Время приема неважно."
        default:
            return nil
        }
    }

    private func frequencyDescription(for count: Int) -> String {
        switch count {
        case 1:
            return "1 раз в день"
        case 2, 3, 4:
            return "\(count) раза в день"
        default:
            return "\(count) раз в день"
        }
    }

    private func reminderNotificationAttachment() -> UNNotificationAttachment? {
        guard let url = notificationAttachmentFileURL() else { return nil }
        return try? UNNotificationAttachment(identifier: "vitamin.image", url: url, options: nil)
    }

    private func addRequestWithAttachmentFallback(_ request: UNNotificationRequest) async {
        do {
            try await center.addAsync(request)
        } catch {
            guard let fallback = requestWithoutAttachments(request) else {
                return
            }
            try? await center.addAsync(fallback)
        }
    }

    private func requestWithoutAttachments(_ request: UNNotificationRequest) -> UNNotificationRequest? {
        guard !request.content.attachments.isEmpty,
              let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            return nil
        }
        mutableContent.attachments = []
        return UNNotificationRequest(
            identifier: request.identifier,
            content: mutableContent,
            trigger: request.trigger
        )
    }

    private func notificationAttachmentFileURL() -> URL? {
        if let cachedURL = cachedNotificationAttachmentURL,
           FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        guard let image = notificationAttachmentImage(),
              let data = image.pngData() else {
            return nil
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vitainfo-notifications", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("vitamin-notification-icon.png")
        do {
            try data.write(to: url, options: .atomic)
            cachedNotificationAttachmentURL = url
            return url
        } catch {
            return nil
        }
    }

    private func notificationAttachmentImage() -> UIImage? {
        for assetName in notificationImageAssetCandidates {
            if let image = UIImage(named: assetName) {
                return image
            }
        }
        return nil
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
