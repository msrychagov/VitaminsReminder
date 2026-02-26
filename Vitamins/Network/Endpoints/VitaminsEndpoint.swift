import Foundation

enum VitaminsEndpoint {
    case list
    case catalog
    case reminders
    case createReminder
    case updateReminder(id: Int)
}

extension VitaminsEndpoint: Endpoint {
    var method: EndpointType {
        switch self {
        case .createReminder:
            return .post
        case .updateReminder:
            return .patch
        case .list, .catalog, .reminders:
            return .get
        }
    }
    var authorized: Bool { true }
    var queryItems: [URLQueryItem]? { nil }

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
        case .updateReminder(let id):
            baseURL.appendingPathComponent("reminders").appendingPathComponent(String(id))
        }
    }
}
