import Foundation

struct KeyEventRecord: Identifiable, Codable {
    let id: String
    let occurredAt: Date
    let keyCode: Int
    let modifierFlags: Int
    let eventType: String
    let sourceApp: String?
}

struct PendingUpload: Identifiable {
    let id: Int64
    let event: KeyEventRecord
}

struct EventBucket: Identifiable {
    let minute: Date
    let count: Int

    var id: Date { minute }
}

struct SummarySnapshot {
    let todayCount: Int
    let recentBuckets: [EventBucket]
    let pendingUploadCount: Int
}

struct AppConfig {
    var apiBaseURL: String
    var bootstrapSecret: String
    var deviceID: String?
    var deviceToken: String?
    var deviceName: String
}

struct RegisterDeviceRequest: Codable {
    let name: String
    let platform: String
    let appVersion: String
    let bootstrapSecret: String
}

struct RegisterDeviceResponse: Codable {
    let deviceID: String
    let deviceToken: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceToken = "device_token"
        case createdAt = "created_at"
    }
}

struct EventBatchRequest: Codable {
    let batchID: String
    let events: [KeyEventPayload]

    enum CodingKeys: String, CodingKey {
        case batchID = "batch_id"
        case events
    }
}

struct KeyEventPayload: Codable {
    let eventID: String
    let occurredAt: Date
    let keyCode: Int
    let modifierFlags: Int
    let eventType: String
    let sourceApp: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case occurredAt = "occurred_at"
        case keyCode = "key_code"
        case modifierFlags = "modifier_flags"
        case eventType = "event_type"
        case sourceApp = "source_app"
    }
}

struct EventBatchResponse: Codable {
    let batchID: String
    let receivedCount: Int
    let insertedCount: Int
    let duplicateCount: Int

    enum CodingKeys: String, CodingKey {
        case batchID = "batch_id"
        case receivedCount = "received_count"
        case insertedCount = "inserted_count"
        case duplicateCount = "duplicate_count"
    }
}

struct SyncResult {
    let uploadedCount: Int
    let duplicateCount: Int
}
