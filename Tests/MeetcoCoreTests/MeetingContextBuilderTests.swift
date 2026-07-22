import Foundation
import Testing
@testable import MeetcoCore

@Suite("Meeting context builder")
struct MeetingContextBuilderTests {
    @Test
    func selectsRelevantAndRecentSegmentsWithinBudget() {
        let meeting = Meeting(title: "Roadmap")
        let relevant = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            text: "We decided to ship the desktop beta Friday."
        )
        let unrelated = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 3_000,
            endMilliseconds: 4_000,
            text: "Coffee break."
        )
        let snapshot = MeetingContextSnapshot(meeting: meeting, transcript: [relevant, unrelated])
        let context = MeetingContextBuilder.build(
            snapshot: snapshot,
            query: "When will desktop ship?",
            characterBudget: 2_000,
            tailCount: 1,
            relevantCount: 1
        )
        #expect(context.text.count <= 2_000)
        #expect(context.text.contains("UNTRUSTED MEETING TRANSCRIPT"))
        #expect(context.text.contains(relevant.id.uuidString))
        #expect(context.includedSegmentIDs.contains(relevant.id))
    }
}
