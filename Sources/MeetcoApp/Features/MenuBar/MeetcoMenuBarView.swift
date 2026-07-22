import MeetcoCore
import SwiftUI

public struct MeetcoMenuBarState: Equatable, Sendable {
    public let activeMeetingTitle: String?
    public let recordingStatus: MeetingStatus?
    public let elapsedMilliseconds: Int64
    public let lastPreset: MeetingConfiguration
    public let canStart: Bool
    public let readinessDetail: String

    public init(
        activeMeetingTitle: String?,
        recordingStatus: MeetingStatus?,
        elapsedMilliseconds: Int64,
        lastPreset: MeetingConfiguration,
        canStart: Bool,
        readinessDetail: String
    ) {
        self.activeMeetingTitle = activeMeetingTitle
        self.recordingStatus = recordingStatus
        self.elapsedMilliseconds = elapsedMilliseconds
        self.lastPreset = lastPreset
        self.canStart = canStart
        self.readinessDetail = readinessDetail
    }
}

public struct MeetcoMenuBarView: View {
    public let state: MeetcoMenuBarState
    public let onStartLastPreset: () -> Void
    public let onOpenMeeting: () -> Void
    public let onPauseResume: () -> Void
    public let onStop: () -> Void
    public let onOpenMeetco: () -> Void
    public let onOpenSettings: () -> Void

    public init(
        state: MeetcoMenuBarState,
        onStartLastPreset: @escaping () -> Void,
        onOpenMeeting: @escaping () -> Void,
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onOpenMeetco: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.state = state
        self.onStartLastPreset = onStartLastPreset
        self.onOpenMeeting = onOpenMeeting
        self.onPauseResume = onPauseResume
        self.onStop = onStop
        self.onOpenMeetco = onOpenMeetco
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
            if let title = state.activeMeetingTitle, let status = state.recordingStatus {
                VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                    HStack {
                        Circle()
                            .fill(MeetcoTheme.recording)
                            .frame(width: 9, height: 9)
                            .meetcoRecordingPulse(active: status == .recording)
                        Text(status == .paused ? "Paused" : "Recording")
                            .font(.meetcoSection)
                        Spacer()
                        Text(MeetcoFormatting.duration(milliseconds: state.elapsedMilliseconds))
                            .font(.meetcoTimer)
                            .monospacedDigit()
                    }
                    Text(title)
                        .font(.meetcoBody)
                        .lineLimit(1)
                    Label("Audio is saving locally", systemImage: "internaldrive.fill")
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.success)
                }

                Button("Open live meeting", systemImage: "macwindow", action: onOpenMeeting)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                HStack {
                    Button(status == .paused ? "Resume" : "Pause", action: onPauseResume)
                    Spacer()
                    Button("Stop", systemImage: "stop.fill", action: onStop)
                        .tint(MeetcoTheme.recording)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ready to record").font(.meetcoSection)
                    Text(state.readinessDetail)
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                }
                Button("Start \(MeetcoFormatting.captureMode(state.lastPreset.captureMode))", systemImage: "record.circle", action: onStartLastPreset)
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.canStart)
                    .frame(maxWidth: .infinity)
                Text("\(MeetcoFormatting.transcriptionMode(state.lastPreset.transcriptionMode)) · \(MeetcoFormatting.provider(state.lastPreset.agentProvider))")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }

            Divider()
            Button("Open Meetco", systemImage: "macwindow", action: onOpenMeetco)
            Button("Settings…", systemImage: "gearshape", action: onOpenSettings)
        }
        .padding(MeetcoTheme.Spacing.large)
        .frame(width: 300)
    }
}
