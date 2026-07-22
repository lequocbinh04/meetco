import Foundation
import Testing
@testable import MeetcoCapture
@testable import MeetcoCore

@Suite("Audio timeline mixing")
struct AudioTimelineMixerTests {
    @Test
    func waitsForBothOnlineSourcesAndMixesOneFrame() async {
        let mixer = AudioTimelineMixer(expectedSources: [.microphone, .system])
        let microphone = ConvertedAudioChunk(
            source: .microphone,
            startMilliseconds: 0,
            samples: Array(repeating: 10_000, count: 4_000)
        )
        let system = ConvertedAudioChunk(
            source: .system,
            startMilliseconds: 0,
            samples: Array(repeating: 2_000, count: 4_000)
        )

        #expect(await mixer.append(microphone).isEmpty)
        let frames = await mixer.append(system)
        #expect(frames.count == 1)
        #expect(frames[0].source == .mixed)
        #expect(frames[0].durationMilliseconds == 250)

        let samples = frames[0].pcmData.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Int16.self))
        }
        #expect(samples.first == 6_000)
    }

    @Test
    func boundsAStalledOnlineSourceWithAOneSecondWatermark() async {
        let mixer = AudioTimelineMixer(expectedSources: [.microphone, .system])
        var frames: [AudioFrame] = []

        for index in 0..<5 {
            frames += await mixer.append(ConvertedAudioChunk(
                source: .microphone,
                startMilliseconds: Int64(index * 250),
                samples: Array(repeating: 8_000, count: 4_000)
            ))
        }

        #expect(frames.count == 1)
        #expect(frames[0].startMilliseconds == 0)
        let samples = frames[0].pcmData.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Int16.self))
        }
        #expect(samples.first == 4_000)
    }

    @Test
    func insertsSilenceForInitialGapAndPadsOnFinish() async {
        let mixer = AudioTimelineMixer(expectedSources: [.microphone])
        let chunk = ConvertedAudioChunk(
            source: .microphone,
            startMilliseconds: 250,
            samples: Array(repeating: 4_000, count: 1_600)
        )

        let immediate = await mixer.append(chunk)
        #expect(immediate.count == 1)
        let final = await mixer.finish()
        #expect(final.count == 1)
        #expect(final[0].pcmData.count == 8_000)
    }
}
