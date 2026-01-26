import Foundation

enum NetworkClientErrors: Error {
    case malformedURL
    case incorrectURL
    case requestError
}

enum APIError: Error {
    case nonHTTPResponse
    case unexpectedStatusCode(URLResponse)
    case badRequest(Data?)
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case unprocessableEntity(Data?)
    case serverError(code: Int)
    case decodingError(Error)
}

enum SerializationErrors: Error {
    case encodingError
    case decodingError
}
