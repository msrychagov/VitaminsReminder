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

                let timesCount = max(1, times.count)
                let bodyText = reminderNotificationBody(for: reminder, timesCount: timesCount)

                let preferences = reminder.notificationPreferences

                let dosePerIntakeText: String? = (preferences?.includeDose ?? true) ? resolvedDosePerIntakeText(for: reminder) : nil
                let frequencyText: String? = (preferences?.includeFrequency ?? true) ? resolvedFrequencyText(timesCount: timesCount) : nil
                let noteText: String? = resolvedNoteTextOnly(for: reminder)
                let conditionText: String? = (preferences?.includeCondition ?? true) ? resolvedConditionTextOnly(for: reminder) : nil
                let interactionText: String? = (preferences?.includeInteraction ?? true) ? resolvedInteractionTextOnly(for: reminder) : nil
                let compatibilityText: String? = (preferences?.includeCompatibility ?? true) ? resolvedCompatibilityTextOnly(for: reminder) : nil
                let contraindicationsText: String? = (preferences?.includeContraindications ?? true) ? resolvedContraindicationsTextOnly(for: reminder) : nil

                let instructionText = "Удерживайте, чтобы отметить прием и увидеть дополнительную информацию"

                return dayCodes.flatMap { dayCode in
                    times.compactMap { time in
                        makeRequest(
                            reminderID: reminder.id,
                            vitaminName: name,
                            bodyText: bodyText,
                            dosePerIntakeText: dosePerIntakeText,
                            frequencyText: frequencyText,
                            noteText: noteText,
                            conditionText: conditionText,
                            interactionText: interactionText,
                            compatibilityText: compatibilityText,
                            contraindicationsText: contraindicationsText,
                            instructionText: instructionText,
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
        dosePerIntakeText: String?,
        frequencyText: String?,
        noteText: String?,
        conditionText: String?,
        interactionText: String?,
        compatibilityText: String?,
        contraindicationsText: String?,
        instructionText: String?,
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
        content.subtitle = ""
        content.body = bodyText
        if let attachment = reminderNotificationAttachment() {
            content.attachments = [attachment]
        }
        content.sound = .default
        content.categoryIdentifier = ReminderNotificationIdentifiers.category

        var userInfo: [AnyHashable: Any] = [
            ReminderNotificationIdentifiers.userInfoReminderID: reminderID,
            ReminderNotificationIdentifiers.userInfoReminderDay: dayCode,
            ReminderNotificationIdentifiers.userInfoReminderTime: String(format: "%02d:%02d", time.hour, time.minute)
        ]

        if let dosePerIntakeText { userInfo["reminder_dose_per_intake_text"] = dosePerIntakeText }
        if let frequencyText { userInfo["reminder_frequency_text"] = frequencyText }
        if let noteText { userInfo["reminder_note_text"] = noteText }
        if let conditionText { userInfo["reminder_condition_text"] = conditionText }
        if let interactionText { userInfo["reminder_interaction_text"] = interactionText }
        if let compatibilityText { userInfo["reminder_compatibility_text"] = compatibilityText }
        if let contraindicationsText { userInfo["reminder_contraindications_text"] = contraindicationsText }
        if let instructionText { userInfo["reminder_instruction_text"] = instructionText }

        content.userInfo = userInfo

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

    private func reminderNotificationBody(for _: ReminderRemote, timesCount _: Int) -> String {
        "Удерживайте, чтобы отметить прием и увидеть дополнительную информацию"
    }

    private func resolvedDosePerIntakeText(for remote: ReminderRemote) -> String {
        let dose = remote.dose?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (dose?.isEmpty == false ? dose! : "1 капсула")
    }

    private func resolvedFrequencyText(timesCount: Int) -> String {
        frequencyDescription(for: timesCount)
    }

    private func resolvedConditionTextOnly(for remote: ReminderRemote) -> String {
        humanConditionDescription(remote.condition) ?? "Следуйте рекомендациям по приему."
    }

    private func resolvedNoteTextOnly(for remote: ReminderRemote) -> String? {
        let note = remote.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let note, !note.isEmpty else { return nil }
        return note
    }

    private func resolvedInteractionTextOnly(for remote: ReminderRemote) -> String {
        let s = remote.contentOverrides?.interactionTextOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? remote.catalog?.interactionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false ? s! : "Нет данных о взаимодействии.")
    }

    private func resolvedCompatibilityTextOnly(for remote: ReminderRemote) -> String {
        let s = remote.contentOverrides?.compatibilityTextOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? remote.catalog?.compatibilityText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false ? s! : "Нет данных о совместимости.")
    }

    private func resolvedContraindicationsTextOnly(for remote: ReminderRemote) -> String {
        let s = remote.contentOverrides?.contraindicationsTextOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? remote.catalog?.contraindicationsText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false ? s! : "Нет данных о противопоказаниях.")
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
