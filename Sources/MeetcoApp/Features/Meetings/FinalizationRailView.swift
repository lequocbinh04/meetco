import SwiftUI

public struct FinalizationRailView: View {
    public let stages: [FinalizationStageState]
    public let onRetry: (String) -> Void

    public init(stages: [FinalizationStageState], onRetry: @escaping (String) -> Void) {
        self.stages = stages
        self.onRetry = onRetry
    }

    public var body: some View {
        MeetcoCard {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finalizing meeting").font(.meetcoSection)
                        Text("Your local recording is already safe. You can leave this view.")
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                    }
                    Spacer()
                    ProgressView().controlSize(.small)
                }
                HStack(spacing: 0) {
                    ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                        stageView(stage)
                        if index < stages.count - 1 {
                            Rectangle()
                                .fill(stageColor(stage))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func stageView(_ stage: FinalizationStageState) -> some View {
        VStack(spacing: MeetcoTheme.Spacing.small) {
            Image(systemName: stageSymbol(stage))
                .foregroundStyle(stageColor(stage))
                .frame(width: 28, height: 28)
                .background(stageColor(stage).opacity(0.1))
                .clipShape(Circle())
            Text(stage.title).font(.meetcoMetadata)
            if case let .failed(message) = stage.status {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(MeetcoTheme.error)
                    .lineLimit(1)
                Button("Retry") { onRetry(stage.id) }
                    .controlSize(.mini)
            }
        }
        .frame(minWidth: 92)
        .accessibilityElement(children: .combine)
    }

    private func stageSymbol(_ stage: FinalizationStageState) -> String {
        switch stage.status {
        case .pending: "circle"
        case .running: "clock.arrow.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        }
    }

    private func stageColor(_ stage: FinalizationStageState) -> Color {
        switch stage.status {
        case .pending: MeetcoTheme.textSecondary
        case .running: MeetcoTheme.accent
        case .completed: MeetcoTheme.success
        case .failed: MeetcoTheme.error
        }
    }
}
