import Foundation
import MeetcoCore

extension MeetcoViewStateFactory {
    static func settings(_ model: AppModel) -> SettingsViewState {
        let root = model.dependencies?.paths.root.path ?? "Meetco storage unavailable"
        let snapshot = model.dependencies?.paths.liveSnapshotURL
        let snapshotExists = snapshot.map {
            FileManager.default.fileExists(atPath: $0.path)
        } ?? false
        let mcpHosted = model.dependencies?.mcpHTTPServer != nil

        return SettingsViewState(
            connections: ConnectionsSettingsState(
                providers: [
                    ProviderConnectionState(
                        id: "elevenlabs",
                        name: "ElevenLabs Scribe",
                        kind: nil,
                        health: transcriptionHealth(model)
                    ),
                    providerConnection(.claudeAPI, model: model),
                    providerConnection(.claudeCLI, model: model),
                    providerConnection(.codexCLI, model: model),
                ],
                selectedAgent: model.settings.defaultConfiguration.agentProvider,
                anthropicModel: model.settings.anthropicModel
            ),
            recording: RecordingSettingsState(
                configuration: model.settings.defaultConfiguration,
                storageLocation: root
            ),
            mcp: MCPSettingsState(
                isEnabled: model.settings.defaultConfiguration.mcpEnabled,
                health: model.mcpDiagnosticHealth ?? ProviderHealth(
                    state: mcpHosted ? .ready : .unavailable,
                    detail: mcpHosted
                        ? "Local HTTP endpoint is hosted while Meetco runs"
                        : "Meetco storage is unavailable"
                ),
                configurationText: model.mcpConfigurationText,
                snapshotDetail: snapshotExists
                    ? "Live snapshot ready at \(snapshot?.path ?? "")"
                    : "A snapshot appears here while MCP is enabled for a meeting"
            ),
            permissions: PermissionDiagnosticsState(
                items: [
                    permission(
                        id: "microphone",
                        title: "Microphone",
                        detail: "Required for every recording",
                        systemImage: "mic.fill",
                        availability: model.captureStatus.microphone
                    ),
                    permission(
                        id: "screen",
                        title: "Screen & System Audio",
                        detail: "Required only for online meeting capture",
                        systemImage: "rectangle.on.rectangle",
                        availability: model.captureStatus.systemAudio
                    ),
                ],
                compatibleModeDetail: model.captureStatus.microphone == .ready
                    ? "On-site microphone recording is available."
                    : nil
            )
        )
    }
}
