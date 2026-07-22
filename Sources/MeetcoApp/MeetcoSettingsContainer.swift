import MeetcoCore
import SwiftUI

struct MeetcoSettingsContainer: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsView(
            selection: $model.settingsSection,
            state: MeetcoViewStateFactory.settings(model),
            onSaveElevenLabsKey: { model.saveSecret($0, for: .elevenLabsAPIKey) },
            onSaveAnthropicKey: { model.saveSecret($0, for: .anthropicAPIKey) },
            onSelectAgent: model.updateDefaultAgent,
            onModelChange: model.updateAnthropicModel,
            onRefreshProviders: refresh,
            onRecordingConfigurationChange: model.updateDefaultConfiguration,
            onRevealStorage: model.revealStorage,
            onSetMCPEnabled: model.setDefaultMCPEnabled,
            onCopyMCPConfiguration: model.copyMCPConfiguration,
            onRunMCPDiagnostics: model.runMCPDiagnostics,
            onRequestPermission: model.requestPermission,
            onOpenPermissionSettings: model.openPermissionSettings,
            onRefreshPermissions: refresh
        )
    }

    private func refresh() {
        Task { await model.refreshDiagnostics() }
    }
}
