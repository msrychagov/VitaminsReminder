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

    init?(apiCode: String) {
        switch apiCode.lowercased() {
        case "mon": self = .mon
        case "tue": self = .tue
        case "wed": self = .wed
        case "thu": self = .thu
        case "fri": self = .fri
        case "sat": self = .sat
        case "sun": self = .sun
        default: return nil
        }
    }

    static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        let weekdayNumber = calendar.component(.weekday, from: date)
        switch weekdayNumber {
        case 1: return .sun
        case 2: return .mon
        case 3: return .tue
        case 4: return .wed
        case 5: return .thu
        case 6: return .fri
        default: return .sat
        }
    }

    static func orderedCases(startingFrom weekday: Weekday) -> [Weekday] {
        guard let startIndex = allCases.firstIndex(of: weekday) else {
            return allCases
        }

        return Array(allCases[startIndex...]) + Array(allCases[..<startIndex])
    }

    static func everyOtherDaySet(startingFrom weekday: Weekday) -> Set<Weekday> {
        guard let startIndex = allCases.firstIndex(of: weekday) else {
            return Set(allCases)
        }

        var result = Set<Weekday>()
        for offset in stride(from: 0, to: allCases.count, by: 2) {
            let index = (startIndex + offset) % allCases.count
            result.insert(allCases[index])
        }
        return result
    }

    static func ordered(_ weekdays: Set<Weekday>, startingFrom weekday: Weekday) -> [Weekday] {
        orderedCases(startingFrom: weekday).filter { weekdays.contains($0) }
    }
}
