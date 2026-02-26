import Foundation

struct VitaminCatalogItem: Decodable, Identifiable, Equatable {
    let id: Int
    let code: String?
    let displayName: String?
    let defaultUnit: String?
    let interactionText: String?
    let compatibilityText: String?
    let contraindicationsText: String?
    let defaultCondition: String?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case displayName = "display_name"
        case defaultUnit = "default_unit"
        case interactionText = "interaction_text"
        case compatibilityText = "compatibility_text"
        case contraindicationsText = "contraindications_text"
        case defaultCondition = "default_condition"
    }

    var resolvedName: String {
        let value = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? (code ?? "Витамин") : value
    }
}
