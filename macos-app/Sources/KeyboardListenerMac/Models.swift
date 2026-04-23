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
    let bucketStart: Date
    let count: Int

    var id: Date { bucketStart }
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
    var startListeningOnLaunch: Bool
}

enum DashboardRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        }
    }

    var statsBucket: String {
        switch self {
        case .day: return "hour"
        case .week, .month: return "day"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .day: return 24 * 60 * 60
        case .week: return 7 * 24 * 60 * 60
        case .month: return 30 * 24 * 60 * 60
        }
    }

    var chartTitle: String {
        switch self {
        case .day: return "最近24小时"
        case .week: return "最近7天"
        case .month: return "最近30天"
        }
    }
}

struct KeyCodeStat: Identifiable {
    let keyCode: Int
    let count: Int

    var id: Int { keyCode }
}

struct RegisterDeviceRequest: Codable {
    let name: String
    let platform: String
    let appVersion: String
    let bootstrapSecret: String

    enum CodingKeys: String, CodingKey {
        case name
        case platform
        case appVersion = "app_version"
        case bootstrapSecret = "bootstrap_secret"
    }
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

struct StatsSummaryResponse: Codable {
    let startTime: Date
    let endTime: Date
    let bucket: String
    let totalEvents: Int
    let buckets: [StatsBucketPayload]

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case bucket
        case totalEvents = "total_events"
        case buckets
    }
}

struct StatsBucketPayload: Codable {
    let bucketStart: Date
    let count: Int

    enum CodingKeys: String, CodingKey {
        case bucketStart = "bucket_start"
        case count
    }
}

struct KeyCodeStatsResponse: Codable {
    let startTime: Date
    let endTime: Date
    let totalEvents: Int
    let items: [KeyCodeStatPayload]

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case totalEvents = "total_events"
        case items
    }
}

struct KeyCodeStatPayload: Codable {
    let keyCode: Int
    let count: Int

    enum CodingKeys: String, CodingKey {
        case keyCode = "key_code"
        case count
    }
}
