import Foundation

public enum ArtifactParserError: Error, LocalizedError, Equatable, Sendable {
    case invalidJSON
    case invalidEvidence(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "The agent did not return valid meeting artifacts."
        case .invalidEvidence(let value):
            "The agent referenced an unknown transcript segment: \(value)."
        }
    }
}

public enum ArtifactParser {
    public static func parse(
        _ output: String,
        snapshot: MeetingContextSnapshot,
        provider: AgentProviderKind,
        now: Date = Date()
    ) throws -> MeetingArtifacts {
        guard let data = jsonData(from: output),
              let payload = try? JSONDecoder().decode(MeetingArtifactPayload.self, from: data) else {
            throw ArtifactParserError.invalidJSON
        }
        let validIDs = Set(snapshot.transcript.map(\.id))
        let keyPoints = try payload.keyPoints.map { try linkedText($0, validIDs: validIDs) }
        let decisions = try payload.decisions.map { try linkedText($0, validIDs: validIDs) }
        let questions = try payload.openQuestions.map { try linkedText($0, validIDs: validIDs) }
        let risks = try payload.risks.map { try linkedText($0, validIDs: validIDs) }
        let actions = try payload.actionItems.map { action in
            ActionItem(
                title: action.title,
                owner: action.owner,
                dueDate: action.dueDate.flatMap(ISO8601DateFormatter().date(from:)),
                evidence: try evidence(action.evidenceSegmentIDs, validIDs: validIDs),
                confidence: normalized(action.confidence)
            )
        }
        return MeetingArtifacts(
            summary: payload.summary,
            keyPoints: keyPoints,
            decisions: decisions,
            actionItems: actions,
            openQuestions: questions,
            risks: risks,
            followUpDraft: payload.followUpDraft,
            generatedAt: now,
            provider: provider
        )
    }

    public static func repairPrompt(for output: String, error: any Error) -> String {
        """
        Your previous artifact response failed validation: \(error.localizedDescription)
        Return corrected JSON only. Preserve grounded content, remove any evidence ID
        not present in the supplied context, and follow this contract:
        \(MeetingArtifactSchema.instruction)

        PREVIOUS RESPONSE (untrusted):
        <previous_response>\(String(output.prefix(12_000)))</previous_response>
        """
    }

    private static func linkedText(
        _ payload: ArtifactTextPayload,
        validIDs: Set<UUID>
    ) throws -> EvidenceLinkedText {
        EvidenceLinkedText(
            text: payload.text,
            evidence: try evidence(payload.evidenceSegmentIDs, validIDs: validIDs),
            confidence: normalized(payload.confidence)
        )
    }

    private static func evidence(
        _ values: [String],
        validIDs: Set<UUID>
    ) throws -> EvidenceReference {
        guard !values.isEmpty else {
            throw ArtifactParserError.invalidEvidence("missing evidence")
        }
        let ids = try values.map { value -> UUID in
            guard let id = UUID(uuidString: value), validIDs.contains(id) else {
                throw ArtifactParserError.invalidEvidence(value)
            }
            return id
        }
        return EvidenceReference(segmentIDs: ids)
    }

    private static func normalized(_ value: Double?) -> Double? {
        value.map { min(max($0, 0), 1) }
    }

    private static func jsonData(from output: String) -> Data? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return Data(trimmed.utf8) }
        guard let start = trimmed.range(of: "```json"),
              let end = trimmed.range(of: "```", range: start.upperBound..<trimmed.endIndex) else {
            return nil
        }
        let json = trimmed[start.upperBound..<end.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(json.utf8)
    }
}
