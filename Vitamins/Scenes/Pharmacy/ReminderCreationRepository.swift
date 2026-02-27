import Foundation

final class ReminderCreationRepository {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = NetworkClient()) {
        self.networkClient = networkClient
    }

    func createReminder(request: CreateVitaminReminderRequest) async throws {
        let _: EmptyResponse? = try await networkClient.request(
            body: request,
            endpoint: VitaminsEndpoint.createReminder
        )
    }

    func updateReminder(id: Int, request: CreateVitaminReminderRequest) async throws {
        let _: EmptyResponse? = try await networkClient.request(
            body: request,
            endpoint: VitaminsEndpoint.updateReminder(id: id)
        )
    }
}
