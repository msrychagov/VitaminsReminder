import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var selectedMonth: Date
    @Published private(set) var stats: MonthStatsResponse?
    @Published private(set) var items: [ReminderStatsItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: ReminderRepository
    private let calendar: Calendar

    init(
        repository: ReminderRepository = ReminderRepository(),
        calendar: Calendar = .current,
        initialMonth: Date = Date()
    ) {
        self.repository = repository
        self.calendar = calendar
        self.selectedMonth = StatsViewModel.startOfMonth(for: initialMonth, calendar: calendar)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await repository.fetchMonthStatsWithReminders(
                month: monthQueryString(),
                timezone: TimeZone.current.identifier
            )
            self.stats = response?.summary
            self.items = response?.items ?? []
        } catch {
            self.errorMessage = "Не удалось загрузить статистику"
        }
        isLoading = false
    }

    func previousMonth() {
        selectedMonth = adjusted(by: -1)
        Task { await load() }
    }

    func nextMonth() {
        selectedMonth = adjusted(by: 1)
        Task { await load() }
    }

    private func adjusted(by delta: Int) -> Date {
        calendar.date(byAdding: .month, value: delta, to: selectedMonth) ?? selectedMonth
    }

    private func monthQueryString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: selectedMonth)
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
