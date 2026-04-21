import Foundation

@MainActor
final class AppState: ObservableObject {
    static let appVersion = "0.1.0"

    @Published var isListening = false
    @Published var hasAccessibilityAccess = AccessibilityService.isTrusted()
    @Published var todayCount = 0
    @Published var recentBuckets: [EventBucket] = []
    @Published var pendingUploadCount = 0
    @Published var syncStatus = "Idle"
    @Published var lastError: String?
    @Published var config: AppConfig

    private let configStore: ConfigStore
    private let localStore: LocalStore
    private let eventCaptureService = EventCaptureService()
    private let syncService: SyncService
    private var syncTimer: Timer?

    init() {
        let configStore = ConfigStore()
        self.configStore = configStore
        self.config = configStore.load()

        do {
            let localStore = try LocalStore()
            self.localStore = localStore
            self.syncService = SyncService(configStore: configStore, localStore: localStore)
        } catch {
            fatalError("Unable to initialize local store: \(error.localizedDescription)")
        }

        refreshSnapshot()
        scheduleSync()
    }

    func toggleListening() {
        isListening ? pauseListening() : startListening()
    }

    func startListening() {
        hasAccessibilityAccess = AccessibilityService.isTrusted()
        guard hasAccessibilityAccess else {
            AccessibilityService.promptForAccess()
            hasAccessibilityAccess = AccessibilityService.isTrusted()
            syncStatus = "Grant Accessibility access to start capturing."
            return
        }

        eventCaptureService.start { [weak self] record in
            Task { @MainActor in
                self?.persist(event: record)
            }
        }
        isListening = true
        syncStatus = "Listening"
    }

    func pauseListening() {
        eventCaptureService.stop()
        isListening = false
        syncStatus = "Paused"
    }

    func saveConfig(apiBaseURL: String, bootstrapSecret: String) {
        config.apiBaseURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        config.bootstrapSecret = bootstrapSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        configStore.save(config: config)
        syncStatus = "Configuration saved"
    }

    func refreshPermissions() {
        hasAccessibilityAccess = AccessibilityService.isTrusted()
    }

    func syncNow() {
        Task {
            do {
                syncStatus = "Syncing..."
                let result = try await syncService.flushPendingEvents(appVersion: Self.appVersion)
                refreshSnapshot()
                let lastSyncedText = configStore.lastSyncedAt()?.formatted(date: .abbreviated, time: .shortened) ?? "never"
                syncStatus = "Synced \(result.uploadedCount) new, \(result.duplicateCount) duplicate. Last sync \(lastSyncedText)."
                config = configStore.load()
            } catch {
                refreshSnapshot()
                lastError = error.localizedDescription
                syncStatus = "Sync failed"
            }
        }
    }

    private func persist(event: KeyEventRecord) {
        do {
            try localStore.insert(event: event)
            refreshSnapshot()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshSnapshot() {
        do {
            let snapshot = try localStore.summarySnapshot()
            todayCount = snapshot.todayCount
            recentBuckets = snapshot.recentBuckets
            pendingUploadCount = snapshot.pendingUploadCount
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func scheduleSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncNow()
            }
        }
    }
}
