import Foundation
import UserNotifications

@MainActor
final class ReminderNotificationResponseHandler {
    static let shared = ReminderNotificationResponseHandler()

    private let repository = ReminderRepository()
    private let completionStorage = ReminderCompletionStorage()
    private let snoozeStorage = ReminderSnoozeStorage()
    private let scheduler = ReminderNotificationScheduler.shared
    private let allWeekdays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    func handle(response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let reminderID = ReminderNotificationIdentifiers.parseReminderID(from: userInfo) else {
            return
        }

        let preferredTime = ReminderNotificationIdentifiers.parseReminderTime(from: userInfo)
        let dayCode = ReminderNotificationIdentifiers.parseReminderDay(from: userInfo)
        var properties: AnalyticsProperties = [
            "screen": "notification",
            "action_identifier": .string(response.actionIdentifier),
            "reminder_id": .int(reminderID)
        ]

        if let preferredTime, !preferredTime.isEmpty {
            properties["time"] = .string(preferredTime)
        }

        if let dayCode, !dayCode.isEmpty {
            properties["day"] = .string(dayCode)
        }

        AnalyticsService.shared.track(
            AnalyticsEventName.notificationClicked,
            properties: properties
        )

        switch response.actionIdentifier {
        case ReminderNotificationIdentifiers.actionMarkTaken:
            await markTaken(reminderID: reminderID, preferredTime: preferredTime)
        case ReminderNotificationIdentifiers.actionSnooze15:
            await snooze(reminderID: reminderID, preferredTime: preferredTime, minutes: 15)
        case ReminderNotificationIdentifiers.actionSnooze60:
            await snooze(reminderID: reminderID, preferredTime: preferredTime, minutes: 60)
        case ReminderNotificationIdentifiers.actionOpenReminder, UNNotificationDefaultActionIdentifier:
            await MainActor.run {
                ReminderNotificationRouter.shared.enqueue(
                    .init(reminderID: reminderID, preferredTime: preferredTime, dayCode: dayCode)
                )
            }
        default:
            break
        }
    }

    private func markTaken(reminderID: Int, preferredTime: String?) async {
        guard
            let reminders = try? await repository.fetchReminders(),
            let reminder = reminders.first(where: { $0.id == reminderID })
        else {
            return
        }

        let request = makeUpdateRequest(from: reminder, fallbackTime: preferredTime ?? "09:00")
        try? await repository.updateReminder(id: reminder.id, request: request)

        if let takenID = makeTakenID(for: reminder, preferredTime: preferredTime) {
            var takenIDs = completionStorage.load()
            takenIDs.insert(takenID)
            completionStorage.save(takenIDs)
        }

        await scheduler.schedule(from: reminders)
    }

    private func snooze(reminderID: Int, preferredTime: String?, minutes: Int) async {
        guard let reminders = try? await repository.fetchReminders(),
              let reminder = reminders.first(where: { $0.id == reminderID }) else {
            return
        }

        let timezoneID = reminder.course?.timezone
        let scheduleTimes = normalizedTimes(reminder.schedule?.times, fallback: preferredTime ?? "09:00")
        let sourceTime = canonicalTime(preferredTime ?? "") ?? scheduleTimes.first ?? "09:00"
        let sourceIndex = scheduleTimes.firstIndex(of: sourceTime) ?? 0

        let today = Date()
        let scheduledFor = ReminderTimeFormatters.makeRFC3339(
            date: today,
            time: sourceTime,
            timezoneID: timezoneID
        )

        do {
            let response = try await repository.snoozeOccurrence(
                id: reminder.id,
                scheduledFor: scheduledFor,
                minutes: minutes
            )
            guard let snoozedUntilDate = ReminderTimeFormatters.parseRFC3339(response.snoozedUntil) else { return }

            let sourceDate = ReminderTimeFormatters.slotDateString(today, timezoneID: timezoneID)
            let scheduledDate = ReminderTimeFormatters.slotDateString(snoozedUntilDate, timezoneID: timezoneID)
            let scheduledTime = ReminderTimeFormatters.slotTimeString(snoozedUntilDate, timezoneID: timezoneID)

            var overrides = snoozeStorage.load()
            let entry = ReminderSnoozeEntry(
                reminderID: reminder.id,
                sourceDate: sourceDate,
                sourceTime: sourceTime,
                sourceIndex: sourceIndex,
                scheduledDate: scheduledDate,
                scheduledTime: scheduledTime
            )
            overrides[entry.occurrenceID] = entry
            snoozeStorage.save(overrides)

            await scheduler.schedule(from: reminders, overrides: overrides)
        } catch {
            // ignore — пользователь увидит старое поведение
        }
    }

