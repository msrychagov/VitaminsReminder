import Foundation

final class AnalyticsService {
    static let shared = AnalyticsService()

    private let engine = AnalyticsEngine()

    private init() {}

    func start() {
        Task {
            await engine.start()
        }
    }

    func identify(userID: String?) {
        Task {
            await engine.identify(userID: userID)
        }
    }

    func clearUser() {
        Task {
            await engine.clearUser()
        }
    }

    func track(_ name: String, properties: AnalyticsProperties = [:], requestID: String? = nil) {
        Task {
            await engine.track(name, properties: properties, requestID: requestID)
        }
    }

    func trackAPIError(
        endpoint: String,
        statusCode: Int?,
        errorCode: String?,
        requestID: String? = nil
    ) {
        var properties: AnalyticsProperties = [
            "endpoint": .string(endpoint)
        ]

        if let statusCode {
            properties["http_status"] = .int(statusCode)
        }

        if let errorCode, !errorCode.isEmpty {
            properties["error_code"] = .string(errorCode)
        }

        track(AnalyticsEventName.apiError, properties: properties, requestID: requestID)
    }

    func handleApplicationWillEnterForeground() {
        Task {
            await engine.handleApplicationWillEnterForeground()
        }
    }

    func handleApplicationDidEnterBackground() async {
        await engine.handleApplicationDidEnterBackground()
    }

    func handleApplicationWillTerminate() async {
        await engine.handleApplicationWillTerminate()
    }
}

private actor AnalyticsEngine {
    private enum Config {
        static let preferredBatchSize = 20
        static let maxBatchSize = 100
        static let flushInterval: TimeInterval = 15
        static let sessionTimeout: TimeInterval = 30 * 60
    }

    private let queueStore = AnalyticsQueueStore()
    private let identityStore = AnalyticsIdentityStore()
    private let uploader = AnalyticsUploader()

    private var isStarted = false
    private var isFlushInFlight = false
    private var consecutiveFailures = 0
    private var nextRetryAt: Date?
    private var lastBackgroundDate: Date?
    private var timerTask: Task<Void, Never>?

    func start() async {
        guard !isStarted else { return }
        isStarted = true

        _ = await identityStore.identityContext()
        await identityStore.startNewSession()
        startFlushTimer()
        await flush(force: false, reason: "startup")
    }

    func identify(userID: String?) async {
        await identityStore.setUserID(userID)
    }

    func clearUser() async {
        await identityStore.clearUserID()
    }

    func track(_ name: String, properties: AnalyticsProperties, requestID: String?) async {
        guard Self.isValidEventName(name) else { return }

        let identity = await identityStore.identityContext()
        let event = AnalyticsEvent(
            eventID: UUID(),
            occurredAt: Date(),
            eventName: name,
            sessionID: identity.sessionID,
            userID: identity.userID,
            anonymousID: identity.anonymousID,
            properties: properties,
            appVersion: identity.appVersion,
            platform: identity.platform,
            requestID: requestID
        )

        await queueStore.enqueue(event)

        let pendingCount = await queueStore.count()
        if pendingCount >= Config.preferredBatchSize {
            await flush(force: false, reason: "threshold")
        }
    }

    func handleApplicationWillEnterForeground() async {
        if let lastBackgroundDate {
            let inactivityDuration = Date().timeIntervalSince(lastBackgroundDate)
            if inactivityDuration >= Config.sessionTimeout {
                await identityStore.startNewSession()
            }
        }

        lastBackgroundDate = nil
        await flush(force: false, reason: "foreground")
    }

    func handleApplicationDidEnterBackground() async {
        lastBackgroundDate = Date()
        await flush(force: true, reason: "background")
    }

    func handleApplicationWillTerminate() async {
        await flush(force: true, reason: "termination")
    }

    private func startFlushTimer() {
        timerTask?.cancel()
        timerTask = Task { [flushInterval = Config.flushInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
                await self.flush(force: false, reason: "timer")
            }
        }
    }

    private func flush(force: Bool, reason: String) async {
        _ = reason

        guard !isFlushInFlight else { return }

        if let nextRetryAt, Date() < nextRetryAt {
            return
        }

        let pendingCount = await queueStore.count()
        guard pendingCount > 0 else { return }

        if !force && pendingCount < Config.preferredBatchSize {
            guard
                let oldestEventAge = await queueStore.oldestEventAge(referenceDate: Date()),
                oldestEventAge >= Config.flushInterval
            else {
                return
            }
        }

        isFlushInFlight = true
        defer { isFlushInFlight = false }

        while true {
            let currentCount = await queueStore.count()
            guard currentCount > 0 else { return }

            if !force && currentCount < Config.preferredBatchSize {
                guard
                    let oldestEventAge = await queueStore.oldestEventAge(referenceDate: Date()),
                    oldestEventAge >= Config.flushInterval
                else {
                    return
                }
            }

            let batch = await queueStore.peek(limit: Config.maxBatchSize)
            guard !batch.isEmpty else { return }

            do {
                let response = try await uploader.upload(events: batch)
                let acknowledgedEvents = response.accepted + response.deduplicated

                guard acknowledgedEvents == batch.count else {
                    throw AnalyticsUploader.UploadError.invalidAcknowledgement(
                        expected: batch.count,
                        received: acknowledgedEvents
                    )
                }

                await queueStore.remove(eventIDs: Set(batch.map(\.eventID)))
                consecutiveFailures = 0
                nextRetryAt = nil
            } catch {
                consecutiveFailures += 1
                nextRetryAt = Date().addingTimeInterval(backoffInterval(for: consecutiveFailures))
                return
            }

            let remainingCount = await queueStore.count()
            if !force && remainingCount < Config.preferredBatchSize {
                return
            }
        }
    }

    private func backoffInterval(for failureCount: Int) -> TimeInterval {
        min(300, pow(2.0, Double(max(0, failureCount - 1))) * 5)
    }

    private static func isValidEventName(_ name: String) -> Bool {
        let parts = name.split(separator: ".")
        return parts.count == 2 && parts.allSatisfy { !$0.isEmpty }
    }
}

