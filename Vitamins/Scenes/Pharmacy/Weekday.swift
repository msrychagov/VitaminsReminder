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
}