    private func makeUpdateRequest(from remote: ReminderRemote, fallbackTime: String) -> CreateVitaminReminderRequest {
        let scheduleTimes = normalizedTimes(remote.schedule?.times, fallback: fallbackTime)
        let rawDays = remote.schedule?.days?.map { $0.lowercased() } ?? []
        let scheduleDays = rawDays.isEmpty ? allWeekdays : rawDays

        return CreateVitaminReminderRequest(
            catalogID: remote.catalogID,
            name: nonEmpty(remote.name),
            form: nonEmpty(remote.form) ?? "capsule",
            dose: nonEmpty(remote.dose) ?? "1",
            condition: nonEmpty(remote.condition) ?? "any",
            note: remote.note ?? "",
            course: .init(
                startDate: remote.course?.startDate ?? isoDateString(for: Date()),
                endDate: remote.course?.endDate,
                timezone: remote.course?.timezone ?? TimeZone.current.identifier
            ),
            schedule: .init(
                days: scheduleDays,
                times: scheduleTimes
            ),
            notificationPreferences: .init(
                includeDose: remote.notificationPreferences?.includeDose ?? true,
                includeFrequency: remote.notificationPreferences?.includeFrequency ?? true,
                includeInteraction: remote.notificationPreferences?.includeInteraction ?? true,
                includeCompatibility: remote.notificationPreferences?.includeCompatibility ?? true,
                includeCondition: remote.notificationPreferences?.includeCondition ?? true,
                includeContraindications: remote.notificationPreferences?.includeContraindications ?? true
            ),
            contentOverrides: .init(
                interactionTextOverride: remote.contentOverrides?.interactionTextOverride,
                compatibilityTextOverride: remote.contentOverrides?.compatibilityTextOverride,
                contraindicationsTextOverride: remote.contentOverrides?.contraindicationsTextOverride
            )
        )
    }

    private func makeTakenID(for remote: ReminderRemote, preferredTime: String?) -> String? {
        let time = canonicalTime(preferredTime ?? "") ?? normalizedTimes(remote.schedule?.times, fallback: "09:00").first
        guard let time else { return nil }

        let datePart = isoDateString(for: Date())
        let scheduleTimes = normalizedTimes(remote.schedule?.times, fallback: time)
        let index = scheduleTimes.firstIndex(of: time) ?? 0
        return "\(remote.id)-\(datePart)-\(time)-\(index)"
    }

    private func normalizedTimes(_ source: [String]?, fallback: String) -> [String] {
        let parsed = (source ?? []).compactMap(canonicalTime)
        var unique: [String] = []
        var seen = Set<String>()

        for time in parsed where seen.insert(time).inserted {
            unique.append(time)
        }

        if unique.isEmpty, let fallbackTime = canonicalTime(fallback) {
            unique = [fallbackTime]
        }

        return unique
    }

    private func canonicalTime(_ raw: String) -> String? {
        let components = raw.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func shiftedTime(_ time: String, by minutes: Int) -> String {
        guard let baseMinutes = minutesFromMidnight(time) else { return time }
        let total = (baseMinutes + minutes + 1440) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func minutesFromMidnight(_ raw: String) -> Int? {
        let components = raw.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }

    private func isoDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
