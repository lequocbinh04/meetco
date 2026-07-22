import SwiftUI

public struct LiveMeetingView: View {
    @State private var showsCopilot = false
    @State private var selectedTranscriptID: UUID?
    public let state: LiveMeetingState
    public let onPauseResume: () -> Void
    public let onStop: () -> Void
    public let onNotesChange: (String) -> Void
    public let onSendMessage: (String) -> Void
    public let onSelectTranscriptSegment: (UUID) -> Void

    public init(
        state: LiveMeetingState,
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onNotesChange: @escaping (String) -> Void,
        onSendMessage: @escaping (String) -> Void,
        onSelectTranscriptSegment: @escaping (UUID) -> Void
    ) {
        self.state = state
        self.onPauseResume = onPauseResume
        self.onStop = onStop
        self.onNotesChange = onNotesChange
        self.onSendMessage = onSendMessage
        self.onSelectTranscriptSegment = onSelectTranscriptSegment
    }

    public var body: some View {
        VStack(spacing: 0) {
            RecordingControlBar(
                state: state.controls,
                onPauseResume: onPauseResume,
                onStop: onStop
            )
            if let notice = state.transcriptNotice {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: MeetcoTheme.Spacing.small) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(notice).lineLimit(1)
                        Spacer()
                        StatusBadge("Recording locally", systemImage: "internaldrive.fill", tone: .success)
                    }
                    VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                        Label(notice, systemImage: "exclamationmark.triangle.fill")
                            .fixedSize(horizontal: false, vertical: true)
                        StatusBadge("Recording locally", systemImage: "internaldrive.fill", tone: .success)
                    }
                }
                .font(.meetcoMetadata)
                .foregroundStyle(MeetcoTheme.warning)
                .padding(.horizontal, MeetcoTheme.Spacing.xLarge)
                .padding(.vertical, MeetcoTheme.Spacing.small)
                .background(MeetcoTheme.warning.opacity(0.09))
            }
            GeometryReader { proxy in
                if proxy.size.width >= 1_040 {
                    HSplitView {
                        transcript
                            .frame(minWidth: 560)
                        VSplitView {
                            PrivateNotesView(notes: state.privateNotes, onChange: onNotesChange)
                                .frame(minHeight: 150)
                            copilot.frame(minHeight: 300)
                        }
                        .frame(minWidth: 330, idealWidth: 370, maxWidth: 440)
                    }
                } else {
                    transcript
                        .inspector(isPresented: $showsCopilot) {
                            VSplitView {
                                PrivateNotesView(notes: state.privateNotes, onChange: onNotesChange)
                                    .frame(minHeight: 150)
                                copilot.frame(minHeight: 300)
                            }
                            .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
                        }
                }
            }
        }
        .navigationTitle(state.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Notes and copilot", systemImage: "sidebar.trailing") {
                    showsCopilot.toggle()
                }
                .accessibilityLabel(showsCopilot ? "Hide notes and copilot" : "Show notes and copilot")
            }
        }
        .background(MeetcoTheme.canvas)
    }

    private var transcript: some View {
        LiveTranscriptView(
            segments: state.transcript,
            version: state.transcriptVersion,
            scrollToSegmentID: selectedTranscriptID,
            onSelectSegment: selectTranscriptSegment
        )
    }

    private var copilot: some View {
        CopilotPanel(
            provider: state.provider,
            health: state.providerHealth,
            messages: state.chat,
            prompts: state.quickPrompts,
            isResponding: state.isCopilotResponding,
            onSend: onSendMessage,
            onOpenEvidence: selectTranscriptSegment
        )
    }

    private func selectTranscriptSegment(_ id: UUID) {
        selectedTranscriptID = id
        onSelectTranscriptSegment(id)
    }
}
