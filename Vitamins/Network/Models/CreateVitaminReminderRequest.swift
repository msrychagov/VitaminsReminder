import Foundation

struct CreateVitaminReminderRequest: Encodable {
    struct Course: Encodable {
        let startDate: String
        let endDate: String?
        let timezone: String

        enum CodingKeys: String, CodingKey {
            case startDate = "start_date"
            case endDate = "end_date"
            case timezone
        }
    }

    struct Schedule: Encodable {
        let days: [String]
        let times: [String]
    }

    struct NotificationPreferences: Encodable {
        let includeDose: Bool
        let includeFrequency: Bool
        let includeInteraction: Bool
        let includeCompatibility: Bool
        let includeCondition: Bool
        let includeContraindications: Bool

        enum CodingKeys: String, CodingKey {
            case includeDose = "include_dose"
            case includeFrequency = "include_frequency"
            case includeInteraction = "include_interaction"
            case includeCompatibility = "include_compatibility"
            case includeCondition = "include_condition"
            case includeContraindications = "include_contraindications"
        }
    }

    struct ContentOverrides: Encodable {
        let interactionTextOverride: String?
        let compatibilityTextOverride: String?
        let contraindicationsTextOverride: String?

        enum CodingKeys: String, CodingKey {
            case interactionTextOverride = "interaction_text_override"
            case compatibilityTextOverride = "compatibility_text_override"
            case contraindicationsTextOverride = "contraindications_text_override"
        }
    }

    let catalogID: Int?
    let name: String?
    let form: String
    let dose: String
    let condition: String
    let note: String
    let course: Course
    let schedule: Schedule
    let notificationPreferences: NotificationPreferences
    let contentOverrides: ContentOverrides

    enum CodingKeys: String, CodingKey {
        case catalogID = "catalog_id"
        case name
        case form
        case dose
        case condition
        case note
        case course
        case schedule
        case notificationPreferences = "notification_preferences"
        case contentOverrides = "content_overrides"
    }
}
