import Foundation

struct NetworkClient {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }
    
    func request<RequestBody: Encodable, ResponseBody: Decodable>(
        body: RequestBody? = nil,
        endpoint: Endpoint
    ) async throws -> ResponseBody? {
        guard var components = URLComponents(url: endpoint.url, resolvingAgainstBaseURL: false) else {
            throw NetworkClientErrors.malformedURL
        }
        
        components.queryItems = endpoint.queryItems
        
        guard let url = components.url else {
            throw NetworkClientErrors.incorrectURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
//        if endpoint.authorized {
//            request.setValue("Bearer \(Constants.token)", forHTTPHeaderField: "Authorization")
//        }
        
        if let body = body {
            do {
                request.httpBody = try await Task.detached(priority: .background) {
                    try encoder.encode(body)
                }.value
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw SerializationErrors.encodingError
            }
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkClientErrors.requestError
        }
        
        switch httpResponse.statusCode {
        case 204:
            return nil
        case 200..<300:
            do {
                return try await Task.detached(priority: .background) {
                    try decoder.decode(ResponseBody.self, from: data)
                }.value
            } catch {
                throw SerializationErrors.decodingError
            }
        case 400:
            throw APIError.badRequest(data)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 409:
            throw APIError.conflict
        case 422:
            throw APIError.unprocessableEntity(data)
        case 500..<600:
            throw APIError.serverError(code: httpResponse.statusCode)
        default:
            throw APIError.unexpectedStatusCode(response)
        }
    }
    
    func request<ResponseBody: Decodable>(endpoint: Endpoint) async throws -> ResponseBody? {
        try await request(body: Optional<EmptyRequest>.none, endpoint: endpoint)
    }
}
