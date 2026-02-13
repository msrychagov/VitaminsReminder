import Foundation

struct Vitamin: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
}

struct VitaminResponse: Decodable {
    struct Catalog: Decodable {
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    let id: Int
    let name: String
    let catalog: Catalog?

    func toDomain() -> Vitamin {
        let title = catalog?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = title.flatMap { $0.isEmpty ? nil : $0 } ?? name
        return Vitamin(id: id, name: resolvedName)
    }
}
