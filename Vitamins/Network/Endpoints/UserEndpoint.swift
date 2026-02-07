import Foundation

enum UserEndpoint {
    case fetchMe
    case updateMe
}

extension UserEndpoint: Endpoint {
    var method: EndpointType {
        switch self {
        case .fetchMe: return .get
        case .updateMe: return .patch
        }
    }

    var authorized: Bool { true }

    var queryItems: [URLQueryItem]? { nil }

    var baseURL: URL {
        URL(string: "\(NetworkClient.Constants.baseURL)/users")!
    }

    var url: URL {
        switch self {
        case .fetchMe:
            return baseURL.appendingPathComponent("me")
        case .updateMe:
            return baseURL.appendingPathComponent("me")
        }
    }
}
