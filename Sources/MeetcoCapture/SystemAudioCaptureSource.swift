@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import CoreMedia
import Foundation
import MeetcoCore

public final class SystemAudioCaptureSource: NSObject, @unchecked Sendable {
    private let handler: CaptureBufferHandler
    private let sampleQueue = DispatchQueue(label: "com.meetco.capture.system-audio", qos: .userInitiated)
    private let stateLock = NSLock()
    private var stream: SCStream?
    private var stopping = false

    public init(handler: @escaping CaptureBufferHandler) {
        self.handler = handler
    }

    public func start() async throws {
        guard CGPreflightScreenCaptureAccess() else {
            throw AudioCaptureError.screenRecordingPermissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw AudioCaptureError.systemAudioUnavailable(error.localizedDescription)
        }
        guard let display = content.displays.first else {
            throw AudioCaptureError.systemAudioUnavailable("No display is available")
        }

        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let excludedApplications = content.applications.filter {
            $0.bundleIdentifier == ownBundleIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.width = 2
        configuration.height = 2
        configuration.showsCursor = false

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
            try await stream.startCapture()
            stateLock.withLock { stopping = false }
            self.stream = stream
        } catch {
            throw AudioCaptureError.systemAudioUnavailable(error.localizedDescription)
        }
    }

    public func stop() async {
        stateLock.withLock { stopping = true }
        guard let stream else { return }
        try? await stream.stopCapture()
        try? stream.removeStreamOutput(self, type: .audio)
        self.stream = nil
    }

    private func copyAudioBuffer(from sampleBuffer: CMSampleBuffer) -> CapturedAudioBuffer? {
        guard sampleBuffer.isValid,
              CMSampleBufferDataIsReady(sampleBuffer),
              let description = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: buffer.mutableAudioBufferList
        )
        guard status == noErr else { return nil }
        let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        return CapturedAudioBuffer(
            source: .system,
            presentationTimeSeconds: seconds.isFinite ? seconds : 0,
            copying: buffer
        )
    }
}

extension SystemAudioCaptureSource: SCStreamOutput {
    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio else { return }
        guard let captured = copyAudioBuffer(from: sampleBuffer) else {
            handler(.failure(.bufferCopyFailed))
            return
        }
        handler(.success(captured))
    }
}

extension SystemAudioCaptureSource: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        let wasStopping = stateLock.withLock { stopping }
        if !wasStopping {
            handler(.failure(.systemAudioUnavailable(error.localizedDescription)))
        }
    }
}