private actor AnalyticsIdentityStore {
    private enum Key {
        static let anonymousID = "analytics.anonymous_id"
        static let userID = "analytics.user_id"
    }

    private let defaults: UserDefaults
    private let appVersion: String?
    private var sessionID = UUID()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    func identityContext() -> AnalyticsIdentityContext {
        AnalyticsIdentityContext(
            anonymousID: anonymousID(),
            sessionID: sessionID,
            userID: currentUserID(),
            appVersion: appVersion,
            platform: "ios"
        )
    }

    func startNewSession() {
        sessionID = UUID()
    }

    func setUserID(_ rawValue: String?) {
        guard
            let rawValue,
            let parsedUserID = Int64(rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            defaults.removeObject(forKey: Key.userID)
            return
        }

        defaults.set(String(parsedUserID), forKey: Key.userID)
    }

    func clearUserID() {
        defaults.removeObject(forKey: Key.userID)
    }

    private func anonymousID() -> UUID {
        if let rawValue = defaults.string(forKey: Key.anonymousID),
           let existingID = UUID(uuidString: rawValue) {
            return existingID
        }

        let newID = UUID()
        defaults.set(newID.uuidString, forKey: Key.anonymousID)
        return newID
    }

    private func currentUserID() -> Int64? {
        guard let rawValue = defaults.string(forKey: Key.userID) else {
            return nil
        }

        return Int64(rawValue)
    }
}

private actor AnalyticsQueueStore {
    private let fileURL: URL
    private let encoder = AnalyticsCoding.makeEncoder()
    private let decoder = AnalyticsCoding.makeDecoder()

    private var didLoadFromDisk = false
    private var events: [AnalyticsEvent] = []

    init(fileManager: FileManager = .default) {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let analyticsDirectory = baseDirectory.appendingPathComponent("Analytics", isDirectory: true)
        self.fileURL = analyticsDirectory.appendingPathComponent("pending-events.json")
    }

    func enqueue(_ event: AnalyticsEvent) {
        do {
            try ensureLoaded()
            events.append(event)
            try persist()
        } catch {
            return
        }
    }

    func count() -> Int {
        do {
            try ensureLoaded()
            return events.count
        } catch {
            return events.count
        }
    }

    func peek(limit: Int) -> [AnalyticsEvent] {
        do {
            try ensureLoaded()
            return Array(events.prefix(limit))
        } catch {
            return Array(events.prefix(limit))
        }
    }

    func remove(eventIDs: Set<UUID>) {
        do {
            try ensureLoaded()
            events.removeAll { eventIDs.contains($0.eventID) }
            try persist()
        } catch {
            return
        }
    }

    func oldestEventAge(referenceDate: Date) -> TimeInterval? {
        do {
            try ensureLoaded()
            guard let event = events.first else { return nil }
            return referenceDate.timeIntervalSince(event.occurredAt)
        } catch {
            return events.first.map { referenceDate.timeIntervalSince($0.occurredAt) }
        }
    }

    private func ensureLoaded() throws {
        guard !didLoadFromDisk else { return }
        didLoadFromDisk = true

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            events = []
            return
        }

        let data = try Data(contentsOf: fileURL)
        events = try decoder.decode([AnalyticsEvent].self, from: data)
    }

    private func persist() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(events)
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct AnalyticsUploader {
    enum UploadError: Error {
        case invalidResponse
        case invalidAcknowledgement(expected: Int, received: Int)
        case httpStatus(Int)
    }

    private let session = URLSession.shared
    private let encoder = AnalyticsCoding.makeEncoder()
    private let decoder = AnalyticsCoding.makeDecoder()

    func upload(events: [AnalyticsEvent]) async throws -> AnalyticsBatchResponse {
        guard let url = URL(string: "\(NetworkClient.Constants.baseURL)/analytics/events") else {
            throw NetworkClientErrors.incorrectURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = EndpointType.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(
            AnalyticsBatchRequest(
                batchID: UUID(),
                sentAt: Date(),
                events: events
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UploadError.httpStatus(httpResponse.statusCode)
        }

        return try decoder.decode(AnalyticsBatchResponse.self, from: data)
    }
}
