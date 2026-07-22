import AVFoundation
import Testing
@testable import MeetcoCapture
@testable import MeetcoCore

@Suite("Audio buffer conversion")
struct AudioBufferConverterTests {
    @Test
    func converts48kStereoFloatTo16kMonoInt16() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800))
        buffer.frameLength = 4_800
        for channelIndex in 0..<2 {
            let channel = try #require(buffer.floatChannelData?[channelIndex])
            for index in 0..<4_800 {
                channel[index] = channelIndex == 0 ? 0.5 : -0.25
            }
        }
        let captured = try #require(CapturedAudioBuffer(
            source: .system,
            presentationTimeSeconds: 0,
            copying: buffer
        ))

        let converted = try AudioBufferConverter().convert(captured, startMilliseconds: 120)

        #expect(converted.startMilliseconds == 120)
        #expect(abs(converted.samples.count - 1_600) <= 2)
        #expect(converted.samples.allSatisfy { $0 <= Int16.max && $0 >= Int16.min })
    }
}
