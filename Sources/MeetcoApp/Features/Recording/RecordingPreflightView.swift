import MeetcoCore
import SwiftUI

public struct RecordingPreflightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAdvanced = false
    @State private var meetingTitle = ""

    public let state: RecordingPreflightState
    public let onConfigurationChange: (MeetingConfiguration) -> Void
    public let onStart: (String) -> Void
    public let onOpenConnections: () -> Void

    public init(
        state: RecordingPreflightState,
        onConfigurationChange: @escaping (MeetingConfiguration) -> Void,
        onStart: @escaping (String) -> Void,
        onOpenConnections: @escaping () -> Void
    ) {
        self.state = state
        self.onConfigurationChange = onConfigurationChange
        self.onStart = onStart
        self.onOpenConnections = onOpenConnections
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                    studioHeader
                    captureSection
                    transcriptionSection
                    outputAndProviders
                    advancedSection
                }
                .padding(MeetcoTheme.Spacing.xLarge)
            }
            Divider()
            footer
        }
        .frame(minWidth: 760, idealWidth: 840, minHeight: 640, idealHeight: 720)
        .background(MeetcoTheme.canvas)
    }

    private var studioHeader: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEW RECORDING")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(MeetcoTheme.accent)
                    Text("Set up the capture")
                        .font(.meetcoDisplay)
                        .foregroundStyle(MeetcoTheme.textPrimary)
                    Text("Audio lands on this Mac before any optional provider receives it.")
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                }
                Spacer()
                StudioWaveformView(color: MeetcoTheme.accent, spacing: 5)
                    .opacity(0.5)
            }

            TextField(
                "",
                text: $meetingTitle,
                prompt: Text("Name this meeting (optional)")
                    .foregroundStyle(MeetcoTheme.textSecondary)
            )
            .font(.meetcoSection)
            .foregroundStyle(MeetcoTheme.textPrimary)
            .textFieldStyle(.plain)
            .padding(.horizontal, MeetcoTheme.Spacing.medium)
            .frame(maxWidth: 440, minHeight: 40)
            .background(MeetcoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                    .stroke(MeetcoTheme.border)
            }
            .accessibilityLabel("Meeting title")
        }
        .padding(.bottom, MeetcoTheme.Spacing.small)
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
            PreflightSectionHeader(
                title: "Where is it happening?",
                detail: "Online captures system audio + mic. On-site uses the room microphone."
            )
            captureModes
        }
    }

    private var captureModes: some View {
        HStack(spacing: MeetcoTheme.Spacing.medium) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                CaptureModeCard(mode: mode, isSelected: state.configuration.captureMode == mode) {
                    update { $0.captureMode = mode }
                }
            }
        }
    }

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
            PreflightSectionHeader(
                title: "When should Meetco transcribe?",
                detail: "Live unlocks the embedded meeting copilot while recording."
            )
            TranscriptionModeSelector(selection: state.configuration.transcriptionMode) { mode in
                update {
                    $0.transcriptionMode = mode
                    if mode == .recordOnly {
                        $0.audioRetention = .audioOnly
                        $0.polishWithBatchAfterRealtime = false
                    } else if $0.audioRetention == .audioOnly {
                        $0.audioRetention = .keepAudio
                    }
                }
            }
        }
    }

    private var outputAndProviders: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: MeetcoTheme.Spacing.large) {
                PreflightOutputPanel(
                    configuration: state.configuration,
                    onChange: onConfigurationChange
                )
                .frame(minWidth: 390)
                PreflightProviderPanel(state: state, onOpenConnections: onOpenConnections)
                    .frame(minWidth: 290, maxWidth: 330)
            }
            VStack(spacing: MeetcoTheme.Spacing.large) {
                PreflightOutputPanel(
                    configuration: state.configuration,
                    onChange: onConfigurationChange
                )
                PreflightProviderPanel(state: state, onOpenConnections: onOpenConnections)
            }
        }
    }

    private var advancedSection: some View {
        DisclosureGroup("Advanced", isExpanded: $showsAdvanced) { advancedControls }
            .font(.meetcoSection)
            .padding(MeetcoTheme.Spacing.large)
            .background(MeetcoTheme.surfaceMuted.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous))
            .animation(MeetcoMotion.micro(reduceMotion: reduceMotion), value: showsAdvanced)
    }

    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
            Toggle("Polish with final batch transcript", isOn: binding(\.polishWithBatchAfterRealtime))
            Toggle("Allow read-only meeting MCP", isOn: binding(\.mcpEnabled))
            Text("Vocabulary and language can be adjusted in Recording settings.")
                .font(.meetcoMetadata)
                .foregroundStyle(MeetcoTheme.textSecondary)
        }
        .padding(.top, MeetcoTheme.Spacing.medium)
    }

    private var footer: some View {
        HStack {
            if let reason = state.blockingReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.warning)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button {
                onStart(resolvedMeetingTitle)
            } label: {
                Label("Start recording", systemImage: "record.circle.fill")
            }
                .buttonStyle(MeetcoActionButtonStyle(tone: .recording))
                .disabled(!state.canStart)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, MeetcoTheme.Spacing.xLarge)
        .padding(.vertical, MeetcoTheme.Spacing.large)
        .background(MeetcoTheme.surface)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<MeetingConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { state.configuration[keyPath: keyPath] },
            set: { value in update { $0[keyPath: keyPath] = value } }
        )
    }

    private func update(_ transform: (inout MeetingConfiguration) -> Void) {
        var configuration = state.configuration
        transform(&configuration)
        onConfigurationChange(configuration)
    }

    private var resolvedMeetingTitle: String {
        let title = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled meeting" : title
    }
}
