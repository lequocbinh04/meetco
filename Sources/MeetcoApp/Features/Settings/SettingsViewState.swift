import MeetcoCore

public struct ProviderConnectionState: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let kind: AgentProviderKind?
    public let health: ProviderHealth

    public init(id: String, name: String, kind: AgentProviderKind?, health: ProviderHealth) {
        self.id = id
        self.name = name
        self.kind = kind
        self.health = health
    }
}

public struct ConnectionsSettingsState: Equatable, Sendable {
    public let providers: [ProviderConnectionState]
    public let selectedAgent: AgentProviderKind
    public let anthropicModel: String

    public init(
        providers: [ProviderConnectionState],
        selectedAgent: AgentProviderKind,
        anthropicModel: String
    ) {
        self.providers = providers
        self.selectedAgent = selectedAgent
        self.anthropicModel = anthropicModel
    }
}

public struct RecordingSettingsState: Equatable, Sendable {
    public let configuration: MeetingConfiguration
    public let storageLocation: String

    public init(configuration: MeetingConfiguration, storageLocation: String) {
        self.configuration = configuration
        self.storageLocation = storageLocation
    }
}

public struct MCPSettingsState: Equatable, Sendable {
    public let isEnabled: Bool
    public let health: ProviderHealth
    public let configurationText: String
    public let snapshotDetail: String

    public init(
        isEnabled: Bool,
        health: ProviderHealth,
        configurationText: String,
        snapshotDetail: String
    ) {
        self.isEnabled = isEnabled
        self.health = health
        self.configurationText = configurationText
        self.snapshotDetail = snapshotDetail
    }
}

public enum PermissionDiagnosticStatus: Equatable, Sendable {
    case granted
    case denied
    case notRequested
    case unavailable
}

public struct PermissionDiagnosticItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let systemImage: String
    public let status: PermissionDiagnosticStatus

    public init(
        id: String,
        title: String,
        detail: String,
        systemImage: String,
        status: PermissionDiagnosticStatus
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.status = status
    }
}

public struct PermissionDiagnosticsState: Equatable, Sendable {
    public let items: [PermissionDiagnosticItem]
    public let compatibleModeDetail: String?

    public init(items: [PermissionDiagnosticItem], compatibleModeDetail: String?) {
        self.items = items
        self.compatibleModeDetail = compatibleModeDetail
    }
}

public struct SettingsViewState: Equatable, Sendable {
    public let connections: ConnectionsSettingsState
    public let recording: RecordingSettingsState
    public let mcp: MCPSettingsState
    public let permissions: PermissionDiagnosticsState

    public init(
        connections: ConnectionsSettingsState,
        recording: RecordingSettingsState,
        mcp: MCPSettingsState,
        permissions: PermissionDiagnosticsState
    ) {
        self.connections = connections
        self.recording = recording
        self.mcp = mcp
        self.permissions = permissions
    }
}
