import Foundation

protocol Endpoint {
    var method: EndpointType { get }
    var authorized: Bool { get }
    var queryItems: [URLQueryItem]? { get }
    var baseURL: URL { get }
    var url: URL { get }
}

enum EndpointType: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
