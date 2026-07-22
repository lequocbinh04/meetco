import SwiftUI

public struct MCPSettingsView: View {
    public let state: MCPSettingsState
    public let onSetEnabled: (Bool) -> Void
    public let onCopyConfiguration: () -> Void
    public let onRunDiagnostics: () -> Void

    public init(
        state: MCPSettingsState,
        onSetEnabled: @escaping (Bool) -> Void,
        onCopyConfiguration: @escaping () -> Void,
        onRunDiagnostics: @escaping () -> Void
    ) {
        self.state = state
        self.onSetEnabled = onSetEnabled
        self.onCopyConfiguration = onCopyConfiguration
        self.onRunDiagnostics = onRunDiagnostics
    }

    public var body: some View {
        SettingsPage {
            SettingsPanel(
                "Read-only meeting MCP",
                detail: "Expose the opted-in live snapshot to local agent clients.",
                systemImage: "point.3.connected.trianglepath.dotted"
            ) {
                Toggle("Enable read-only meeting MCP", isOn: enabledBinding)
                Text("Meetco MCP exposes exported snapshots and transcript search. It cannot write meetings or access API keys and audio paths.")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
                ProviderStatusView(name: "Meetco MCP server", health: state.health)
                LabeledContent("Snapshot") {
                    Text(state.snapshotDetail)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                }
            }

            SettingsPanel(
                "Client configuration",
                detail: "Meetco hosts a local HTTP endpoint on 127.0.0.1 — paste this into Claude, Codex, or another MCP client.",
                systemImage: "terminal"
            ) {
                if state.configurationText.isEmpty {
                    Text("Configuration becomes available when MCP is enabled.")
                        .foregroundStyle(MeetcoTheme.textSecondary)
                } else {
                    ScrollView(.horizontal) {
                        Text(state.configurationText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(MeetcoTheme.Spacing.medium)
                    }
                    .background(MeetcoTheme.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control))
                    Button("Copy configuration", systemImage: "doc.on.doc", action: onCopyConfiguration)
                }
            }

            SettingsPanel(
                "Diagnostics",
                detail: "Test the bundled server without touching recording state.",
                systemImage: "stethoscope"
            ) {
                Button("Test server", systemImage: "stethoscope", action: onRunDiagnostics)
                Text("An MCP failure never interrupts recording, transcription, or local storage.")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { state.isEnabled }, set: { value in onSetEnabled(value) })
    }
}
