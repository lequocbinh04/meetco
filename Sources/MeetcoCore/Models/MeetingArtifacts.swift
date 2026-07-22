import Foundation

public struct EvidenceLinkedText: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var evidence: EvidenceReference
    public var confidence: Double?

    public init(
        id: UUID = UUID(),
        text: String,
        evidence: EvidenceReference = .init(),
        confidence: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.evidence = evidence
        self.confidence = confidence
    }
}

public enum ActionItemStatus: String, Codable, CaseIterable, Sendable {
    case proposed
    case accepted
    case completed
    case dismissed
}

public struct ActionItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var owner: String?
    public var dueDate: Date?
    public var status: ActionItemStatus
    public var evidence: EvidenceReference
    public var confidence: Double?

    public init(
        id: UUID = UUID(),
        title: String,
        owner: String? = nil,
        dueDate: Date? = nil,
        status: ActionItemStatus = .proposed,
        evidence: EvidenceReference = .init(),
        confidence: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.owner = owner
        self.dueDate = dueDate
        self.status = status
        self.evidence = evidence
        self.confidence = confidence
    }
}

public struct MeetingArtifacts: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var summary: String
    public var keyPoints: [EvidenceLinkedText]
    public var decisions: [EvidenceLinkedText]
    public var actionItems: [ActionItem]
    public var openQuestions: [EvidenceLinkedText]
    public var risks: [EvidenceLinkedText]
    public var followUpDraft: String?
    public var generatedAt: Date?
    public var provider: AgentProviderKind?

    public init(
        summary: String = "",
        keyPoints: [EvidenceLinkedText] = [],
        decisions: [EvidenceLinkedText] = [],
        actionItems: [ActionItem] = [],
        openQuestions: [EvidenceLinkedText] = [],
        risks: [EvidenceLinkedText] = [],
        followUpDraft: String? = nil,
        generatedAt: Date? = nil,
        provider: AgentProviderKind? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.summary = summary
        self.keyPoints = keyPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.risks = risks
        self.followUpDraft = followUpDraft
        self.generatedAt = generatedAt
        self.provider = provider
    }
}
