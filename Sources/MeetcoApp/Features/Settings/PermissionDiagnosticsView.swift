import SwiftUI

public struct PermissionDiagnosticsView: View {
    public let state: PermissionDiagnosticsState
    public let onRequest: (String) -> Void
    public let onOpenSystemSettings: (String) -> Void
    public let onRefresh: () -> Void

    public init(
        state: PermissionDiagnosticsState,
        onRequest: @escaping (String) -> Void,
        onOpenSystemSettings: @escaping (String) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.state = state
        self.onRequest = onRequest
        self.onOpenSystemSettings = onOpenSystemSettings
        self.onRefresh = onRefresh
    }

    public var body: some View {
        SettingsPage {
            SettingsPanel(
                "Capture permissions",
                detail: "Meetco requests only the access required by the selected recording mode.",
                systemImage: "checkmark.shield"
            ) {
                if state.items.isEmpty {
                    Text("No permission diagnostics are available.")
                        .foregroundStyle(MeetcoTheme.textSecondary)
                } else {
                    ForEach(state.items) { item in diagnosticRow(item) }
                }
                Button("Refresh diagnostics", systemImage: "arrow.clockwise", action: onRefresh)
            }

            if let detail = state.compatibleModeDetail {
                SettingsPanel(
                    "Compatible mode",
                    detail: "A recording path available with the current grants.",
                    systemImage: "mic.fill"
                ) {
                    Label(detail, systemImage: "mic.fill")
                        .foregroundStyle(MeetcoTheme.textSecondary)
                }
            }
        }
    }

    private func diagnosticRow(_ item: PermissionDiagnosticItem) -> some View {
        HStack(spacing: MeetcoTheme.Spacing.medium) {
            Image(systemName: item.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(statusColor(item.status))
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.meetcoSection)
                Text(item.detail).font(.meetcoMetadata).foregroundStyle(MeetcoTheme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.title), \(statusLabel(item.status)), \(item.detail)")
            Spacer()
            StatusBadge(statusLabel(item.status), systemImage: statusSymbol(item.status), tone: statusTone(item.status))
            switch item.status {
            case .denied:
                Button("Open System Settings") { onOpenSystemSettings(item.id) }
            case .notRequested:
                Button("Request") { onRequest(item.id) }
            case .granted, .unavailable:
                EmptyView()
            }
        }
        .padding(.vertical, MeetcoTheme.Spacing.xSmall)
    }

    private func statusLabel(_ status: PermissionDiagnosticStatus) -> String {
        switch status {
        case .granted: "Granted"
        case .denied: "Denied"
        case .notRequested: "Not requested"
        case .unavailable: "Unavailable"
        }
    }

    private func statusSymbol(_ status: PermissionDiagnosticStatus) -> String {
        switch status {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notRequested: "questionmark.circle.fill"
        case .unavailable: "minus.circle.fill"
        }
    }

    private func statusTone(_ status: PermissionDiagnosticStatus) -> MeetcoStatusTone {
        switch status {
        case .granted: .success
        case .denied: .error
        case .notRequested: .warning
        case .unavailable: .neutral
        }
    }

    private func statusColor(_ status: PermissionDiagnosticStatus) -> Color {
        switch status {
        case .granted: MeetcoTheme.success
        case .denied: MeetcoTheme.error
        case .notRequested: MeetcoTheme.warning
        case .unavailable: MeetcoTheme.textSecondary
        }
    }
}
