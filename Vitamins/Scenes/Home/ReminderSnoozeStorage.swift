import Foundation

struct ReminderSnoozeEntry: Codable, Equatable {
    let occurrenceID: String
    let reminderID: Int
    let sourceDate: String
    let sourceTime: String
    let sourceIndex: Int
    let scheduledDate: String
    let scheduledTime: String

    init(
        reminderID: Int,
        sourceDate: String,
        sourceTime: String,
        sourceIndex: Int,
        scheduledDate: String,
        scheduledTime: String
    ) {
        self.occurrenceID = Self.makeOccurrenceID(
            reminderID: reminderID,
            sourceDate: sourceDate,
            sourceTime: sourceTime,
            sourceIndex: sourceIndex
        )
        self.reminderID = reminderID
        self.sourceDate = sourceDate
        self.sourceTime = sourceTime
        self.sourceIndex = sourceIndex
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
    }

    static func makeOccurrenceID(
        reminderID: Int,
        sourceDate: String,
        sourceTime: String,
        sourceIndex: Int
    ) -> String {
        "\(reminderID)-\(sourceDate)-\(sourceTime)-\(sourceIndex)"
    }
}

final class ReminderSnoozeStorage {
    private let defaults: UserDefaults
    private let cacheKey = "snoozed_reminder_occurrences_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String: ReminderSnoozeEntry] {
        guard let data = defaults.data(forKey: cacheKey),
              let entries = try? JSONDecoder().decode([ReminderSnoozeEntry].self, from: data) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: entries.map { ($0.occurrenceID, $0) })
    }

    func save(_ entries: [String: ReminderSnoozeEntry]) {
        let sortedEntries = entries.values.sorted { $0.occurrenceID < $1.occurrenceID }
        guard let data = try? JSONEncoder().encode(sortedEntries) else { return }
        defaults.set(data, forKey: cacheKey)
    }
}
