import Foundation

final class WelcomeStorage {
    private let defaults: UserDefaults
    private let key = "welcome_screen_shown_v1"
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    var shouldShowWelcome: Bool {
        !defaults.bool(forKey: key)
    }
    
    func markShown() {
        defaults.set(true, forKey: key)
    }
}
