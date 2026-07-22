import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var defaultConfiguration: MeetingConfiguration
    public var anthropicModel: String
    public var launchAtLogin: Bool
    public var hasCompletedOnboarding: Bool

    public init(
        defaultConfiguration: MeetingConfiguration = .init(),
        anthropicModel: String = "claude-sonnet-4-5",
        launchAtLogin: Bool = false,
        hasCompletedOnboarding: Bool = false
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.defaultConfiguration = defaultConfiguration
        self.anthropicModel = anthropicModel
        self.launchAtLogin = launchAtLogin
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

public enum ProviderHealthState: String, Codable, Sendable {
    case ready
    case notConfigured
    case notInstalled
    case needsLogin
    case unsupported
    case unavailable
}

public struct ProviderHealth: Codable, Equatable, Sendable {
    public var state: ProviderHealthState
    public var detail: String
    public var version: String?

    public init(state: ProviderHealthState, detail: String, version: String? = nil) {
        self.state = state
        self.detail = detail
        self.version = version
    }
}
