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

final class PostRegistrationOnboardingStorage {
    private let defaults: UserDefaults
    private let key = "post_registration_onboarding_pending_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldPresentOnboarding: Bool {
        defaults.bool(forKey: key)
    }

    func markPending() {
        defaults.set(true, forKey: key)
    }

    func markCompleted() {
        defaults.set(false, forKey: key)
    }
}
