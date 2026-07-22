import Foundation
import MeetcoCore

extension MeetcoViewStateFactory {
    static func settings(_ model: AppModel) -> SettingsViewState {
        let root = model.dependencies?.paths.root.path ?? "Meetco storage unavailable"
        let snapshot = model.dependencies?.paths.liveSnapshotURL
        let snapshotExists = snapshot.map {
            FileManager.default.fileExists(atPath: $0.path)
        } ?? false
        let mcpBinary = model.mcpExecutableURL
        let mcpExists = mcpBinary.map {
            FileManager.default.isExecutableFile(atPath: $0.path)
        } ?? false

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
                    state: mcpExists ? .ready : .unavailable,
                    detail: mcpExists
                        ? "Read-only local server is available"
                        : "MeetcoMCP is missing from the app bundle"
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
