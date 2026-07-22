import Foundation

public actor SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "meetco.app-settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AppSettings {
        Self.loadSynchronously(defaults: defaults, key: key)
    }

    public nonisolated static func loadSynchronously(
        defaults: UserDefaults = .standard,
        key: String = "meetco.app-settings"
    ) -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONCoding.decoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) throws {
        let data = try JSONCoding.encoder(prettyPrinted: false).encode(settings)
        defaults.set(data, forKey: key)
    }

    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
