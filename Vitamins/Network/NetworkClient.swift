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
        let request = try await makeURLRequest(body: body, endpoint: endpoint)
        return try await performRequest(
            request,
            endpoint: endpoint,
            allowsRetryAfterRefresh: endpoint.authorized
        )
    }
    
    func request<ResponseBody: Decodable>(endpoint: Endpoint) async throws -> ResponseBody? {
        try await request(body: Optional<EmptyRequest>.none, endpoint: endpoint)
    }

    private func makeURLRequest<RequestBody: Encodable>(
        body: RequestBody?,
        endpoint: Endpoint
    ) async throws -> URLRequest {
        guard var components = URLComponents(url: endpoint.url, resolvingAgainstBaseURL: false) else {
            throw NetworkClientErrors.malformedURL
        }

        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw NetworkClientErrors.incorrectURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        if endpoint.authorized, let token = TokenStorage.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
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
        return request
    }

    private func performRequest<ResponseBody: Decodable>(
        _ request: URLRequest,
        endpoint: Endpoint,
        allowsRetryAfterRefresh: Bool
    ) async throws -> ResponseBody? {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkClientErrors.requestError
        }

        if httpResponse.statusCode == 401, endpoint.authorized, allowsRetryAfterRefresh {
            do {
                let newAccessToken = try await TokenRefreshCoordinator.shared.refreshAccessToken(
                    using: encoder,
                    decoder: decoder
                )
                var retriedRequest = request
                retriedRequest.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
                return try await performRequest(
                    retriedRequest,
                    endpoint: endpoint,
                    allowsRetryAfterRefresh: false
                )
            } catch APIError.unauthorized {
                throw APIError.unauthorized
            } catch {
                throw error
            }
        }

        return try await decodeResponse(
            data: data,
            response: response,
            httpResponse: httpResponse
        )
    }

    private func decodeResponse<ResponseBody: Decodable>(
        data: Data,
        response: URLResponse,
        httpResponse: HTTPURLResponse
    ) async throws -> ResponseBody? {
        switch httpResponse.statusCode {
        case 204:
            return nil
        case 200..<300:
            if data.isEmpty {
                return nil
            }
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
}

private actor TokenRefreshCoordinator {
    static let shared = TokenRefreshCoordinator()

    private var refreshTask: Task<String, Error>?

    func refreshAccessToken(using encoder: JSONEncoder, decoder: JSONDecoder) async throws -> String {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<String, Error> {
            try await Self.performRefresh(using: encoder, decoder: decoder)
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private static func performRefresh(using encoder: JSONEncoder, decoder: JSONDecoder) async throws -> String {
        guard let rawRefreshToken = TokenStorage.refreshToken else {
            TokenStorage.clear()
            throw APIError.unauthorized
        }

        let refreshToken = rawRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !refreshToken.isEmpty else {
            TokenStorage.clear()
            throw APIError.unauthorized
        }

        guard let url = URL(string: "\(NetworkClient.Constants.baseURL)/auth/refresh") else {
            throw NetworkClientErrors.incorrectURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = EndpointType.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try encoder.encode(RefreshTokenRequest(refreshToken: refreshToken))
        } catch {
            throw SerializationErrors.encodingError
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkClientErrors.requestError
        }

        switch httpResponse.statusCode {
        case 200..<300:
            let decoded: RefreshTokenResponse
            do {
                decoded = try await Task.detached(priority: .background) {
                    try decoder.decode(RefreshTokenResponse.self, from: data)
                }.value
            } catch {
                throw SerializationErrors.decodingError
            }

            let normalizedRefresh = decoded.refreshToken?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let nextRefreshToken = {
                if let normalizedRefresh, !normalizedRefresh.isEmpty {
                    return normalizedRefresh
                }
                return refreshToken
            }()

            TokenStorage.save(accessToken: decoded.accessToken, refreshToken: nextRefreshToken)
            return decoded.accessToken
        case 400:
            throw APIError.badRequest(data)
        case 401, 403:
            TokenStorage.clear()
            throw APIError.unauthorized
        case 422:
            throw APIError.unprocessableEntity(data)
        case 500..<600:
            throw APIError.serverError(code: httpResponse.statusCode)
        default:
            throw APIError.unexpectedStatusCode(response)
        }
    }
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken
        case refreshTokenSnake = "refresh_token"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(refreshToken, forKey: .refreshTokenSnake)
    }
}

private struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case token
        case access_token
        case refresh_token
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawAccessToken =
            try container.decodeIfPresent(String.self, forKey: .accessToken) ??
            container.decodeIfPresent(String.self, forKey: .token) ??
            container.decodeIfPresent(String.self, forKey: .access_token)

        guard let rawAccessToken else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Missing access token in refresh response"
                )
            )
        }

        let normalizedAccessToken = rawAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAccessToken.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Empty access token in refresh response"
                )
            )
        }

        accessToken = normalizedAccessToken
        refreshToken =
            try container.decodeIfPresent(String.self, forKey: .refreshToken) ??
            container.decodeIfPresent(String.self, forKey: .refresh_token)
    }
}
