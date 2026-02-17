import Foundation

enum Weekday: String, CaseIterable, Identifiable, Hashable {
    case mon = "Пн"
    case tue = "Вт"
    case wed = "Ср"
    case thu = "Чт"
    case fri = "Пт"
    case sat = "Сб"
    case sun = "Вс"

    var id: String { rawValue }

    var apiCode: String {
        switch self {
        case .mon: return "mon"
        case .tue: return "tue"
        case .wed: return "wed"
        case .thu: return "thu"
        case .fri: return "fri"
        case .sat: return "sat"
        case .sun: return "sun"
        }
    }
}
