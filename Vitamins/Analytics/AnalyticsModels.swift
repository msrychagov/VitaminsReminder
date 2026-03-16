import Foundation

struct AnalyticsEvent: Codable, Equatable {
    let eventID: UUID
    let occurredAt: Date
    let eventName: String
    let sessionID: UUID
    let userID: Int64?
    let anonymousID: UUID?
    let properties: AnalyticsProperties
    let appVersion: String?
    let platform: String
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case occurredAt = "occurred_at"
        case eventName = "event_name"
        case sessionID = "session_id"
        case userID = "user_id"
        case anonymousID = "anonymous_id"
        case properties
        case appVersion = "app_version"
        case platform
        case requestID = "request_id"
    }
}

struct AnalyticsBatchRequest: Encodable {
    let batchID: UUID
    let sentAt: Date
    let events: [AnalyticsEvent]

    enum CodingKeys: String, CodingKey {
        case batchID = "batch_id"
        case sentAt = "sent_at"
        case events
    }
}

struct AnalyticsBatchResponse: Decodable {
    let accepted: Int
    let deduplicated: Int
}

struct AnalyticsIdentityContext {
    let anonymousID: UUID
    let sessionID: UUID
    let userID: Int64?
    let appVersion: String?
    let platform: String
}

enum AnalyticsCoding {
    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dateFormatter.string(from: date))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawDate = try container.decode(String.self)

            guard let date = dateFormatter.date(from: rawDate) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid analytics date: \(rawDate)"
                )
            }

            return date
        }
        return decoder
    }
}
