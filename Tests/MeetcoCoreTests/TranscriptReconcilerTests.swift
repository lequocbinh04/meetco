import Foundation
import Testing
@testable import MeetcoCore

@Suite("Transcript reconciliation")
struct TranscriptReconcilerTests {
    @Test
    func retainsProvisionalAndMapsEvidenceByTimelineOverlap() {
        let meetingID = UUID()
        let provisional = TranscriptSegment(
            meetingID: meetingID,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            text: "provisional",
            version: .provisional
        )
        let final = TranscriptSegment(
            meetingID: meetingID,
            startMilliseconds: 1_500,
            endMilliseconds: 2_500,
            text: "final",
            version: .final
        )
        let result = TranscriptReconciler.reconcile(provisional: [provisional], final: [final])
        #expect(result.provisional == [provisional])
        #expect(result.final == [final])
        #expect(result.evidenceMapping[provisional.id] == [final.id])

        let remapped = TranscriptReconciler.remap(
            EvidenceReference(segmentIDs: [provisional.id]),
            using: result
        )
        #expect(remapped.segmentIDs == [final.id])
    }

    @Test
    func remapsPersistedChatAndArtifactsToFinalEvidence() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoEvidenceRemap-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try MeetingRepository(paths: .testing(root: root))
        let meeting = try await repository.createMeeting(configuration: .init())
        let provisional = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 500,
            endMilliseconds: 1_500,
            text: "provisional",
            version: .provisional
        )
        let final = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 750,
            endMilliseconds: 1_750,
            text: "final",
            version: .final
        )
        try await repository.saveChat([
            ChatMessage(
                meetingID: meeting.id,
                role: .assistant,
                content: "Grounded",
                evidenceSegmentIDs: [provisional.id]
            )
        ], id: meeting.id)
        try await repository.saveArtifacts(MeetingArtifacts(
            decisions: [EvidenceLinkedText(
                text: "Ship",
                evidence: EvidenceReference(segmentIDs: [provisional.id])
            )],
            actionItems: [ActionItem(
                title: "Launch",
                evidence: EvidenceReference(segmentIDs: [provisional.id])
            )]
        ), id: meeting.id)

        let result = try await PersistedEvidenceRemapper.remap(
            meetingID: meeting.id,
            reconciliation: TranscriptReconciler.reconcile(
                provisional: [provisional],
                final: [final]
            ),
            repository: repository
        )

        #expect(result.chat[0].evidenceSegmentIDs == [final.id])
        #expect(result.artifacts.decisions[0].evidence.segmentIDs == [final.id])
        #expect(result.artifacts.actionItems[0].evidence.segmentIDs == [final.id])
    }
}
