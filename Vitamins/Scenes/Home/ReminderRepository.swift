import Foundation

struct ReminderRemote: Decodable {
    struct Catalog: Decodable {
        let id: Int?
        let code: String?
        let displayName: String?
        let defaultUnit: String?
        let interactionText: String?
        let compatibilityText: String?
        let contraindicationsText: String?
        let defaultCondition: String?

        enum CodingKeys: String, CodingKey {
            case id
            case code
            case displayName = "display_name"
            case defaultUnit = "default_unit"
            case interactionText = "interaction_text"
            case compatibilityText = "compatibility_text"
            case contraindicationsText = "contraindications_text"
            case defaultCondition = "default_condition"
        }
    }

    struct Course: Decodable {
        let startDate: String?
        let endDate: String?
        let timezone: String?

        enum CodingKeys: String, CodingKey {
            case startDate = "start_date"
            case endDate = "end_date"
            case timezone
        }
    }

    struct Schedule: Decodable {
        let type: String?
        let days: [String]?
        var times: [String]?
    }

    struct NotificationPreferences: Decodable {
        let includeDose: Bool?
        let includeFrequency: Bool?
        let includeInteraction: Bool?
        let includeCompatibility: Bool?
        let includeCondition: Bool?
        let includeContraindications: Bool?

        enum CodingKeys: String, CodingKey {
            case includeDose = "include_dose"
            case includeFrequency = "include_frequency"
            case includeInteraction = "include_interaction"
            case includeCompatibility = "include_compatibility"
            case includeCondition = "include_condition"
            case includeContraindications = "include_contraindications"
        }
    }

    struct ContentOverrides: Decodable {
        let interactionTextOverride: String?
        let compatibilityTextOverride: String?
        let contraindicationsTextOverride: String?

        enum CodingKeys: String, CodingKey {
            case interactionTextOverride = "interaction_text_override"
            case compatibilityTextOverride = "compatibility_text_override"
            case contraindicationsTextOverride = "contraindications_text_override"
        }
    }

    let id: Int
    let catalogID: Int?
    let name: String
    let form: String?
    let dose: String?
    let condition: String?
    let note: String?
    let isActive: Bool
    let catalog: Catalog?
    let course: Course?
    var schedule: Schedule?
    let notificationPreferences: NotificationPreferences?
    let contentOverrides: ContentOverrides?

    enum CodingKeys: String, CodingKey {
        case id
        case catalogID = "catalog_id"
        case name
        case form
        case dose
        case condition
        case note
        case isActive = "is_active"
        case catalog
        case course
        case schedule
        case notificationPreferences = "notification_preferences"
        case contentOverrides = "content_overrides"
    }
}

final class ReminderRepository {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = NetworkClient()) {
        self.networkClient = networkClient
    }

    func fetchReminders() async throws -> [ReminderRemote] {
        try await networkClient.request(endpoint: VitaminsEndpoint.reminders) ?? []
    }

    func updateReminder(id: Int, request: CreateVitaminReminderRequest) async throws {
        let _: EmptyResponse? = try await networkClient.request(
            body: request,
            endpoint: VitaminsEndpoint.updateReminder(id: id)
        )
    }
}
