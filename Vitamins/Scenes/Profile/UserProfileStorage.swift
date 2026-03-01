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
    private let avatarFileNameKey = "user_profile_avatar_filename_v1"
    private let avatarDirectoryName = "user_profile"
    private let avatarFileName = "avatar.jpg"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserProfile {
        var profile = UserProfile.empty

        guard
            let data = defaults.data(forKey: cacheKey),
            let decoded = try? JSONDecoder().decode(UserProfile.self, from: data)
        else {
            return loadAvatarData(into: profile)
        }

        profile = decoded
        return loadAvatarData(into: profile)
    }

    func save(_ profile: UserProfile) {
        persistAvatarData(profile.imageData)

        var snapshot = profile
        snapshot.imageData = nil

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
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
        defaults.removeObject(forKey: avatarFileNameKey)
        if let url = avatarFileURL(), FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        NotificationCenter.default.post(name: .userProfileDidChange, object: nil)
    }

    private func loadAvatarData(into profile: UserProfile) -> UserProfile {
        guard
            let url = avatarFileURL(),
            let imageData = try? Data(contentsOf: url)
        else {
            return profile
        }

        var updated = profile
        updated.imageData = imageData
        return updated
    }

    private func persistAvatarData(_ data: Data?) {
        guard let data, !data.isEmpty else {
            defaults.removeObject(forKey: avatarFileNameKey)
            if let url = avatarFileURL(), FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            return
        }

        guard let directory = avatarDirectoryURL() else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(avatarFileName)
        do {
            try data.write(to: url, options: .atomic)
            defaults.set(avatarFileName, forKey: avatarFileNameKey)
        } catch {
            return
        }
    }

    private func avatarDirectoryURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(avatarDirectoryName, isDirectory: true)
    }

    private func avatarFileURL() -> URL? {
        guard let fileName = defaults.string(forKey: avatarFileNameKey),
              !fileName.isEmpty,
              let directory = avatarDirectoryURL() else {
            return nil
        }
        return directory.appendingPathComponent(fileName)
    }
}
