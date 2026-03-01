import Foundation

struct UserProfile: Codable, Equatable {
    var firstName: String
    var lastName: String
    var email: String
    var imageData: Data?

    static let empty = UserProfile(firstName: "", lastName: "", email: "", imageData: nil)
}

extension Notification.Name {
    static let userProfileDidChange = Notification.Name("user_profile_did_change")
}

final class UserProfileStorage {
    private let defaults: UserDefaults
    private let cacheKey = "user_profile_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserProfile {
        guard
            let data = defaults.data(forKey: cacheKey),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else {
            return .empty
        }

        return profile
    }

    func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: cacheKey)
        NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
    }

    func updateImageData(_ imageData: Data?) {
        var profile = load()
        profile.imageData = imageData
        save(profile)
    }

    func upsert(email: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else { return }
        var profile = load()
        profile.email = cleanEmail
        save(profile)
    }

    func clear() {
        defaults.removeObject(forKey: cacheKey)
        NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
    }
}
