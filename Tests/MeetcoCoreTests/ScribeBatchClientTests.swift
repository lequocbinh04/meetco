import Foundation
import Testing
@testable import MeetcoCore

@Suite("Scribe batch transcription")
struct ScribeBatchClientTests {
    @Test
    func buildsFileBackedMultipartAndGroupsSpeakerSegments() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoBatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audioURL = root.appendingPathComponent("final.wav")
        try Data("RIFFverification".utf8).write(to: audioURL)

        let upload = try ScribeBatchClient.makeUpload(
            audioURL: audioURL,
            apiKey: "verification-key",
            languageCode: "vi",
            keyterms: ["Meetco", "Q4 forecast"],
            numberOfSpeakers: 2,
            temporaryDirectory: root
        )
        let body = try String(decoding: Data(contentsOf: upload.body.url), as: UTF8.self)
        #expect(body.contains("name=\"model_id\"\r\n\r\nscribe_v2"))
        #expect(body.contains("name=\"diarize\"\r\n\r\ntrue"))
        #expect(body.contains("name=\"keyterms\"\r\n\r\nMeetco"))
        #expect(body.contains("name=\"keyterms\"\r\n\r\nQ4 forecast"))
        #expect(body.contains("RIFFverification"))

        let response = ScribeBatchResponse(
            languageCode: "vi",
            languageProbability: 0.98,
            text: "Xin chào. Quyết định xong.",
            words: [
                .init(text: "Xin", start: 0, end: 0.2, speakerID: "speaker_0"),
                .init(text: "chào", start: 0.2, end: 0.5, speakerID: "speaker_0"),
                .init(text: ".", start: 0.5, end: 0.55, speakerID: "speaker_0"),
                .init(text: "Quyết định", start: 1, end: 1.4, speakerID: "speaker_1"),
                .init(text: "xong", start: 1.4, end: 1.8, speakerID: "speaker_1"),
                .init(text: ".", start: 1.8, end: 1.9, speakerID: "speaker_1"),
            ]
        )
        let segments = ScribeBatchClient.segments(from: response, meetingID: UUID())
        #expect(segments.map(\.text) == ["Xin chào.", "Quyết định xong."])
        #expect(segments.map(\.speakerID) == ["speaker_0", "speaker_1"])
        #expect(segments.allSatisfy { $0.version == .final })
    }
}
