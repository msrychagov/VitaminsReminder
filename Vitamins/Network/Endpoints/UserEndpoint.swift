import Foundation

enum UserEndpoint {
    case updateMe
}

extension UserEndpoint: Endpoint {
    var method: EndpointType {
        .put
    }

    var authorized: Bool { true }

    var queryItems: [URLQueryItem]? { nil }

    var baseURL: URL {
        URL(string: "\(NetworkClient.Constants.baseURL)/users")!
    }

    var url: URL {
        switch self {
        case .updateMe:
            return baseURL.appendingPathComponent("me")
        }
    }
}
