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
    private let snoozeStorage: ReminderSnoozeStorage

    init(
        networkClient: NetworkClient = NetworkClient(),
        snoozeStorage: ReminderSnoozeStorage = ReminderSnoozeStorage()
    ) {
        self.networkClient = networkClient
        self.snoozeStorage = snoozeStorage
    }

    func fetchReminders() async throws -> [ReminderRemote] {
        try await networkClient.request(endpoint: VitaminsEndpoint.reminders) ?? []
    }

    func updateReminder(id: Int, request: CreateVitaminReminderRequest) async throws {
        let _: EmptyResponse? = try await networkClient.request(
            body: request,
            endpoint: VitaminsEndpoint.updateReminder(id: id)
        )
        // Бэк не чистит exceptions при PATCH — удаляем локально, чтобы не было мусорных overrides.
        var overrides = snoozeStorage.load()
        let filtered = overrides.filter { $0.value.reminderID != id }
        if filtered.count != overrides.count {
            snoozeStorage.save(filtered)
        }
    }

    func deleteReminder(id: Int) async throws {
        let _: EmptyResponse? = try await networkClient.request(
            endpoint: VitaminsEndpoint.deleteReminder(id: id)
        )
    }

    @discardableResult
    func markIntake(reminderID: Int, scheduledFor: String) async throws -> MarkIntakeResponse? {
        try await networkClient.request(
            body: MarkIntakeRequest(scheduledFor: scheduledFor),
            endpoint: VitaminsEndpoint.markIntake(id: reminderID)
        )
    }

    func unmarkIntake(reminderID: Int, scheduledFor: String) async throws {
        let _: EmptyResponse? = try await networkClient.request(
            endpoint: VitaminsEndpoint.unmarkIntake(id: reminderID, scheduledFor: scheduledFor)
        )
    }

    func snoozeOccurrence(
        id: Int,
        scheduledFor: String,
        minutes: Int
    ) async throws -> SnoozeOccurrenceResponse {
        let body = SnoozeOccurrenceRequest(scheduledFor: scheduledFor, minutes: minutes, snoozedUntil: nil)
        guard let response: SnoozeOccurrenceResponse = try await networkClient.request(
            body: body,
            endpoint: VitaminsEndpoint.snoozeOccurrence(id: id)
        ) else {
            throw APIError.unexpectedStatusCode(URLResponse())
        }
        return response
    }

    func fetchMonthStats(month: String, timezone: String) async throws -> MonthStatsResponse? {
        try await networkClient.request(
            endpoint: VitaminsEndpoint.monthStats(month: month, timezone: timezone)
        )
    }

    func fetchMonthStatsWithReminders(month: String, timezone: String) async throws -> MonthStatsRemindersResponse? {
        try await networkClient.request(
            endpoint: VitaminsEndpoint.monthStatsReminders(month: month, timezone: timezone)
        )
    }
}

struct MonthStatsRemindersResponse: Decodable {
    let selectedMonth: String
    let summary: MonthStatsResponse
    let items: [ReminderStatsItem]

    enum CodingKeys: String, CodingKey {
        case selectedMonth = "selected_month"
        case summary
        case items
    }
}

struct ReminderStatsItem: Decodable, Identifiable, Hashable {
    let reminderID: Int
    let name: String
    let completionPercent: Double
    let takenCount: Int
    let missedCount: Int
    let remainingCount: Int
    let status: String

    var id: Int { reminderID }

    enum CodingKeys: String, CodingKey {
        case reminderID = "reminder_id"
        case name
        case completionPercent = "completion_percent"
        case takenCount = "taken_count"
        case missedCount = "missed_count"
        case remainingCount = "remaining_count"
        case status
    }
}

struct MarkIntakeRequest: Encodable {
    let scheduledFor: String

    enum CodingKeys: String, CodingKey {
        case scheduledFor = "scheduled_for"
    }
}

struct MarkIntakeResponse: Decodable {
    let id: Int
    let reminderID: Int
    let scheduledFor: String
    let takenAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case reminderID = "reminder_id"
        case scheduledFor = "scheduled_for"
        case takenAt = "taken_at"
    }
}

struct SnoozeOccurrenceRequest: Encodable {
    let scheduledFor: String
    let minutes: Int?
    let snoozedUntil: String?

    enum CodingKeys: String, CodingKey {
        case scheduledFor = "scheduled_for"
        case minutes
        case snoozedUntil = "snoozed_until"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduledFor, forKey: .scheduledFor)
        if let minutes { try container.encode(minutes, forKey: .minutes) }
        if let snoozedUntil { try container.encode(snoozedUntil, forKey: .snoozedUntil) }
    }
}

struct SnoozeOccurrenceResponse: Decodable {
    let reminderID: Int
    let scheduledFor: String
    let snoozedUntil: String

    enum CodingKeys: String, CodingKey {
        case reminderID = "reminder_id"
        case scheduledFor = "scheduled_for"
        case snoozedUntil = "snoozed_until"
    }
}

struct MonthStatsResponse: Decodable {
    let completionPercent: Double
    let takenDays: Int
    let missedDays: Int
    let remainingDays: Int
    let selectedMonth: String
    let status: String
    let pie: [PieSlice]

    struct PieSlice: Decodable, Hashable {
        let label: String
        let value: Double
    }

    enum CodingKeys: String, CodingKey {
        case completionPercent = "completion_percent"
        case takenDays = "taken_days"
        case missedDays = "missed_days"
        case remainingDays = "remaining_days"
        case selectedMonth = "selected_month"
        case status
        case pie
    }
}
