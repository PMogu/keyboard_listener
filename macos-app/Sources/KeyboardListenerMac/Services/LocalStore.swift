import Foundation
import SQLite3

final class LocalStore {
    private let queue = DispatchQueue(label: "keyboardListener.localStore")
    private let dateFormatter = ISO8601DateFormatter()
    private var db: OpaquePointer?

    init() throws {
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try openDatabase()
        try createSchema()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    func insert(event: KeyEventRecord) throws {
        try queue.sync {
            let sql = """
            INSERT OR IGNORE INTO key_events (
                event_id, occurred_at, key_code, modifier_flags, event_type, source_app, sync_state
            ) VALUES (?, ?, ?, ?, ?, ?, 0);
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw databaseError()
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, event.id, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, dateFormatter.string(from: event.occurredAt), -1, transientDestructor)
            sqlite3_bind_int(statement, 3, Int32(event.keyCode))
            sqlite3_bind_int(statement, 4, Int32(event.modifierFlags))
            sqlite3_bind_text(statement, 5, event.eventType, -1, transientDestructor)
            if let sourceApp = event.sourceApp {
                sqlite3_bind_text(statement, 6, sourceApp, -1, transientDestructor)
            } else {
                sqlite3_bind_null(statement, 6)
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw databaseError()
            }
        }
    }

    func fetchPendingUploads(limit: Int = 200) throws -> [PendingUpload] {
        try queue.sync {
            let sql = """
            SELECT id, event_id, occurred_at, key_code, modifier_flags, event_type, source_app
            FROM key_events
            WHERE sync_state = 0
            ORDER BY occurred_at ASC
            LIMIT ?;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw databaseError()
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(limit))

            var uploads: [PendingUpload] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let rowID = sqlite3_column_int64(statement, 0)
                let eventID = string(from: statement, index: 1)
                let occurredAt = dateFormatter.date(from: string(from: statement, index: 2)) ?? .now
                let keyCode = Int(sqlite3_column_int(statement, 3))
                let modifierFlags = Int(sqlite3_column_int(statement, 4))
                let eventType = string(from: statement, index: 5)
                let sourceApp = nullableString(from: statement, index: 6)

                uploads.append(
                    PendingUpload(
                        id: rowID,
                        event: KeyEventRecord(
                            id: eventID,
                            occurredAt: occurredAt,
                            keyCode: keyCode,
                            modifierFlags: modifierFlags,
                            eventType: eventType,
                            sourceApp: sourceApp
                        )
                    )
                )
            }
            return uploads
        }
    }

    func markUploaded(ids: [Int64]) throws {
        guard !ids.isEmpty else { return }

        try queue.sync {
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            let sql = "UPDATE key_events SET sync_state = 1 WHERE id IN (\(placeholders));"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw databaseError()
            }
            defer { sqlite3_finalize(statement) }

            for (index, id) in ids.enumerated() {
                sqlite3_bind_int64(statement, Int32(index + 1), id)
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw databaseError()
            }
        }
    }

    func summarySnapshot() throws -> SummarySnapshot {
        try queue.sync {
            SummarySnapshot(
                todayCount: try todayCountLocked(),
                recentBuckets: try recentBucketsLocked(),
                pendingUploadCount: try pendingUploadCountLocked()
            )
        }
    }

    private func openDatabase() throws {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("KeyboardListener", isDirectory: true)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        let dbURL = supportURL.appendingPathComponent("keyboard_listener.sqlite")

        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
            throw databaseError()
        }
    }

    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS key_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id TEXT NOT NULL UNIQUE,
            occurred_at TEXT NOT NULL,
            key_code INTEGER NOT NULL,
            modifier_flags INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            source_app TEXT,
            sync_state INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_key_events_occurred_at ON key_events(occurred_at);
        CREATE INDEX IF NOT EXISTS idx_key_events_sync_state ON key_events(sync_state);
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw databaseError()
        }
    }

    private func todayCountLocked() throws -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let sql = "SELECT COUNT(*) FROM key_events WHERE occurred_at >= ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError()
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, dateFormatter.string(from: start), -1, transientDestructor)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw databaseError()
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func recentBucketsLocked() throws -> [EventBucket] {
        let start = Calendar.current.date(byAdding: .hour, value: -1, to: .now) ?? .now
        let sql = """
        SELECT substr(occurred_at, 1, 16) || ":00Z" AS minute_bucket, COUNT(*)
        FROM key_events
        WHERE occurred_at >= ?
        GROUP BY minute_bucket
        ORDER BY minute_bucket ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError()
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, dateFormatter.string(from: start), -1, transientDestructor)

        var buckets: [EventBucket] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let rawMinute = string(from: statement, index: 0)
            let count = Int(sqlite3_column_int(statement, 1))
            if let date = dateFormatter.date(from: rawMinute) {
                buckets.append(EventBucket(bucketStart: date, count: count))
            }
        }
        return buckets
    }

    private func pendingUploadCountLocked() throws -> Int {
        let sql = "SELECT COUNT(*) FROM key_events WHERE sync_state = 0;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError()
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw databaseError()
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func string(from statement: OpaquePointer?, index: Int32) -> String {
        String(cString: sqlite3_column_text(statement, index))
    }

    private func nullableString(from statement: OpaquePointer?, index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: value)
    }

    private func databaseError() -> NSError {
        let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown SQLite error"
        return NSError(domain: "LocalStore", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
