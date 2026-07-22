import Foundation
import MeetcoCore

public struct CopilotQuickPrompt: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let prompt: String

    public init(id: String, title: String, prompt: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
    }
}

public struct LiveMeetingState: Equatable, Sendable {
    public let meetingID: UUID
    public let title: String
    public let controls: RecordingControlState
    public let transcript: [TranscriptSegment]
    public let transcriptVersion: TranscriptVersion
    public let transcriptNotice: String?
    public let privateNotes: String
    public let chat: [ChatMessage]
    public let provider: AgentProviderKind
    public let providerHealth: ProviderHealth?
    public let quickPrompts: [CopilotQuickPrompt]
    public let isCopilotResponding: Bool

    public init(
        meetingID: UUID,
        title: String,
        controls: RecordingControlState,
        transcript: [TranscriptSegment],
        transcriptVersion: TranscriptVersion,
        transcriptNotice: String?,
        privateNotes: String,
        chat: [ChatMessage],
        provider: AgentProviderKind,
        providerHealth: ProviderHealth?,
        quickPrompts: [CopilotQuickPrompt],
        isCopilotResponding: Bool
    ) {
        self.meetingID = meetingID
        self.title = title
        self.controls = controls
        self.transcript = transcript
        self.transcriptVersion = transcriptVersion
        self.transcriptNotice = transcriptNotice
        self.privateNotes = privateNotes
        self.chat = chat
        self.provider = provider
        self.providerHealth = providerHealth
        self.quickPrompts = quickPrompts
        self.isCopilotResponding = isCopilotResponding
    }
}
