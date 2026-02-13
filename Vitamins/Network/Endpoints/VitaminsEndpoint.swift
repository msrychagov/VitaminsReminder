import Foundation

enum VitaminsEndpoint {
    case list
    case reminders
}

extension VitaminsEndpoint: Endpoint {
    var method: EndpointType { .get }
    var authorized: Bool { true }
    var queryItems: [URLQueryItem]? { nil }

    var baseURL: URL {
        URL(string: "\(NetworkClient.Constants.baseURL)/vitamins")!
    }

    var url: URL {
        switch self {
        case .list:
            baseURL
        case .reminders:
            baseURL.appendingPathComponent("reminders")
        }
    }
}
