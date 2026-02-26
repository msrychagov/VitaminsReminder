import Foundation

final class ReminderCompletionStorage {
    private let defaults: UserDefaults
    private let cacheKey = "taken_reminder_ids_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Set<String> {
        let ids = defaults.stringArray(forKey: cacheKey) ?? []
        return Set(ids)
    }

    func save(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: cacheKey)
    }
}
