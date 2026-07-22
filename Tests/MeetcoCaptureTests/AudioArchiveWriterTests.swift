import AVFoundation
import Foundation
import Testing
@testable import MeetcoCapture
@testable import MeetcoCore

@Suite("Audio archive")
struct AudioArchiveWriterTests {
    @Test
    func writesManifestCAFTrackAndValidWAVHeader() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoArchive-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let meetingID = UUID()
        let writer = try AudioArchiveWriter(meetingID: meetingID, directory: root)
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        buffer.frameLength = 480
        let captured = try #require(CapturedAudioBuffer(
            source: .microphone,
            presentationTimeSeconds: 0,
            copying: buffer
        ))
        try await writer.append(captured, atMilliseconds: 0)
        let manifestURL = try await writer.finish(now: Date(timeIntervalSince1970: 50))
        let manifest = try AtomicFileWriter.read(AudioArchiveManifest.self, from: manifestURL)

        #expect(manifest.meetingID == meetingID)
        #expect(manifest.tracks.count == 1)
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(manifest.tracks[0].fileName).path
        ))

        let wavURL = root.appendingPathComponent("mix.wav")
        let wav = try PCM16WAVWriter(url: wavURL)
        let frame = AudioFrame(
            source: .mixed,
            startMilliseconds: 0,
            sampleCount: 4_000,
            pcmData: Data(count: 8_000)
        )
        try await wav.append(frame)
        _ = try await wav.finish()
        let header = try Data(contentsOf: wavURL).prefix(12)
        #expect(String(decoding: header.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: header.suffix(4), as: UTF8.self) == "WAVE")
    }
}
