import Foundation

enum VitaminsEndpoint {
    case list
    case reminders
    case createReminder
}

extension VitaminsEndpoint: Endpoint {
    var method: EndpointType {
        switch self {
        case .createReminder:
            return .post
        case .list, .reminders:
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
        case .reminders, .createReminder:
            baseURL.appendingPathComponent("reminders")
        }
    }
}
