import Foundation

final class ConfigStore {
    private enum Keys {
        static let apiBaseURL = "keyboardListener.apiBaseURL"
        static let bootstrapSecret = "keyboardListener.bootstrapSecret"
        static let deviceID = "keyboardListener.deviceID"
        static let deviceToken = "keyboardListener.deviceToken"
        static let lastSyncedAt = "keyboardListener.lastSyncedAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppConfig {
        AppConfig(
            apiBaseURL: defaults.string(forKey: Keys.apiBaseURL) ?? "http://127.0.0.1:8000",
            bootstrapSecret: defaults.string(forKey: Keys.bootstrapSecret) ?? "",
            deviceID: defaults.string(forKey: Keys.deviceID),
            deviceToken: defaults.string(forKey: Keys.deviceToken),
            deviceName: Host.current().localizedName ?? "Mac"
        )
    }

    func save(config: AppConfig) {
        defaults.set(config.apiBaseURL, forKey: Keys.apiBaseURL)
        defaults.set(config.bootstrapSecret, forKey: Keys.bootstrapSecret)
        defaults.set(config.deviceID, forKey: Keys.deviceID)
        defaults.set(config.deviceToken, forKey: Keys.deviceToken)
    }

    func setDeviceCredentials(deviceID: String, token: String) {
        defaults.set(deviceID, forKey: Keys.deviceID)
        defaults.set(token, forKey: Keys.deviceToken)
    }

    func updateLastSyncedAt(_ date: Date) {
        defaults.set(date, forKey: Keys.lastSyncedAt)
    }

    func lastSyncedAt() -> Date? {
        defaults.object(forKey: Keys.lastSyncedAt) as? Date
    }
}
