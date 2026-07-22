import MeetcoCore
import SwiftUI

public struct ConnectionsSettingsView: View {
    @State private var elevenLabsKey = ""
    @State private var anthropicKey = ""

    public let state: ConnectionsSettingsState
    public let onSaveElevenLabsKey: (String) -> Void
    public let onSaveAnthropicKey: (String) -> Void
    public let onSelectAgent: (AgentProviderKind) -> Void
    public let onModelChange: (String) -> Void
    public let onRefresh: () -> Void

    public init(
        state: ConnectionsSettingsState,
        onSaveElevenLabsKey: @escaping (String) -> Void,
        onSaveAnthropicKey: @escaping (String) -> Void,
        onSelectAgent: @escaping (AgentProviderKind) -> Void,
        onModelChange: @escaping (String) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.state = state
        self.onSaveElevenLabsKey = onSaveElevenLabsKey
        self.onSaveAnthropicKey = onSaveAnthropicKey
        self.onSelectAgent = onSelectAgent
        self.onModelChange = onModelChange
        self.onRefresh = onRefresh
    }

    public var body: some View {
        SettingsPage {
            SettingsPanel(
                "Provider health",
                detail: "Live status for transcription and meeting copilots.",
                systemImage: "antenna.radiowaves.left.and.right"
            ) {
                ForEach(state.providers) { provider in
                    ProviderStatusView(name: provider.name, health: provider.health)
                    if provider.id != state.providers.last?.id { Divider() }
                }
                HStack {
                    Spacer()
                    Button("Refresh status", systemImage: "arrow.clockwise", action: onRefresh)
                }
            }

            SettingsPanel(
                "ElevenLabs Scribe",
                detail: "Used only for Live or After meeting transcription.",
                systemImage: "waveform.badge.mic"
            ) {
                SecureField("ElevenLabs API key", text: $elevenLabsKey)
                    .textFieldStyle(MeetcoSettingsTextFieldStyle())
                HStack {
                    Label("Stored in macOS Keychain", systemImage: "lock.fill")
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                    Spacer()
                    Button("Save ElevenLabs key") { saveElevenLabsKey() }
                        .buttonStyle(MeetcoActionButtonStyle())
                        .disabled(cleanElevenLabsKey.isEmpty)
                }
            }

            SettingsPanel(
                "Meeting copilot",
                detail: "Choose the agent that receives meeting context when asked.",
                systemImage: "sparkles"
            ) {
                SettingsLabeledRow("Default provider", detail: "Can be changed for each recording") {
                    Picker("Default provider", selection: agentBinding) {
                        ForEach(AgentProviderKind.allCases, id: \.self) { provider in
                            Text(MeetcoFormatting.provider(provider)).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 210)
                }
                TextField("Anthropic model", text: modelBinding)
                    .textFieldStyle(MeetcoSettingsTextFieldStyle())
                SecureField("Anthropic API key", text: $anthropicKey)
                    .textFieldStyle(MeetcoSettingsTextFieldStyle())
                HStack {
                    Text("CLI providers use their own login and run one clean process per turn.")
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                    Spacer()
                    Button("Save Anthropic key") { saveAnthropicKey() }
                        .buttonStyle(MeetcoActionButtonStyle())
                        .disabled(cleanAnthropicKey.isEmpty)
                }
            }
        }
    }

    private var agentBinding: Binding<AgentProviderKind> {
        Binding(get: { state.selectedAgent }, set: { value in onSelectAgent(value) })
    }

    private var modelBinding: Binding<String> {
        Binding(get: { state.anthropicModel }, set: { value in onModelChange(value) })
    }

    private var cleanElevenLabsKey: String {
        elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanAnthropicKey: String {
        anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveElevenLabsKey() {
        guard !cleanElevenLabsKey.isEmpty else { return }
        onSaveElevenLabsKey(cleanElevenLabsKey)
        elevenLabsKey = ""
    }

    private func saveAnthropicKey() {
        guard !cleanAnthropicKey.isEmpty else { return }
        onSaveAnthropicKey(cleanAnthropicKey)
        anthropicKey = ""
    }
}
