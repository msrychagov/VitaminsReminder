import Foundation

extension Date {
    var startOfDayUniversal: Date { Calendar.current.startOfDay(for: self) }
}
