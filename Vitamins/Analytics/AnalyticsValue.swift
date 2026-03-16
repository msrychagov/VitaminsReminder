import Foundation

typealias AnalyticsProperties = [String: AnalyticsValue]

enum AnalyticsValue: Equatable, Codable {
    case string(String)
    case integer(Int64)
    case double(Double)
    case bool(Bool)
    case array([AnalyticsValue])
    case object([String: AnalyticsValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: AnalyticsValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([AnalyticsValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported analytics property value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

extension AnalyticsValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension AnalyticsValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension AnalyticsValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = .integer(Int64(value))
    }
}

extension AnalyticsValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension AnalyticsValue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: AnalyticsValue...) {
        self = .array(elements)
    }
}

extension AnalyticsValue: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, AnalyticsValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension AnalyticsValue: ExpressibleByNilLiteral {
    init(nilLiteral: ()) {
        self = .null
    }
}

extension AnalyticsValue {
    static func int(_ value: Int) -> AnalyticsValue {
        .integer(Int64(value))
    }

    static func int64(_ value: Int64) -> AnalyticsValue {
        .integer(value)
    }
}
