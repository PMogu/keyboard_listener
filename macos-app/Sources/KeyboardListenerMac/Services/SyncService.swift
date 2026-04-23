import Foundation

@MainActor
final class SyncService {
    private let configStore: ConfigStore
    private let localStore: LocalStore
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configStore: ConfigStore, localStore: LocalStore, session: URLSession = .shared) {
        self.configStore = configStore
        self.localStore = localStore
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = fractionalFormatter.date(from: value) {
                return date
            }

            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]
            if let date = standardFormatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported ISO8601 date string: \(value)"
            )
        }
        self.decoder = decoder
    }

    func flushPendingEvents(appVersion: String) async throws -> SyncResult {
        var config = configStore.load()
        guard let baseURL = URL(string: config.apiBaseURL) else {
            throw URLError(.badURL)
        }

        if config.deviceToken == nil {
            let registration = try await registerDevice(baseURL: baseURL, config: config, appVersion: appVersion)
            configStore.setDeviceCredentials(deviceID: registration.deviceID, token: registration.deviceToken)
            config.deviceID = registration.deviceID
            config.deviceToken = registration.deviceToken
        }

        guard let token = config.deviceToken else {
            return SyncResult(uploadedCount: 0, duplicateCount: 0)
        }

        let pending = try localStore.fetchPendingUploads(limit: 200)
        guard !pending.isEmpty else {
            return SyncResult(uploadedCount: 0, duplicateCount: 0)
        }

        let payload = EventBatchRequest(
            batchID: UUID().uuidString.lowercased(),
            events: pending.map {
                KeyEventPayload(
                    eventID: $0.event.id,
                    occurredAt: $0.event.occurredAt,
                    keyCode: $0.event.keyCode,
                    modifierFlags: $0.event.modifierFlags,
                    eventType: $0.event.eventType,
                    sourceApp: $0.event.sourceApp
                )
            }
        )

        var request = URLRequest(url: baseURL.appending(path: "/v1/events/batch"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw SyncError.uploadFailed(String(data: data, encoding: .utf8) ?? "Unexpected response")
        }

        let result = try decoder.decode(EventBatchResponse.self, from: data)
        try localStore.markUploaded(ids: pending.map(\.id))
        configStore.updateLastSyncedAt(.now)
        return SyncResult(uploadedCount: result.insertedCount, duplicateCount: result.duplicateCount)
    }

    func fetchSummary(range: DashboardRange) async throws -> StatsSummaryResponse {
        let config = configStore.load()
        guard let baseURL = URL(string: config.apiBaseURL) else {
            throw URLError(.badURL)
        }
        guard let token = config.deviceToken else {
            throw SyncError.missingDeviceRegistration
        }

        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-range.duration)
        var components = URLComponents(url: baseURL.appending(path: "/v1/stats/summary"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "start_time", value: encoderDateString(startTime)),
            URLQueryItem(name: "end_time", value: encoderDateString(endTime)),
            URLQueryItem(name: "bucket", value: range.statsBucket),
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw SyncError.statsFailed(String(data: data, encoding: .utf8) ?? "Unexpected response")
        }

        return try decoder.decode(StatsSummaryResponse.self, from: data)
    }

    func fetchKeyCodeStats(range: DashboardRange, limit: Int = 10) async throws -> KeyCodeStatsResponse {
        let config = configStore.load()
        guard let baseURL = URL(string: config.apiBaseURL) else {
            throw URLError(.badURL)
        }
        guard let token = config.deviceToken else {
            throw SyncError.missingDeviceRegistration
        }

        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-range.duration)
        var components = URLComponents(url: baseURL.appending(path: "/v1/stats/keycodes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "start_time", value: encoderDateString(startTime)),
            URLQueryItem(name: "end_time", value: encoderDateString(endTime)),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw SyncError.statsFailed(String(data: data, encoding: .utf8) ?? "Unexpected response")
        }

        return try decoder.decode(KeyCodeStatsResponse.self, from: data)
    }

    private func registerDevice(baseURL: URL, config: AppConfig, appVersion: String) async throws -> RegisterDeviceResponse {
        let requestBody = RegisterDeviceRequest(
            name: config.deviceName,
            platform: "macOS",
            appVersion: appVersion,
            bootstrapSecret: config.bootstrapSecret
        )

        var request = URLRequest(url: baseURL.appending(path: "/v1/devices/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw SyncError.registrationFailed(String(data: data, encoding: .utf8) ?? "Unexpected response")
        }
        return try decoder.decode(RegisterDeviceResponse.self, from: data)
    }

    private func encoderDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

enum SyncError: LocalizedError {
    case registrationFailed(String)
    case uploadFailed(String)
    case statsFailed(String)
    case missingDeviceRegistration

    var errorDescription: String? {
        switch self {
        case let .registrationFailed(message):
            return "Device registration failed: \(message)"
        case let .uploadFailed(message):
            return "Event upload failed: \(message)"
        case let .statsFailed(message):
            return "Stats fetch failed: \(message)"
        case .missingDeviceRegistration:
            return "Device not registered yet. Sync once before loading remote stats."
        }
    }
}
