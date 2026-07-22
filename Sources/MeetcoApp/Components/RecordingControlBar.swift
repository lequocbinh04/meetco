import MeetcoCore
import SwiftUI

public struct RecordingControlState: Equatable, Sendable {
    public let status: MeetingStatus
    public let elapsedMilliseconds: Int64
    public let microphoneLevel: Float
    public let systemLevel: Float?
    public let localStatus: String

    public init(
        status: MeetingStatus,
        elapsedMilliseconds: Int64,
        microphoneLevel: Float,
        systemLevel: Float?,
        localStatus: String
    ) {
        self.status = status
        self.elapsedMilliseconds = elapsedMilliseconds
        self.microphoneLevel = microphoneLevel
        self.systemLevel = systemLevel
        self.localStatus = localStatus
    }
}

public struct RecordingControlBar: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public let state: RecordingControlState
    public let onPauseResume: () -> Void
    public let onStop: () -> Void

    public init(
        state: RecordingControlState,
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self.state = state
        self.onPauseResume = onPauseResume
        self.onStop = onStop
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            wideControls
                .fixedSize(horizontal: true, vertical: false)
            compactControls
        }
        .padding(.horizontal, MeetcoTheme.Spacing.large)
        .padding(.vertical, MeetcoTheme.Spacing.small)
        .frame(minHeight: 58)
        .background(reduceTransparency ? AnyShapeStyle(MeetcoTheme.elevated) : AnyShapeStyle(.regularMaterial))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var wideControls: some View {
        HStack(spacing: MeetcoTheme.Spacing.large) {
            recordingStatus
            meters
            Spacer(minLength: MeetcoTheme.Spacing.small)
            localStatus
            actions
        }
    }

    private var compactControls: some View {
        VStack(spacing: MeetcoTheme.Spacing.small) {
            HStack(spacing: MeetcoTheme.Spacing.medium) {
                recordingStatus
                Spacer(minLength: MeetcoTheme.Spacing.small)
                actions
            }
            HStack(spacing: MeetcoTheme.Spacing.medium) {
                meters
                Spacer(minLength: MeetcoTheme.Spacing.small)
                localStatus
            }
        }
    }

    private var recordingStatus: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            Circle()
                .fill(MeetcoTheme.recording)
                .frame(width: 9, height: 9)
                .meetcoRecordingPulse(active: state.status == .recording)
            Text(state.status == .paused ? "Paused" : "Recording")
                .font(.meetcoSection)
            Text(MeetcoFormatting.duration(milliseconds: state.elapsedMilliseconds))
                .font(.meetcoTimer)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.status == .paused ? "Paused" : "Recording"), elapsed \(MeetcoFormatting.duration(milliseconds: state.elapsedMilliseconds))")
    }

    private var meters: some View {
        HStack(spacing: MeetcoTheme.Spacing.large) {
            LiveWaveformView(
                label: "Microphone",
                level: state.microphoneLevel,
                systemImage: "mic.fill",
                isActive: state.status == .recording
            )
            if let level = state.systemLevel {
                LiveWaveformView(
                    label: "System",
                    level: level,
                    systemImage: "speaker.wave.2.fill",
                    isActive: state.status == .recording
                )
            }
        }
    }

    private var localStatus: some View {
        StatusBadge(state.localStatus, systemImage: "internaldrive.fill", tone: .success)
    }

    private var actions: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            Button(state.status == .paused ? "Resume" : "Pause", action: onPauseResume)
                .keyboardShortcut(.space, modifiers: [])
            Button("Stop", systemImage: "stop.fill", action: onStop)
                .buttonStyle(.borderedProminent)
                .tint(MeetcoTheme.recording)
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
