import Foundation

public enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

public enum ChatMessageStatus: String, Codable, Sendable {
    case sending
    case complete
    case failed
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let meetingID: UUID
    public var role: ChatRole
    public var content: String
    public var createdAt: Date
    public var provider: AgentProviderKind?
    public var evidenceSegmentIDs: [UUID]
    public var status: ChatMessageStatus

    public init(
        id: UUID = UUID(),
        meetingID: UUID,
        role: ChatRole,
        content: String,
        createdAt: Date = Date(),
        provider: AgentProviderKind? = nil,
        evidenceSegmentIDs: [UUID] = [],
        status: ChatMessageStatus = .complete
    ) {
        self.id = id
        self.meetingID = meetingID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.provider = provider
        self.evidenceSegmentIDs = evidenceSegmentIDs
        self.status = status
    }
}
