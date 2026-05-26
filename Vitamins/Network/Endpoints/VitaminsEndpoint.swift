import Foundation

enum VitaminsEndpoint {
    case list
    case catalog
    case reminders
    case createReminder
    case updateReminder(id: Int)
    case deleteReminder(id: Int)
    case markIntake(id: Int)
    case unmarkIntake(id: Int, scheduledFor: String)
    case snoozeOccurrence(id: Int)
    case monthStats(month: String, timezone: String)
    case monthStatsReminders(month: String, timezone: String)
}

extension VitaminsEndpoint: Endpoint {
    var method: EndpointType {
        switch self {
        case .createReminder, .snoozeOccurrence:
            return .post
        case .updateReminder:
            return .patch
        case .deleteReminder, .unmarkIntake:
            return .delete
        case .markIntake:
            return .put
        case .list, .catalog, .reminders, .monthStats, .monthStatsReminders:
            return .get
        }
    }
    var authorized: Bool { true }
    var queryItems: [URLQueryItem]? {
        switch self {
        case .unmarkIntake(_, let scheduledFor):
            return [URLQueryItem(name: "scheduled_for", value: scheduledFor)]
        case .monthStats(let month, let timezone),
             .monthStatsReminders(let month, let timezone):
            return [
                URLQueryItem(name: "month", value: month),
                URLQueryItem(name: "timezone", value: timezone)
            ]
        default:
            return nil
        }
    }

    var baseURL: URL {
        URL(string: "\(NetworkClient.Constants.baseURL)/vitamins")!
    }

    var url: URL {
        switch self {
        case .list:
            baseURL
        case .catalog:
            baseURL.appendingPathComponent("catalog")
        case .reminders, .createReminder:
            baseURL.appendingPathComponent("reminders")
        case .updateReminder(let id), .deleteReminder(let id):
            baseURL.appendingPathComponent("reminders").appendingPathComponent(String(id))
        case .markIntake(let id), .unmarkIntake(let id, _):
            baseURL.appendingPathComponent("reminders").appendingPathComponent(String(id)).appendingPathComponent("intakes")
        case .snoozeOccurrence(let id):
            baseURL
                .appendingPathComponent("reminders")
                .appendingPathComponent(String(id))
                .appendingPathComponent("occurrences")
                .appendingPathComponent("snooze")
        case .monthStats:
            baseURL.appendingPathComponent("intakes").appendingPathComponent("stats").appendingPathComponent("month")
        case .monthStatsReminders:
            baseURL.appendingPathComponent("intakes").appendingPathComponent("stats").appendingPathComponent("reminders")
        }
    }
}
