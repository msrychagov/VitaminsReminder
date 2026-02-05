import Foundation

final class VitaminRepository {
    private let networkClient: NetworkClient
    private let storage: VitaminStorage
    private let useMocks: Bool

    init(
        networkClient: NetworkClient = NetworkClient(),
        storage: VitaminStorage = VitaminStorage(),
        useMocks: Bool = true
    ) {
        self.networkClient = networkClient
        self.storage = storage
        self.useMocks = useMocks
    }

    func fetchVitamins() async throws -> [Vitamin] {
        if useMocks {
            let mock = [
                Vitamin(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEE1") ?? UUID(), name: "Витамин A"),
                Vitamin(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEE2") ?? UUID(), name: "Витамин B")
            ]
            storage.save(mock)
            return mock
        }

        do {
            if let remote: [VitaminResponse] = try await networkClient.request(endpoint: VitaminsEndpoint.list) {
                let items = remote.map { $0.toDomain() }
                storage.save(items)
                return items
            }
            return []
        } catch {
            let cached = storage.load()
            if !cached.isEmpty {
                return cached
            }
            throw error
        }
    }
}
