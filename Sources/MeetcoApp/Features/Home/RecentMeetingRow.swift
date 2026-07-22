import MeetcoCore
import SwiftUI

public struct RecentMeetingRow: View {
    public let state: RecentMeetingState
    public let onOpen: () -> Void

    public init(state: RecentMeetingState, onOpen: @escaping () -> Void) {
        self.state = state
        self.onOpen = onOpen
    }

    public var body: some View {
        Button(action: onOpen) {
            HStack(spacing: MeetcoTheme.Spacing.medium) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MeetcoTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(MeetcoTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control))

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.meeting.title)
                        .font(.meetcoSection)
                        .foregroundStyle(MeetcoTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: MeetcoTheme.Spacing.small) {
                        Text(state.meeting.createdAt, format: .relative(presentation: .named))
                        if state.meeting.durationMilliseconds > 0 {
                            Text("·")
                            Text(MeetcoFormatting.duration(milliseconds: state.meeting.durationMilliseconds))
                        }
                        if state.actionCount > 0 {
                            Text("·")
                            Text("\(state.actionCount) action\(state.actionCount == 1 ? "" : "s")")
                        }
                    }
                    .font(.meetcoMetadata)
                    .lineLimit(1)
                    .foregroundStyle(MeetcoTheme.textSecondary)
                }

                Spacer()
                StatusBadge(statusLabel, systemImage: statusSymbol, tone: statusTone)
                Image(systemName: "chevron.right")
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(state.meeting.title), \(statusLabel)")
    }

    private var statusLabel: String {
        if let version = state.transcriptVersion {
            return version == .final ? "Final" : "Provisional"
        }
        return switch state.meeting.status {
        case .recording: "Recording"
        case .paused: "Paused"
        case .finalizing: "Finalizing"
        case .completed: "Completed"
        case .failed: "Failed"
        case .recoverable: "Files preserved"
        case .draft: "Draft"
        }
    }

    private var statusSymbol: String {
        switch state.meeting.status {
        case .failed: "exclamationmark.triangle.fill"
        case .recording, .paused: "record.circle"
        case .finalizing: "clock"
        default: state.transcriptVersion == .final ? "checkmark.circle.fill" : "doc.text"
        }
    }

    private var statusTone: MeetcoStatusTone {
        switch state.meeting.status {
        case .failed: .error
        case .recording, .paused: .recording
        case .finalizing, .recoverable: .warning
        default: state.transcriptVersion == .final ? .success : .neutral
        }
    }
}
