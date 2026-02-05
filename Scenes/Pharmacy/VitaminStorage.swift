import Foundation

final class VitaminStorage {
    private let defaults: UserDefaults
    private let cacheKey = "cached_vitamins"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ vitamins: [Vitamin]) {
        guard let data = try? JSONEncoder().encode(vitamins) else { return }
        defaults.set(data, forKey: cacheKey)
    }

    func load() -> [Vitamin] {
        guard
            let data = defaults.data(forKey: cacheKey),
            let vitamins = try? JSONDecoder().decode([Vitamin].self, from: data)
        else {
            return []
        }
        return vitamins
    }
}
