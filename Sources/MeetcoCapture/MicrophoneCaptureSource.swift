@preconcurrency import AVFoundation
import Foundation
import MeetcoCore

public final class MicrophoneCaptureSource: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let handler: CaptureBufferHandler
    private var isRunning = false

    public init(handler: @escaping CaptureBufferHandler) {
        self.handler = handler
    }

    public func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.inputUnavailable
        }

        let handler = self.handler
        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { buffer, time in
            let seconds: Double
            if time.hostTime != 0 {
                seconds = AVAudioTime.seconds(forHostTime: time.hostTime)
            } else if time.sampleTime >= 0 {
                seconds = Double(time.sampleTime) / format.sampleRate
            } else {
                seconds = 0
            }
            guard let captured = CapturedAudioBuffer(
                source: .microphone,
                presentationTimeSeconds: seconds,
                copying: buffer
            ) else {
                handler(.failure(.bufferCopyFailed))
                return
            }
            handler(.success(captured))
        }

        do {
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    public func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}
