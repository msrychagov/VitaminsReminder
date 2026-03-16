import Foundation

enum AnalyticsEventName {
    static let registerStart = "auth.register_start"
    static let registerSuccess = "auth.register_success"
    static let loginSuccess = "auth.login_success"
    static let loginFailed = "auth.login_failed"
    static let logout = "auth.logout"
    static let refreshSuccess = "auth.refresh_success"
    static let refreshFailed = "auth.refresh_failed"

    static let passwordResetRequested = "password_reset.requested"
    static let passwordResetCodeSent = "password_reset.code_sent"
    static let passwordResetVerifySuccess = "password_reset.verify_success"
    static let passwordResetVerifyFailed = "password_reset.verify_failed"
    static let passwordResetConfirmSuccess = "password_reset.confirm_success"
    static let passwordResetConfirmFailed = "password_reset.confirm_failed"

    static let profileViewed = "profile.viewed"
    static let profileUpdated = "profile.updated"
    static let profileEmailChanged = "profile.email_changed"
    static let profileNameChanged = "profile.name_changed"

    static let catalogOpened = "catalog.opened"
    static let catalogSearch = "catalog.search"
    static let catalogItemOpened = "catalog.item_opened"

    static let wizardStarted = "wizard.started"
    static let wizardStep1Completed = "wizard.step1_completed"
    static let wizardStep2Completed = "wizard.step2_completed"
    static let wizardStep3Completed = "wizard.step3_completed"
    static let wizardAbandoned = "wizard.abandoned"

    static let reminderCreated = "vitamins.reminder_created"
    static let reminderUpdated = "vitamins.reminder_updated"
    static let reminderDeleted = "vitamins.reminder_deleted"
    static let reminderEnabled = "vitamins.reminder_enabled"
    static let reminderDisabled = "vitamins.reminder_disabled"

    static let scheduleTimeAdded = "schedule.time_added"
    static let scheduleTimeRemoved = "schedule.time_removed"
    static let scheduleDaysChanged = "schedule.days_changed"
    static let scheduleEverydaySelected = "schedule.everyday_selected"

    static let notificationSettingsOpened = "notification.settings_opened"
    static let notificationPreferencesChanged = "notification.preferences_changed"
    static let notificationOverrideEdited = "notification.override_edited"
    static let notificationClicked = "notification.clicked"

    static let apiError = "api.error"
    static let appError = "app.error"
}
