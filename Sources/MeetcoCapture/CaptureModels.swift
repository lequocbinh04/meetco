import AVFoundation
import Foundation
import MeetcoCore

public enum AudioCaptureState: Equatable, Sendable {
    case idle
    case starting
    case recording
    case paused
    case stopping
    case finished
    case failed(String)
}

public enum AudioCaptureError: Error, LocalizedError, Sendable {
    case microphonePermissionDenied
    case screenRecordingPermissionDenied
    case inputUnavailable
    case invalidAudioFormat
    case bufferCopyFailed
    case conversionFailed(String)
    case systemAudioUnavailable(String)
    case archiveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            "Microphone access is required for this recording mode."
        case .screenRecordingPermissionDenied:
            "Screen Recording access is required to capture system audio."
        case .inputUnavailable:
            "The selected microphone is unavailable."
        case .invalidAudioFormat:
            "The audio device returned an unsupported format."
        case .bufferCopyFailed:
            "Meetco could not safely copy an audio buffer."
        case let .conversionFailed(detail):
            "Audio conversion failed: \(detail)"
        case let .systemAudioUnavailable(detail):
            "System audio is unavailable: \(detail)"
        case let .archiveFailed(detail):
            "Local audio archive failed: \(detail)"
        }
    }

    var isFatalDuringActiveCapture: Bool {
        switch self {
        case .systemAudioUnavailable, .archiveFailed, .inputUnavailable:
            true
        case .microphonePermissionDenied, .screenRecordingPermissionDenied,
             .invalidAudioFormat, .bufferCopyFailed, .conversionFailed:
            false
        }
    }
}

public final class CapturedAudioBuffer: @unchecked Sendable {
    public let source: AudioSource
    public let presentationTimeSeconds: Double
    public let buffer: AVAudioPCMBuffer

    public init?(source: AudioSource, presentationTimeSeconds: Double, copying buffer: AVAudioPCMBuffer) {
        guard let copied = buffer.meetcoDeepCopy() else { return nil }
        self.source = source
        self.presentationTimeSeconds = presentationTimeSeconds
        self.buffer = copied
    }
}

public struct ConvertedAudioChunk: Equatable, Sendable {
    public var source: AudioSource
    public var startMilliseconds: Int64
    public var samples: [Int16]

    public init(source: AudioSource, startMilliseconds: Int64, samples: [Int16]) {
        self.source = source
        self.startMilliseconds = startMilliseconds
        self.samples = samples
    }

    public var durationMilliseconds: Int64 {
        Int64((Double(samples.count) / 16_000 * 1_000).rounded())
    }
}

public enum AudioCaptureEvent: Sendable {
    case state(AudioCaptureState)
    case level(AudioLevel)
    case realtimeFrame(AudioFrame)
    case discontinuity(source: AudioSource, atMilliseconds: Int64)
    case warning(String)
}

public struct AudioCaptureResult: Equatable, Sendable {
    public var manifestURL: URL
    public var mixURL: URL
    public var durationMilliseconds: Int64
    public var trailingRealtimeFrames: [AudioFrame]

    public init(
        manifestURL: URL,
        mixURL: URL,
        durationMilliseconds: Int64,
        trailingRealtimeFrames: [AudioFrame] = []
    ) {
        self.manifestURL = manifestURL
        self.mixURL = mixURL
        self.durationMilliseconds = durationMilliseconds
        self.trailingRealtimeFrames = trailingRealtimeFrames
    }
}

public typealias CaptureBufferHandler = @Sendable (Result<CapturedAudioBuffer, AudioCaptureError>) -> Void

extension AVAudioPCMBuffer {
    fileprivate func meetcoDeepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return nil
        }
        copy.frameLength = frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else { return nil }

        for index in sourceBuffers.indices {
            let source = sourceBuffers[index]
            let byteCount = Int(source.mDataByteSize)
            guard let sourceData = source.mData,
                  let destinationData = destinationBuffers[index].mData else { continue }
            memcpy(destinationData, sourceData, byteCount)
            destinationBuffers[index].mDataByteSize = source.mDataByteSize
        }
        return copy
    }
}
