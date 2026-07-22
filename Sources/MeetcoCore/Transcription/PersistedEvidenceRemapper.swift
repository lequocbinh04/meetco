import Foundation

public struct PersistedEvidenceRemappingResult: Equatable, Sendable {
    public var chat: [ChatMessage]
    public var artifacts: MeetingArtifacts

    public init(chat: [ChatMessage], artifacts: MeetingArtifacts) {
        self.chat = chat
        self.artifacts = artifacts
    }
}

public enum PersistedEvidenceRemapper {
    public static func remap(
        meetingID: UUID,
        reconciliation: TranscriptReconciliation,
        repository: MeetingRepository
    ) async throws -> PersistedEvidenceRemappingResult {
        var chat = try await repository.loadChat(id: meetingID)
        for index in chat.indices {
            chat[index].evidenceSegmentIDs = TranscriptReconciler.remap(
                EvidenceReference(segmentIDs: chat[index].evidenceSegmentIDs),
                using: reconciliation
            ).segmentIDs
        }
        try await repository.saveChat(chat, id: meetingID)

        var artifacts = try await repository.loadArtifacts(id: meetingID)
        for index in artifacts.keyPoints.indices {
            artifacts.keyPoints[index].evidence = TranscriptReconciler.remap(
                artifacts.keyPoints[index].evidence,
                using: reconciliation
            )
        }
        for index in artifacts.decisions.indices {
            artifacts.decisions[index].evidence = TranscriptReconciler.remap(
                artifacts.decisions[index].evidence,
                using: reconciliation
            )
        }
        for index in artifacts.actionItems.indices {
            artifacts.actionItems[index].evidence = TranscriptReconciler.remap(
                artifacts.actionItems[index].evidence,
                using: reconciliation
            )
        }
        for index in artifacts.openQuestions.indices {
            artifacts.openQuestions[index].evidence = TranscriptReconciler.remap(
                artifacts.openQuestions[index].evidence,
                using: reconciliation
            )
        }
        for index in artifacts.risks.indices {
            artifacts.risks[index].evidence = TranscriptReconciler.remap(
                artifacts.risks[index].evidence,
                using: reconciliation
            )
        }
        try await repository.saveArtifacts(artifacts, id: meetingID)
        return PersistedEvidenceRemappingResult(chat: chat, artifacts: artifacts)
    }
}
