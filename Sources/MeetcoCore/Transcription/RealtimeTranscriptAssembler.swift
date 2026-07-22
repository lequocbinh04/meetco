import Foundation

public struct RealtimeTranscriptSnapshot: Equatable, Sendable {
    public var committed: [TranscriptSegment]
    public var partial: TranscriptSegment?

    public init(committed: [TranscriptSegment], partial: TranscriptSegment?) {
        self.committed = committed
        self.partial = partial
    }
}

public actor RealtimeTranscriptAssembler {
    private let meetingID: UUID
    private var sessionID: String?
    private var committed: [TranscriptSegment] = []
    private var partial: TranscriptSegment?

    public init(meetingID: UUID) {
        self.meetingID = meetingID
    }

    public func apply(_ event: ScribeRealtimeEvent) -> RealtimeTranscriptSnapshot {
        switch event {
        case .sessionStarted(let id):
            sessionID = id
        case .partial(let text):
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            partial = normalized.isEmpty ? nil : TranscriptSegment(
                meetingID: meetingID,
                startMilliseconds: committed.last?.endMilliseconds ?? 0,
                endMilliseconds: committed.last?.endMilliseconds ?? 0,
                text: normalized,
                version: .provisional,
                isCommitted: false,
                provider: "elevenlabs",
                providerSessionID: sessionID
            )
        case .committed(let text):
            appendCommitted(text: text, words: [])
        case .committedWithTimestamps(let text, let realtimeWords):
            let words = realtimeWords.map {
                TranscriptWord(
                    text: $0.text,
                    startMilliseconds: milliseconds($0.startSeconds),
                    endMilliseconds: milliseconds($0.endSeconds)
                )
            }
            enrichOrAppend(text: text, words: words)
        case .error, .unknown:
            break
        }
        return RealtimeTranscriptSnapshot(committed: committed, partial: partial)
    }

    private func appendCommitted(text: String, words: [TranscriptWord]) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if committed.last?.text == normalized {
            partial = nil
            return
        }
        let start = words.first?.startMilliseconds ?? committed.last?.endMilliseconds ?? 0
        let end = words.last?.endMilliseconds ?? start
        committed.append(TranscriptSegment(
            meetingID: meetingID,
            startMilliseconds: start,
            endMilliseconds: end,
            text: normalized,
            version: .provisional,
            isCommitted: true,
            words: words,
            provider: "elevenlabs",
            providerSessionID: sessionID
        ))
        partial = nil
    }

    private func enrichOrAppend(text: String, words: [TranscriptWord]) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = committed.indices.last, committed[index].text == normalized {
            committed[index].words = words
            committed[index].startMilliseconds = words.first?.startMilliseconds ?? committed[index].startMilliseconds
            committed[index].endMilliseconds = words.last?.endMilliseconds ?? committed[index].endMilliseconds
            partial = nil
        } else {
            appendCommitted(text: normalized, words: words)
        }
    }

    private func milliseconds(_ seconds: Double) -> Int64 {
        Int64((seconds * 1_000).rounded())
    }
}
