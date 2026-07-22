import Foundation

public struct MeetingContextSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var meeting: Meeting
    public var transcript: [TranscriptSegment]
    public var artifacts: MeetingArtifacts
    public var chat: [ChatMessage]
    public var manualNotes: String
    public var updatedAt: Date
    public var mcpEnabled: Bool

    public init(
        meeting: Meeting,
        transcript: [TranscriptSegment] = [],
        artifacts: MeetingArtifacts = .init(),
        chat: [ChatMessage] = [],
        manualNotes: String = "",
        updatedAt: Date = Date(),
        mcpEnabled: Bool? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.meeting = meeting
        self.transcript = transcript
        self.artifacts = artifacts
        self.chat = chat
        self.manualNotes = manualNotes
        self.updatedAt = updatedAt
        self.mcpEnabled = mcpEnabled ?? meeting.configuration.mcpEnabled
    }
}
