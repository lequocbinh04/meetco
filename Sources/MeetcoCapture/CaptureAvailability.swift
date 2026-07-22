import Foundation
import MeetcoCore

public enum CaptureAvailability: Equatable, Sendable {
    case ready
    case microphonePermissionRequired
    case microphonePermissionDenied
    case screenRecordingPermissionRequired
    case screenRecordingPermissionDenied
    case unavailable(String)
}

public struct CaptureStatus: Equatable, Sendable {
    public var microphone: CaptureAvailability
    public var systemAudio: CaptureAvailability

    public init(microphone: CaptureAvailability, systemAudio: CaptureAvailability) {
        self.microphone = microphone
        self.systemAudio = systemAudio
    }
}
