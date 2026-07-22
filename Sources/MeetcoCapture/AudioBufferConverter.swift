import AVFoundation
import Foundation
import MeetcoCore

public final class AudioBufferConverter: @unchecked Sendable {
    private final class InputBox: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
        var supplied = false

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    public static let realtimeSampleRate = 16_000.0

    public init() {}

    public func convert(
        _ captured: CapturedAudioBuffer,
        startMilliseconds: Int64
    ) throws -> ConvertedAudioChunk {
        let input = captured.buffer
        guard input.format.sampleRate > 0,
              input.format.channelCount > 0,
              let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Self.realtimeSampleRate,
                channels: 1,
                interleaved: false
              ),
              let converter = AVAudioConverter(from: input.format, to: outputFormat) else {
            throw AudioCaptureError.invalidAudioFormat
        }

        let ratio = Self.realtimeSampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * ratio) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw AudioCaptureError.conversionFailed("Could not allocate output buffer")
        }

        let inputBox = InputBox(buffer: input)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if inputBox.supplied {
                inputStatus.pointee = .endOfStream
                return nil
            }
            inputBox.supplied = true
            inputStatus.pointee = .haveData
            return inputBox.buffer
        }

        guard status != .error, conversionError == nil,
              let channel = output.floatChannelData?.pointee else {
            throw AudioCaptureError.conversionFailed(
                conversionError?.localizedDescription ?? "Converter returned an error"
            )
        }

        let samples = UnsafeBufferPointer(start: channel, count: Int(output.frameLength)).map { sample in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16((clamped * Float(Int16.max)).rounded())
        }
        return ConvertedAudioChunk(
            source: captured.source,
            startMilliseconds: startMilliseconds,
            samples: samples
        )
    }
}
