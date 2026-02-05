import Foundation

@MainActor
final class PharmacyViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded([Vitamin])
        case failed(String)
    }

    @Published var state: State = .loading

    private let repository: VitaminRepository

    init(repository: VitaminRepository = VitaminRepository()) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            let vitamins = try await repository.fetchVitamins()
            state = .loaded(vitamins)
        } catch {
            state = .failed("Не удалось загрузить витамины")
        }
    }
}
