import Foundation

enum VitaminsEndpoint {
    case list
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
        }
    }
}
