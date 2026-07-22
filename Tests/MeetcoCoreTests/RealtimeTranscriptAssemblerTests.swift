import Foundation
import Testing
@testable import MeetcoCore

@Suite("Realtime transcript assembly")
struct RealtimeTranscriptAssemblerTests {
    @Test
    func replacesPartialAndEnrichesCommitWithoutDuplication() async {
        let assembler = RealtimeTranscriptAssembler(meetingID: UUID())
        _ = await assembler.apply(.sessionStarted(id: "session-1"))
        let partial = await assembler.apply(.partial(text: "Hello wor"))
        #expect(partial.partial?.text == "Hello wor")

        let committed = await assembler.apply(.committed(text: "Hello world"))
        #expect(committed.partial == nil)
        #expect(committed.committed.count == 1)

        let enriched = await assembler.apply(.committedWithTimestamps(
            text: "Hello world",
            words: [
                .init(text: "Hello", startSeconds: 1, endSeconds: 1.4),
                .init(text: " world", startSeconds: 1.4, endSeconds: 1.8),
            ]
        ))
        #expect(enriched.committed.count == 1)
        #expect(enriched.committed[0].startMilliseconds == 1_000)
        #expect(enriched.committed[0].endMilliseconds == 1_800)
        #expect(enriched.committed[0].providerSessionID == "session-1")
    }
}
