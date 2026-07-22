import MeetcoCore
import SwiftUI

public struct ProviderStatusView: View {
    public let name: String
    public let health: ProviderHealth
    public let repairTitle: String?
    public let onRepair: (() -> Void)?

    public init(
        name: String,
        health: ProviderHealth,
        repairTitle: String? = nil,
        onRepair: (() -> Void)? = nil
    ) {
        self.name = name
        self.health = health
        self.repairTitle = repairTitle
        self.onRepair = onRepair
    }

    public var body: some View {
        HStack(alignment: .center, spacing: MeetcoTheme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(toneColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: MeetcoTheme.Spacing.small) {
                    Text(name)
                        .font(.meetcoSection)
                    if let version = health.version {
                        Text(version)
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                    }
                }
                Text(health.detail)
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: MeetcoTheme.Spacing.small)

            if let repairTitle, let onRepair, health.state != .ready {
                Button(repairTitle, action: onRepair)
                    .controlSize(.small)
            } else {
                StatusBadge(statusLabel, systemImage: symbol, tone: statusTone)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(statusLabel), \(health.detail)")
    }

    private var statusLabel: String {
        switch health.state {
        case .ready: "Ready"
        case .notConfigured: "Not configured"
        case .notInstalled: "Not installed"
        case .needsLogin: "Login needed"
        case .unsupported: "Unsupported"
        case .unavailable: "Unavailable"
        }
    }

    private var symbol: String {
        health.state == .ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    private var statusTone: MeetcoStatusTone {
        health.state == .ready ? .success : .warning
    }

    private var toneColor: Color {
        health.state == .ready ? MeetcoTheme.success : MeetcoTheme.warning
    }
}
