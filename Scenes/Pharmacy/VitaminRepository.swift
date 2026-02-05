import Foundation

final class VitaminRepository {
    private let networkClient: NetworkClient
    private let storage: VitaminStorage

    init(
        networkClient: NetworkClient = NetworkClient(),
        storage: VitaminStorage = VitaminStorage()
    ) {
        self.networkClient = networkClient
        self.storage = storage
    }

    func fetchVitamins() async throws -> [Vitamin] {
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
