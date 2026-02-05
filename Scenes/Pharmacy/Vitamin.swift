import Foundation

struct Vitamin: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
}

struct VitaminResponse: Decodable {
    let id: UUID
    let name: String

    func toDomain() -> Vitamin {
        Vitamin(id: id, name: name)
    }
}
