import Foundation

struct ReminderRemote: Decodable {
    struct Course: Decodable {
        let startDate: String?
        let timezone: String?

        enum CodingKeys: String, CodingKey {
            case startDate = "start_date"
            case timezone
        }
    }

    struct Schedule: Decodable {
        let type: String?
        let days: [String]?
        let times: [String]?
    }

    let id: Int
    let name: String
    let condition: String?
    let isActive: Bool
    let course: Course?
    let schedule: Schedule?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case condition
        case isActive = "is_active"
        case course
        case schedule
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
}
