import Foundation
import Testing
@testable import MeetcoCore

@Suite("Artifact validation")
struct ArtifactParserTests {
    @Test
    func acceptsExistingEvidenceAndRejectsInventedIDs() throws {
        let meeting = Meeting(title: "Artifact check")
        let segment = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 0,
            endMilliseconds: 1_000,
            text: "Cris owns the launch checklist."
        )
        let snapshot = MeetingContextSnapshot(meeting: meeting, transcript: [segment])
        let valid = artifactJSON(evidenceID: segment.id.uuidString)
        let parsed = try ArtifactParser.parse(
            valid,
            snapshot: snapshot,
            provider: .claudeAPI,
            now: Date(timeIntervalSince1970: 10)
        )
        #expect(parsed.actionItems[0].evidence.segmentIDs == [segment.id])

        #expect(throws: ArtifactParserError.self) {
            try ArtifactParser.parse(
                artifactJSON(evidenceID: UUID().uuidString),
                snapshot: snapshot,
                provider: .claudeAPI
            )
        }
    }

    private func artifactJSON(evidenceID: String) -> String {
        """
        {"summary":"Launch prep","keyPoints":[],"decisions":[],"actionItems":[{"title":"Own checklist","owner":"Cris","dueDate":null,"evidenceSegmentIDs":["\(evidenceID)"],"confidence":0.9}],"openQuestions":[],"risks":[],"followUpDraft":null}
        """
    }
}
