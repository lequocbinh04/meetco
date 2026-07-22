import MeetcoCore
import SwiftUI

public enum MeetcoSettingsSection: String, CaseIterable, Identifiable, Sendable {
    case connections = "Connections"
    case recording = "Recording"
    case mcp = "MCP"
    case permissions = "Permissions"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .connections: "link"
        case .recording: "waveform.and.mic"
        case .mcp: "point.3.connected.trianglepath.dotted"
        case .permissions: "checkmark.shield"
        }
    }
}

public struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var selection: MeetcoSettingsSection
    public let state: SettingsViewState
    public let onSaveElevenLabsKey: (String) -> Void
    public let onSaveAnthropicKey: (String) -> Void
    public let onSelectAgent: (AgentProviderKind) -> Void
    public let onModelChange: (String) -> Void
    public let onRefreshProviders: () -> Void
    public let onRecordingConfigurationChange: (MeetingConfiguration) -> Void
    public let onRevealStorage: () -> Void
    public let onSetMCPEnabled: (Bool) -> Void
    public let onCopyMCPConfiguration: () -> Void
    public let onRunMCPDiagnostics: () -> Void
    public let onRequestPermission: (String) -> Void
    public let onOpenPermissionSettings: (String) -> Void
    public let onRefreshPermissions: () -> Void

    public init(
        selection: Binding<MeetcoSettingsSection>,
        state: SettingsViewState,
        onSaveElevenLabsKey: @escaping (String) -> Void,
        onSaveAnthropicKey: @escaping (String) -> Void,
        onSelectAgent: @escaping (AgentProviderKind) -> Void,
        onModelChange: @escaping (String) -> Void,
        onRefreshProviders: @escaping () -> Void,
        onRecordingConfigurationChange: @escaping (MeetingConfiguration) -> Void,
        onRevealStorage: @escaping () -> Void,
        onSetMCPEnabled: @escaping (Bool) -> Void,
        onCopyMCPConfiguration: @escaping () -> Void,
        onRunMCPDiagnostics: @escaping () -> Void,
        onRequestPermission: @escaping (String) -> Void,
        onOpenPermissionSettings: @escaping (String) -> Void,
        onRefreshPermissions: @escaping () -> Void
    ) {
        self._selection = selection
        self.state = state
        self.onSaveElevenLabsKey = onSaveElevenLabsKey
        self.onSaveAnthropicKey = onSaveAnthropicKey
        self.onSelectAgent = onSelectAgent
        self.onModelChange = onModelChange
        self.onRefreshProviders = onRefreshProviders
        self.onRecordingConfigurationChange = onRecordingConfigurationChange
        self.onRevealStorage = onRevealStorage
        self.onSetMCPEnabled = onSetMCPEnabled
        self.onCopyMCPConfiguration = onCopyMCPConfiguration
        self.onRunMCPDiagnostics = onRunMCPDiagnostics
        self.onRequestPermission = onRequestPermission
        self.onOpenPermissionSettings = onOpenPermissionSettings
        self.onRefreshPermissions = onRefreshPermissions
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        settingsTitle
                        Spacer()
                        localProfile
                    }
                    settingsTitle
                }

                sectionSwitcher
            }
            .padding(.horizontal, MeetcoTheme.Spacing.xxLarge)
            .padding(.top, MeetcoTheme.Spacing.small)
            .padding(.bottom, MeetcoTheme.Spacing.large)

            detail
                .id(selection)
                .transition(MeetcoMotion.replacement(reduceMotion: reduceMotion))
                .animation(MeetcoMotion.panel(reduceMotion: reduceMotion), value: selection)
        }
        .background(MeetcoTheme.canvas)
        .frame(minWidth: 620, minHeight: 520)
    }

    private var settingsTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Settings")
                .font(.meetcoDisplay)
                .foregroundStyle(MeetcoTheme.textPrimary)
            Text("Connections, capture defaults, and local access")
                .font(.meetcoMetadata)
                .foregroundStyle(MeetcoTheme.textSecondary)
        }
    }

    private var localProfile: some View {
        StatusBadge("Local profile", systemImage: "internaldrive.fill", tone: .success)
    }

    private var sectionSwitcher: some View {
        HStack(spacing: MeetcoTheme.Spacing.xSmall) {
            ForEach(MeetcoSettingsSection.allCases) { section in
                settingsTab(section)
            }
        }
        .padding(MeetcoTheme.Spacing.xSmall)
        .background(MeetcoTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control + 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control + 4, style: .continuous)
                .strokeBorder(MeetcoTheme.border.opacity(0.6))
        }
    }

    private func settingsTab(_ section: MeetcoSettingsSection) -> some View {
        let isSelected = selection == section
        return Button { selection = section } label: {
            Label(section.rawValue, systemImage: section.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .foregroundStyle(isSelected ? MeetcoTheme.textPrimary : MeetcoTheme.textSecondary)
                .padding(.horizontal, MeetcoTheme.Spacing.medium)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                            .fill(MeetcoTheme.surface)
                            .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .connections:
            ConnectionsSettingsView(
                state: state.connections,
                onSaveElevenLabsKey: onSaveElevenLabsKey,
                onSaveAnthropicKey: onSaveAnthropicKey,
                onSelectAgent: onSelectAgent,
                onModelChange: onModelChange,
                onRefresh: onRefreshProviders
            )
        case .recording:
            RecordingSettingsView(
                state: state.recording,
                onConfigurationChange: onRecordingConfigurationChange,
                onRevealStorage: onRevealStorage
            )
        case .mcp:
            MCPSettingsView(
                state: state.mcp,
                onSetEnabled: onSetMCPEnabled,
                onCopyConfiguration: onCopyMCPConfiguration,
                onRunDiagnostics: onRunMCPDiagnostics
            )
        case .permissions:
            PermissionDiagnosticsView(
                state: state.permissions,
                onRequest: onRequestPermission,
                onOpenSystemSettings: onOpenPermissionSettings,
                onRefresh: onRefreshPermissions
            )
        }
    }
}
