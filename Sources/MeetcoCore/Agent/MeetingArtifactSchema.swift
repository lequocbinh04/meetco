import Foundation

public struct ArtifactTextPayload: Codable, Equatable, Sendable {
    public var text: String
    public var evidenceSegmentIDs: [String]
    public var confidence: Double?

    public init(text: String, evidenceSegmentIDs: [String] = [], confidence: Double? = nil) {
        self.text = text
        self.evidenceSegmentIDs = evidenceSegmentIDs
        self.confidence = confidence
    }
}

public struct ArtifactActionPayload: Codable, Equatable, Sendable {
    public var title: String
    public var owner: String?
    public var dueDate: String?
    public var evidenceSegmentIDs: [String]
    public var confidence: Double?

    public init(
        title: String,
        owner: String? = nil,
        dueDate: String? = nil,
        evidenceSegmentIDs: [String] = [],
        confidence: Double? = nil
    ) {
        self.title = title
        self.owner = owner
        self.dueDate = dueDate
        self.evidenceSegmentIDs = evidenceSegmentIDs
        self.confidence = confidence
    }
}

public struct MeetingArtifactPayload: Codable, Equatable, Sendable {
    public var summary: String
    public var keyPoints: [ArtifactTextPayload]
    public var decisions: [ArtifactTextPayload]
    public var actionItems: [ArtifactActionPayload]
    public var openQuestions: [ArtifactTextPayload]
    public var risks: [ArtifactTextPayload]
    public var followUpDraft: String?

    public init(
        summary: String,
        keyPoints: [ArtifactTextPayload] = [],
        decisions: [ArtifactTextPayload] = [],
        actionItems: [ArtifactActionPayload] = [],
        openQuestions: [ArtifactTextPayload] = [],
        risks: [ArtifactTextPayload] = [],
        followUpDraft: String? = nil
    ) {
        self.summary = summary
        self.keyPoints = keyPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.risks = risks
        self.followUpDraft = followUpDraft
    }
}

public enum MeetingArtifactSchema {
    public static let instruction = """
    Return one JSON object only with: summary (string), keyPoints, decisions,
    actionItems, openQuestions, risks (arrays), and followUpDraft (string or null).
    Text items require text, evidenceSegmentIDs, confidence. Actions require title,
    owner, dueDate (ISO-8601 or null), evidenceSegmentIDs, confidence. Every evidence
    ID must be copied exactly from a provided transcript segment_id. Never invent IDs.
    """

    public static var jsonSchema: [String: Any] { [
        "type": "object",
        "additionalProperties": false,
        "required": ["summary", "keyPoints", "decisions", "actionItems", "openQuestions", "risks", "followUpDraft"],
        "properties": [
            "summary": ["type": "string"],
            "keyPoints": textArray,
            "decisions": textArray,
            "openQuestions": textArray,
            "risks": textArray,
            "actionItems": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["title", "owner", "dueDate", "evidenceSegmentIDs", "confidence"],
                    "properties": [
                        "title": ["type": "string"],
                        "owner": ["type": ["string", "null"]],
                        "dueDate": ["type": ["string", "null"]],
                        "evidenceSegmentIDs": ["type": "array", "items": ["type": "string"]],
                        "confidence": ["type": ["number", "null"]],
                    ],
                ],
            ],
            "followUpDraft": ["type": ["string", "null"]],
        ],
    ] }

    private static var textArray: [String: Any] { [
        "type": "array",
        "items": [
            "type": "object",
            "additionalProperties": false,
            "required": ["text", "evidenceSegmentIDs", "confidence"],
            "properties": [
                "text": ["type": "string"],
                "evidenceSegmentIDs": ["type": "array", "items": ["type": "string"]],
                "confidence": ["type": ["number", "null"]],
            ],
        ],
    ] }
}
