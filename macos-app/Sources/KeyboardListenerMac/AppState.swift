import Foundation
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    static let appVersion = "0.1.0"

    @Published var isListening = false
    @Published var hasAccessibilityAccess = AccessibilityService.isTrusted()
    @Published var todayCount = 0
    @Published var pendingUploadCount = 0
    @Published var syncStatus = "Idle"
    @Published var lastError: String?
    @Published var config: AppConfig
    @Published var launchAtLoginEnabled = false
    @Published var launchAtLoginSupported = false
    @Published var selectedRange: DashboardRange = .day
    @Published var remoteBuckets: [EventBucket] = []
    @Published var topKeyStats: [KeyCodeStat] = []
    @Published var remoteStatsStatus = "Loading remote stats..."
    @Published var remoteStatsTotal = 0
    @Published var hideRangeStart: Date
    @Published var hideRangeEnd: Date
    @Published var hideRangeStatus = "Only synced backend data will be marked as 未记录."
    @Published var isHidingRange = false

    private let configStore: ConfigStore
    private let localStore: LocalStore
    private let eventCaptureService = EventCaptureService()
    private let syncService: SyncService
    private var syncTimer: Timer?
    private let maxHideRangeDuration: TimeInterval = 24 * 60 * 60

    init() {
        let roundedNow = Self.roundedToMinute(.now)
        self.hideRangeEnd = roundedNow
        self.hideRangeStart = Calendar.current.date(byAdding: .minute, value: -1, to: roundedNow) ?? roundedNow

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
        refreshLaunchAtLoginStatus()
        scheduleSync()
        loadRemoteStats()
        if config.startListeningOnLaunch {
            startListening()
        }
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

        eventCaptureService.onEvent = { [weak self] record in
            Task { @MainActor in
                self?.persist(event: record)
            }
        }
        eventCaptureService.start()
        isListening = true
        syncStatus = "Listening"
    }

    func pauseListening() {
        eventCaptureService.stop()
        eventCaptureService.onEvent = nil
        isListening = false
        syncStatus = "Paused"
    }

    func saveConfig(apiBaseURL: String, bootstrapSecret: String) {
        config.apiBaseURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        config.bootstrapSecret = bootstrapSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        configStore.save(config: config)
        syncStatus = "Configuration saved"
    }

    func setStartListeningOnLaunch(_ enabled: Bool) {
        config.startListeningOnLaunch = enabled
        configStore.save(config: config)
        syncStatus = enabled ? "Will start listening on launch" : "Will stay paused on launch"
    }

    func refreshPermissions() {
        hasAccessibilityAccess = AccessibilityService.isTrusted()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        guard launchAtLoginSupported else {
            lastError = "Open at Login is available from the packaged .app build."
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            launchAtLoginEnabled = false
            lastError = error.localizedDescription
        }
    }

    func syncNow() {
        Task {
            do {
                syncStatus = "Syncing..."
                let result = try await syncService.flushPendingEvents(appVersion: Self.appVersion)
                refreshSnapshot()
                await reloadRemoteStats()
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

    func selectRange(_ range: DashboardRange) {
        guard selectedRange != range else { return }
        selectedRange = range
        loadRemoteStats()
    }

    var hideRangeValidationMessage: String? {
        if config.deviceToken == nil {
            return "Sync once before hiding synced data."
        }
        if hideRangeEnd <= hideRangeStart {
            return "End time must be later than start time."
        }
        if hideRangeEnd.timeIntervalSince(hideRangeStart) > maxHideRangeDuration {
            return "A single hide range cannot exceed 24 hours."
        }
        return nil
    }

    var canHideSelectedRange: Bool {
        hideRangeValidationMessage == nil && !isHidingRange
    }

    func hideSelectedRange() {
        guard let validationMessage = hideRangeValidationMessage else {
            let start = hideRangeStart
            let end = hideRangeEnd
            isHidingRange = true
            hideRangeStatus = "Hiding synced events..."
            lastError = nil

            Task {
                do {
                    let result = try await syncService.hideRange(start: start, end: end)
                    await reloadRemoteStats()
                    hideRangeStatus = "Hidden \(result.updatedCount) synced events from \(formatHideRangeDate(start)) to \(formatHideRangeDate(end))."
                    syncStatus = "Hide completed"
                } catch {
                    lastError = error.localizedDescription
                    hideRangeStatus = "Hide failed"
                }
                isHidingRange = false
            }
            return
        }

        lastError = validationMessage
        hideRangeStatus = "Hide failed"
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

    private func loadRemoteStats() {
        Task {
            await reloadRemoteStats()
        }
    }

    private func reloadRemoteStats() async {
        do {
            remoteStatsStatus = "Loading \(selectedRange.chartTitle)..."
            let summary = try await syncService.fetchSummary(range: selectedRange)
            let keycodes = try await syncService.fetchKeyCodeStats(range: selectedRange)
            remoteBuckets = summary.buckets.map {
                EventBucket(bucketStart: $0.bucketStart, count: $0.count)
            }
            topKeyStats = keycodes.items.map { KeyCodeStat(keyCode: $0.keyCode, count: $0.count) }
            remoteStatsTotal = summary.totalEvents
            remoteStatsStatus = summary.totalEvents == 0 ? "No synced data in this range yet." : "Showing synced data for \(selectedRange.chartTitle)."
        } catch {
            remoteBuckets = []
            topKeyStats = []
            remoteStatsTotal = 0
            remoteStatsStatus = error.localizedDescription
        }
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginSupported = Bundle.main.bundleURL.pathExtension == "app"
        guard launchAtLoginSupported else {
            launchAtLoginEnabled = false
            return
        }

        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled || status == .requiresApproval
    }

    private func formatHideRangeDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func roundedToMinute(_ date: Date) -> Date {
        let calendar = Calendar.current
        let withoutSeconds = calendar.date(bySetting: .second, value: 0, of: date) ?? date
        return calendar.date(bySetting: .nanosecond, value: 0, of: withoutSeconds) ?? withoutSeconds
    }
}
