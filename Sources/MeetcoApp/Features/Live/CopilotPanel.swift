import MeetcoCore
import SwiftUI

public struct CopilotPanel: View {
    @State private var draft = ""
    public let provider: AgentProviderKind
    public let health: ProviderHealth?
    public let messages: [ChatMessage]
    public let prompts: [CopilotQuickPrompt]
    public let isResponding: Bool
    public let onSend: (String) -> Void
    public let onOpenEvidence: (UUID) -> Void

    public init(
        provider: AgentProviderKind,
        health: ProviderHealth?,
        messages: [ChatMessage],
        prompts: [CopilotQuickPrompt],
        isResponding: Bool,
        onSend: @escaping (String) -> Void,
        onOpenEvidence: @escaping (UUID) -> Void
    ) {
        self.provider = provider
        self.health = health
        self.messages = messages
        self.prompts = prompts
        self.isResponding = isResponding
        self.onSend = onSend
        self.onOpenEvidence = onOpenEvidence
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            quickPrompts
            Divider()
            messageList
            composer
        }
        .background(MeetcoTheme.surface)
    }

    private var header: some View {
        HStack {
            Label("Copilot", systemImage: "sparkles")
                .font(.meetcoSection)
            Spacer()
            StatusBadge(
                MeetcoFormatting.provider(provider),
                systemImage: health?.state == .ready ? "checkmark.circle" : "exclamationmark.circle",
                tone: health?.state == .ready ? .success : .warning
            )
        }
        .padding(MeetcoTheme.Spacing.medium)
    }

    private var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MeetcoTheme.Spacing.small) {
                ForEach(prompts) { prompt in
                    Button(prompt.title) { onSend(prompt.prompt) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(provider == .none || health?.state != .ready || isResponding)
                }
            }
            .padding(MeetcoTheme.Spacing.medium)
        }
    }

    @ViewBuilder private var messageList: some View {
        if messages.isEmpty {
            EmptyStateView(
                title: provider == .none ? "No copilot selected" : "Ask about this meeting",
                message: provider == .none ? "Select a provider in the recording settings." : "Answers use the live transcript and your notes.",
                systemImage: "sparkles"
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                    ForEach(messages) { message in chatBubble(message) }
                    if isResponding {
                        HStack { ProgressView().controlSize(.small); Text("Thinking…") }
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                    }
                }
                .padding(MeetcoTheme.Spacing.medium)
            }
        }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
            Text(message.role == .user ? "You" : MeetcoFormatting.provider(message.provider ?? provider))
                .font(.meetcoMetadata)
                .foregroundStyle(MeetcoTheme.textSecondary)
            Text(message.content)
                .font(.meetcoBody)
                .textSelection(.enabled)
            if let segmentID = message.evidenceSegmentIDs.first {
                Button("Open transcript source", systemImage: "arrow.up.right") { onOpenEvidence(segmentID) }
                    .buttonStyle(.plain)
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.accent)
            }
        }
        .padding(MeetcoTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == .user ? MeetcoTheme.accentSoft : MeetcoTheme.canvas)
        .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: MeetcoTheme.Spacing.small) {
            TextField("Ask about this meeting", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .onSubmit(sendDraft)
            Button("Send", systemImage: "arrow.up.circle.fill", action: sendDraft)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.system(size: 22))
                .foregroundStyle(MeetcoTheme.accent)
                .frame(width: 44, height: 44)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(
                    draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || provider == .none
                        || health?.state != .ready
                        || isResponding
                )
                .accessibilityLabel("Send message")
        }
        .padding(MeetcoTheme.Spacing.medium)
        .overlay(alignment: .top) { Divider() }
    }

    private func sendDraft() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        onSend(message)
        draft = ""
    }
}
