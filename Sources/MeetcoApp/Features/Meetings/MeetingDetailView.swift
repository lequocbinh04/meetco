import MeetcoCore
import SwiftUI

public struct MeetingDetailView: View {
    @State private var selectedTab: MeetingDetailTab = .overview
    @State private var notesDraft: String
    @State private var focusedTranscriptSegmentID: UUID?

    public let state: MeetingDetailState
    public let onExport: (MeetingExportFormat) -> Void
    public let onDelete: () -> Void
    public let onRevealLocalFiles: () -> Void
    public let onOpenEvidence: (EvidenceReference) -> Void
    public let onToggleAction: (UUID) -> Void
    public let onRegenerateArtifacts: () -> Void
    public let onRetryFinalTranscript: () -> Void
    public let onEditTranscript: (UUID, String, String) -> Void
    public let onPlayAudio: (Int64) -> Void
    public let onNotesChange: (String) -> Void
    public let onSendMessage: (String) -> Void

    public init(
        state: MeetingDetailState,
        onExport: @escaping (MeetingExportFormat) -> Void,
        onDelete: @escaping () -> Void,
        onRevealLocalFiles: @escaping () -> Void,
        onOpenEvidence: @escaping (EvidenceReference) -> Void,
        onToggleAction: @escaping (UUID) -> Void,
        onRegenerateArtifacts: @escaping () -> Void,
        onRetryFinalTranscript: @escaping () -> Void,
        onEditTranscript: @escaping (UUID, String, String) -> Void,
        onPlayAudio: @escaping (Int64) -> Void,
        onNotesChange: @escaping (String) -> Void,
        onSendMessage: @escaping (String) -> Void
    ) {
        self.state = state
        self.onExport = onExport
        self.onDelete = onDelete
        self.onRevealLocalFiles = onRevealLocalFiles
        self.onOpenEvidence = onOpenEvidence
        self.onToggleAction = onToggleAction
        self.onRegenerateArtifacts = onRegenerateArtifacts
        self.onRetryFinalTranscript = onRetryFinalTranscript
        self.onEditTranscript = onEditTranscript
        self.onPlayAudio = onPlayAudio
        self.onNotesChange = onNotesChange
        self.onSendMessage = onSendMessage
        _notesDraft = State(initialValue: state.snapshot.manualNotes)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if state.snapshot.meeting.failureMessage != nil {
                recoveryBanner
                    .padding(.horizontal, MeetcoTheme.Spacing.xLarge)
                    .padding(.top, MeetcoTheme.Spacing.large)
                    .padding(.bottom, MeetcoTheme.Spacing.small)
            }
            header
            Divider()
            tabContent
        }
        .navigationTitle(state.snapshot.meeting.title)
        .background(MeetcoTheme.canvas)
    }

    // Export and management actions live in the header so they stay visually
    // attached to the meeting they act on instead of floating in the toolbar.
    private var headerActions: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            Menu {
                Button("Markdown", systemImage: "doc.plaintext") { onExport(.markdown) }
                Button("JSON", systemImage: "curlybraces") { onExport(.json) }
                Button("Audio", systemImage: "waveform") { onExport(.audio) }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Menu {
                if canRetryFinalTranscript {
                    Button(
                        state.isTranscriptionRetrying ? "Retrying transcript…" : "Retry final transcript",
                        systemImage: "arrow.clockwise",
                        action: onRetryFinalTranscript
                    )
                    .disabled(state.isTranscriptionRetrying)
                }
                Button("Regenerate notes", systemImage: "arrow.clockwise", action: onRegenerateArtifacts)
                Divider()
                Button("Delete meeting", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .foregroundStyle(MeetcoTheme.textSecondary)
    }

    private var recoveryBanner: some View {
        HStack(alignment: .center, spacing: MeetcoTheme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MeetcoTheme.warning)
                .frame(width: 30, height: 30)
                .background(MeetcoTheme.warning.opacity(0.15))
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.snapshot.meeting.status == .recoverable ? "Meeting needs attention" : "Completed with a warning")
                    .font(.meetcoSection)
                    .foregroundStyle(MeetcoTheme.textPrimary)
                Text(state.snapshot.meeting.failureMessage ?? "Meetco closed before finalization finished.")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: MeetcoTheme.Spacing.medium)
            if canRetryFinalTranscript {
                Button("Retry Transcript", systemImage: "arrow.clockwise", action: onRetryFinalTranscript)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isTranscriptionRetrying)
            }
            Button("Show Local Files", systemImage: "folder", action: onRevealLocalFiles)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, MeetcoTheme.Spacing.large)
        .padding(.vertical, MeetcoTheme.Spacing.medium)
        .background(MeetcoTheme.warning.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous)
                .strokeBorder(MeetcoTheme.warning.opacity(0.35))
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: MeetcoTheme.Spacing.xLarge) {
                meetingIdentity
                Spacer(minLength: MeetcoTheme.Spacing.medium)
                tabPicker.frame(maxWidth: 380)
                headerActions
            }
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                HStack(alignment: .top) {
                    meetingIdentity
                    Spacer(minLength: MeetcoTheme.Spacing.medium)
                    headerActions
                }
                tabPicker.frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, MeetcoTheme.Spacing.xLarge)
        .padding(.vertical, MeetcoTheme.Spacing.large)
        .background(MeetcoTheme.surface)
    }

    private var meetingIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.snapshot.meeting.title)
                .font(.meetcoTitle)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: MeetcoTheme.Spacing.small) {
                if state.snapshot.meeting.durationMilliseconds > 0 {
                    Text(MeetcoFormatting.duration(milliseconds: state.snapshot.meeting.durationMilliseconds))
                }
                Text(state.snapshot.meeting.createdAt, style: .date)
                if state.snapshot.meeting.hasLocalAudio {
                    Label("Audio local", systemImage: "internaldrive.fill")
                }
            }
            .font(.meetcoMetadata)
            .foregroundStyle(MeetcoTheme.textSecondary)
        }
    }

    private var tabPicker: some View {
        Picker("Meeting section", selection: $selectedTab) {
            ForEach(MeetingDetailTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder private var tabContent: some View {
        switch selectedTab {
        case .overview:
            ArtifactsOverviewView(
                artifacts: state.snapshot.artifacts,
                onOpenEvidence: openEvidence,
                onToggleAction: onToggleAction,
                onRegenerate: onRegenerateArtifacts
            )
        case .transcript:
            TranscriptDetailView(
                segments: state.snapshot.transcript,
                focusedSegmentID: focusedTranscriptSegmentID,
                hasAudio: state.snapshot.meeting.hasLocalAudio,
                onEdit: onEditTranscript,
                onPlay: onPlayAudio
            )
        case .notes:
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                Label("Private local notes", systemImage: "lock.fill").font(.meetcoSection)
                TextEditor(text: $notesDraft)
                    .font(.meetcoBody)
                    .scrollContentBackground(.hidden)
                    .padding(MeetcoTheme.Spacing.small)
                    .background(MeetcoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card))
                    .overlay { RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card).stroke(MeetcoTheme.border) }
                    .onChange(of: notesDraft) { _, notes in onNotesChange(notes) }
            }
            .padding(MeetcoTheme.Spacing.xLarge)
        case .chat:
            CopilotPanel(
                provider: state.snapshot.artifacts.provider ?? state.snapshot.meeting.configuration.agentProvider,
                health: state.providerHealth,
                messages: state.snapshot.chat,
                prompts: [],
                isResponding: state.isAgentResponding,
                onSend: onSendMessage,
                onOpenEvidence: { id in
                    openEvidence(EvidenceReference(segmentIDs: [id]))
                }
            )
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    private func openEvidence(_ evidence: EvidenceReference) {
        selectedTab = .transcript
        focusedTranscriptSegmentID = evidence.segmentIDs.first
        onOpenEvidence(evidence)
    }

    private var canRetryFinalTranscript: Bool {
        state.snapshot.meeting.hasLocalAudio
            && state.snapshot.meeting.configuration.transcriptionMode != .recordOnly
            && state.snapshot.meeting.status == .recoverable
    }
}
