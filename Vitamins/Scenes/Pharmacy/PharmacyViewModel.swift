import Foundation
import Combine

struct PharmacyReminderItem: Identifiable, Equatable {
    let id: Int
    let title: String
}

final class PharmacyViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded([PharmacyReminderItem])
        case failed(String)
    }

    @Published var state: State = .loading

    private let repository: ReminderRepository

    init(repository: ReminderRepository = ReminderRepository()) {
        self.repository = repository
    }

    @MainActor
    func load() async {
        state = .loading
        do {
            let reminders = try await repository.fetchReminders()
                .filter(\.isActive)
            let items = reminders.map { reminder in
                PharmacyReminderItem(
                    id: reminder.id,
                    title: Self.resolvedTitle(for: reminder)
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            state = .loaded(items)
        } catch {
            state = .failed("Не удалось загрузить витамины")
        }
    }

    private static func resolvedTitle(for reminder: ReminderRemote) -> String {
        let catalogTitle = reminder.catalog?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !catalogTitle.isEmpty {
            return catalogTitle
        }
        let name = reminder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Витамин" : name
    }
}
