import Foundation
import MeetcoCore

public actor AudioCaptureCoordinator {
    private let permissionService: CapturePermissionService
    private let converter = AudioBufferConverter()
    private var state: AudioCaptureState = .idle
    private var microphone: MicrophoneCaptureSource?
    private var systemAudio: SystemAudioCaptureSource?
    private var archiveWriter: AudioArchiveWriter?
    private var mixWriter: PCM16WAVWriter?
    private var mixer: AudioTimelineMixer?
    private var sourceSampleCounts: [AudioSource: Int64] = [:]
    private var captureEpochSeconds = 0.0
    private var accumulatedPauseSeconds = 0.0
    private var pauseStartedSeconds: Double?
    private var seenSources: Set<AudioSource> = []
    private var continuations: [UUID: AsyncStream<AudioCaptureEvent>.Continuation] = [:]

    public init(permissionService: CapturePermissionService = .init()) {
        self.permissionService = permissionService
    }

    public nonisolated func events() -> AsyncStream<AudioCaptureEvent> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id) }
            }
            Task { await self.addContinuation(continuation, id: id) }
        }
    }

    public func start(
        meetingID: UUID,
        mode: CaptureMode,
        audioDirectory: URL,
        microphoneDeviceUID: String? = nil
    ) async throws {
        if case .failed = state {
            await discardFailedResources()
        }
        guard state == .idle || state == .finished else {
            throw AudioCaptureError.archiveFailed("A recording is already active")
        }
        transition(to: .starting)

        guard await permissionService.requestMicrophoneAccess() else {
            transition(to: .failed(AudioCaptureError.microphonePermissionDenied.localizedDescription))
            throw AudioCaptureError.microphonePermissionDenied
        }
        if mode == .online,
           permissionService.systemAudioAvailability() != .ready,
           !permissionService.requestScreenRecordingAccess() {
            transition(to: .failed(AudioCaptureError.screenRecordingPermissionDenied.localizedDescription))
            throw AudioCaptureError.screenRecordingPermissionDenied
        }

        let archive: AudioArchiveWriter
        let mix: PCM16WAVWriter
        do {
            archive = try AudioArchiveWriter(meetingID: meetingID, directory: audioDirectory)
            mix = try PCM16WAVWriter(url: audioDirectory.appendingPathComponent("final-mix.wav"))
        } catch {
            transition(to: .failed(error.localizedDescription))
            throw error
        }
        let expectedSources: Set<AudioSource> = mode == .online ? [.system, .microphone] : [.microphone]
        let mixer = AudioTimelineMixer(expectedSources: expectedSources)
        let handler: CaptureBufferHandler = { result in
            Task { await self.ingest(result) }
        }
        let microphone = MicrophoneCaptureSource(handler: handler, deviceUID: microphoneDeviceUID)
        let systemAudio = mode == .online ? SystemAudioCaptureSource(handler: handler) : nil

        self.archiveWriter = archive
        self.mixWriter = mix
        self.mixer = mixer
        self.microphone = microphone
        self.systemAudio = systemAudio
        self.sourceSampleCounts = [:]
        self.captureEpochSeconds = ProcessInfo.processInfo.systemUptime
        self.accumulatedPauseSeconds = 0
        self.pauseStartedSeconds = nil
        self.seenSources = []

        do {
            try await systemAudio?.start()
            try microphone.start()
            transition(to: .recording)
        } catch {
            microphone.stop()
            await systemAudio?.stop()
            transition(to: .failed(error.localizedDescription))
            throw error
        }
    }

    public func pause() {
        guard state == .recording else { return }
        pauseStartedSeconds = ProcessInfo.processInfo.systemUptime
        transition(to: .paused)
    }

    public func resume() {
        guard state == .paused else { return }
        if let pauseStartedSeconds {
            accumulatedPauseSeconds += ProcessInfo.processInfo.systemUptime - pauseStartedSeconds
        }
        pauseStartedSeconds = nil
        transition(to: .recording)
    }

    public func stop() async throws -> AudioCaptureResult {
        let canStop: Bool
        switch state {
        case .recording, .paused, .failed:
            canStop = true
        default:
            canStop = false
        }
        guard canStop, let mixer,
              let mixWriter,
              let archiveWriter else {
            throw AudioCaptureError.archiveFailed("No recording is active")
        }
        transition(to: .stopping)
        microphone?.stop()
        await systemAudio?.stop()
        do {
            let finalFrames = await mixer.finish()
            for frame in finalFrames {
                try await mixWriter.append(frame)
            }
            let mixURL = try await mixWriter.finish()
            let manifestURL = try await archiveWriter.finish()
            let duration = sourceSampleCounts.values.max().map {
                Int64(Double($0) / 16_000 * 1_000)
            } ?? 0
            let result = AudioCaptureResult(
                manifestURL: manifestURL,
                mixURL: mixURL,
                durationMilliseconds: duration,
                trailingRealtimeFrames: finalFrames
            )
            clearRuntimeReferences()
            transition(to: .finished)
            return result
        } catch {
            clearRuntimeReferences()
            transition(to: .failed(error.localizedDescription))
            throw error
        }
    }

    private func ingest(_ result: Result<CapturedAudioBuffer, AudioCaptureError>) async {
        guard state == .recording else { return }
        let captured: CapturedAudioBuffer
        switch result {
        case .success(let value):
            captured = value
        case .failure(let error):
            if error.isFatalDuringActiveCapture {
                await failActiveCapture(error)
            } else {
                broadcast(.warning("Dropped one audio buffer: \(error.localizedDescription)"))
            }
            return
        }

        let sequentialStart = sourceSampleCounts[captured.source, default: 0]
        let startMilliseconds = timelineStartMilliseconds(
            presentationTimeSeconds: captured.presentationTimeSeconds,
            sequentialStartSample: sequentialStart
        )
        let requestedStartSample = Int64(Double(startMilliseconds) / 1_000 * 16_000)
        if seenSources.contains(captured.source),
           abs(requestedStartSample - sequentialStart) > 4_000 {
            broadcast(.discontinuity(source: captured.source, atMilliseconds: startMilliseconds))
        }
        seenSources.insert(captured.source)

        do {
            try await archiveWriter?.append(captured, atMilliseconds: startMilliseconds)
        } catch {
            await failActiveCapture(.archiveFailed(error.localizedDescription))
            return
        }

        let converted: ConvertedAudioChunk
        do {
            converted = try converter.convert(captured, startMilliseconds: startMilliseconds)
        } catch {
            broadcast(.warning("Dropped one audio buffer: \(error.localizedDescription)"))
            return
        }

        sourceSampleCounts[captured.source] = max(
            sequentialStart,
            requestedStartSample + Int64(converted.samples.count)
        )
        broadcast(.level(AudioLevelMeter.measure(source: captured.source, samples: converted.samples)))

        guard let frames = await mixer?.append(converted) else { return }
        do {
            for frame in frames {
                try await mixWriter?.append(frame)
                broadcast(.realtimeFrame(frame))
            }
        } catch {
            await failActiveCapture(.archiveFailed("Final mix write failed: \(error.localizedDescription)"))
        }
    }

    private func failActiveCapture(_ error: AudioCaptureError) async {
        guard state == .recording || state == .paused else { return }
        transition(to: .failed(error.localizedDescription))
        microphone?.stop()
        await systemAudio?.stop()
    }

    private func transition(to newState: AudioCaptureState) {
        state = newState
        broadcast(.state(newState))
    }

    private func broadcast(_ event: AudioCaptureEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func addContinuation(
        _ continuation: AsyncStream<AudioCaptureEvent>.Continuation,
        id: UUID
    ) {
        continuations[id] = continuation
        continuation.yield(.state(state))
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func timelineStartMilliseconds(
        presentationTimeSeconds: Double,
        sequentialStartSample: Int64
    ) -> Int64 {
        let fallback = Int64(Double(sequentialStartSample) / 16_000 * 1_000)
        guard presentationTimeSeconds.isFinite, presentationTimeSeconds > 0 else { return fallback }
        let relative = presentationTimeSeconds - captureEpochSeconds - accumulatedPauseSeconds
        guard relative >= -0.25, relative < 86_400 else { return fallback }
        return max(0, Int64((relative * 1_000).rounded()))
    }

    private func discardFailedResources() async {
        microphone?.stop()
        await systemAudio?.stop()
        _ = try? await mixWriter?.finish()
        _ = try? await archiveWriter?.finish()
        clearRuntimeReferences()
        state = .idle
    }

    private func clearRuntimeReferences() {
        microphone = nil
        systemAudio = nil
        archiveWriter = nil
        mixWriter = nil
        mixer = nil
        sourceSampleCounts = [:]
        seenSources = []
    }
}
