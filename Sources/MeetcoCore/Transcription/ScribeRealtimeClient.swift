import Foundation

public actor ScribeRealtimeClient: TranscriptionService {
    private struct PendingFrame: Sendable {
        let sequence: Int64
        let frame: AudioFrame
    }

    private struct ExplicitCommitRequest: Sendable {
        let id: Int
        let frameBoundary: Int64?
        let connectionGeneration: Int
    }

    private struct InputChunk: Encodable {
        let messageType = "input_audio_chunk"
        let audioBase64: String
        let sampleRate = 16_000
        let commit: Bool
        let previousText: String?

        enum CodingKeys: String, CodingKey {
            case messageType = "message_type"
            case audioBase64 = "audio_base_64"
            case sampleRate = "sample_rate"
            case commit
            case previousText = "previous_text"
        }
    }

    public static let maximumQueuedFrames = 120
    public static let periodicCommitMilliseconds: Int64 = 20_000
    public static let transportSendTimeout: Duration = .seconds(5)
    private let transport: any ScribeRealtimeTransport
    private var configuration = ScribeRealtimeConfiguration()
    private var apiKey: String?
    private var state: RealtimeTranscriptionState = .idle
    private var isActive = false
    private var isConnected = false
    private var pendingFrames: [PendingFrame] = []
    private var committedTail = ""
    private var nextSequence: Int64 = 0
    private var pendingExplicitCommits: [ExplicitCommitRequest] = []
    private var nextExplicitCommitID = 0
    private var acknowledgedExplicitCommitID = 0
    private var connectionGeneration = 0
    private var lastPeriodicCommitMilliseconds: Int64 = 0
    private var receiveTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<ScribeRealtimeClientEvent>.Continuation] = [:]

    public init(transport: any ScribeRealtimeTransport = URLSessionScribeRealtimeTransport()) {
        self.transport = transport
    }

    public nonisolated func events() -> AsyncStream<ScribeRealtimeClientEvent> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { _ in Task { await self.removeContinuation(id) } }
            Task { await self.addContinuation(continuation, id: id) }
        }
    }

    public func startRealtime(
        apiKey: String,
        configuration: ScribeRealtimeConfiguration
    ) async throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw TranscriptionFailure(kind: .missingKey, message: "Add an ElevenLabs API key first.")
        }
        guard !isActive else {
            throw TranscriptionFailure(
                kind: .invalidInput,
                message: "Realtime transcription is already active."
            )
        }
        resetMeetingState()
        self.configuration = configuration
        self.configuration.commitStrategy = "manual"
        self.apiKey = key
        isActive = true
        do {
            try await connect(attempt: 1, replayPending: true)
            receiveTask = Task { await self.receiveLoop() }
        } catch {
            isActive = false
            isConnected = false
            self.apiKey = nil
            resetMeetingState()
            transition(.failed(normalizedFailure(error)))
            throw error
        }
    }

    public func send(_ frame: AudioFrame) async throws {
        guard frame.sampleRate == 16_000,
              frame.channelCount == 1,
              frame.pcmData.count == frame.sampleCount * MemoryLayout<Int16>.size,
              (100...1_000).contains(frame.durationMilliseconds) else {
            throw TranscriptionFailure(
                kind: .invalidInput,
                message: "Realtime audio must be mono 16-bit PCM at 16 kHz in 0.1–1.0 second chunks."
            )
        }
        let pending = PendingFrame(sequence: nextSequence, frame: frame)
        nextSequence += 1
        pendingFrames.append(pending)
        if pendingFrames.count > Self.maximumQueuedFrames {
            pendingFrames.removeFirst(pendingFrames.count - Self.maximumQueuedFrames)
            transition(.delayed(queuedFrames: pendingFrames.count))
        }
        guard isConnected else { return }
        try await sendFrame(frame, previousText: nil)
        let frameEnd = frame.startMilliseconds + frame.durationMilliseconds
        if configuration.commitStrategy == "manual",
           pendingExplicitCommits.isEmpty,
           frameEnd - lastPeriodicCommitMilliseconds >= Self.periodicCommitMilliseconds {
            _ = try await issueExplicitCommit()
            lastPeriodicCommitMilliseconds = frameEnd
        }
    }

    public func commit() async throws {
        guard isConnected else { return }
        _ = try await issueExplicitCommit()
        if let lastFrame = pendingFrames.last?.frame {
            lastPeriodicCommitMilliseconds = lastFrame.startMilliseconds + lastFrame.durationMilliseconds
        }
    }

    private func issueExplicitCommit() async throws -> Int {
        nextExplicitCommitID += 1
        let request = ExplicitCommitRequest(
            id: nextExplicitCommitID,
            frameBoundary: pendingFrames.last?.sequence,
            connectionGeneration: connectionGeneration
        )
        pendingExplicitCommits.append(request)
        do {
            try await sendChunk(audio: Data(), commit: true, previousText: nil)
        } catch {
            pendingExplicitCommits.removeAll { $0.id == request.id }
            throw error
        }
        return request.id
    }

    public func stopRealtime() async {
        guard isActive else { return }
        transition(.stopping)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while isActive, clock.now < deadline {
            guard isConnected else {
                try? await Task.sleep(for: .milliseconds(50))
                continue
            }
            do {
                let generation = connectionGeneration
                let id = try await issueExplicitCommit()
                if await waitForExplicitCommit(
                    id: id,
                    connectionGeneration: generation,
                    deadline: deadline
                ) {
                    break
                }
            } catch {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        isActive = false
        isConnected = false
        apiKey = nil
        receiveTask?.cancel()
        receiveTask = nil
        await transport.close()
        resetMeetingState()
        transition(.finished)
    }

    public func diagnostics() -> (state: RealtimeTranscriptionState, queuedFrames: Int) {
        (state, pendingFrames.count)
    }

    public static func request(
        apiKey: String,
        configuration: ScribeRealtimeConfiguration
    ) throws -> URLRequest {
        var components = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")
        var items = [
            URLQueryItem(name: "model_id", value: "scribe_v2_realtime"),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "include_timestamps", value: "true"),
            URLQueryItem(name: "include_language_detection", value: configuration.includeLanguageDetection ? "true" : "false"),
            URLQueryItem(name: "commit_strategy", value: configuration.commitStrategy),
            URLQueryItem(name: "vad_silence_threshold_secs", value: "1.5"),
            URLQueryItem(name: "vad_threshold", value: "0.4"),
        ]
        if let language = configuration.languageCode, !language.isEmpty {
            items.append(URLQueryItem(name: "language_code", value: language))
        }
        items.append(contentsOf: configuration.keyterms.map { URLQueryItem(name: "keyterms", value: $0) })
        components?.queryItems = items
        guard let url = components?.url else {
            throw TranscriptionFailure(kind: .invalidInput, message: "Could not build Scribe realtime URL.")
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        return request
    }

    private func connect(attempt: Int, replayPending: Bool) async throws {
        guard let apiKey else { return }
        if case .stopping = state {
            // Preserve the terminal lifecycle state while reconnecting to flush audio.
        } else {
            transition(.connecting(attempt: attempt))
        }
        try await transport.connect(request: Self.request(apiKey: apiKey, configuration: configuration))
        if replayPending {
            let previous = String(committedTail.suffix(50))
            var index = 0
            while index < pendingFrames.count {
                let pending = pendingFrames[index]
                try await sendFrame(
                    pending.frame,
                    previousText: index == 0 && !previous.isEmpty ? previous : nil
                )
                index += 1
            }
        }
        connectionGeneration += 1
        isConnected = true
    }

    private func receiveLoop() async {
        var attempt = 0
        while isActive && !Task.isCancelled {
            do {
                let event = try ScribeRealtimeEvent.decode(await transport.receive().data)
                try await handle(event)
                attempt = 0
            } catch is CancellationError {
                return
            } catch {
                isConnected = false
                // A response from the closed transport can no longer acknowledge
                // these requests. Replayed audio will be covered by the next commit.
                pendingExplicitCommits.removeAll(keepingCapacity: true)
                let failure = normalizedFailure(error)
                guard failure.isRetryable, isActive, attempt < 5 else {
                    transition(.failed(failure))
                    isActive = false
                    apiKey = nil
                    resetMeetingState()
                    return
                }
                attempt += 1
                if case .stopping = state {
                    // Stop owns the visible state while the transport reconnects.
                } else {
                    transition(.delayed(queuedFrames: pendingFrames.count))
                }
                let base = min(pow(2.0, Double(attempt - 1)) * 0.5, 8)
                let delay = base + Double.random(in: 0...(base * 0.2))
                try? await Task.sleep(for: .seconds(delay))
                do {
                    try await connect(attempt: attempt + 1, replayPending: true)
                } catch {
                    continue
                }
            }
        }
    }

    private func handle(_ event: ScribeRealtimeEvent) async throws {
        broadcast(.server(event))
        switch event {
        case .sessionStarted(let id):
            if case .stopping = state {
                break
            }
            transition(.connected(sessionID: id))
        case .committed(let text):
            committedTail = (committedTail + " " + text).trimmingCharacters(in: .whitespaces)
            acknowledgeNextExplicitCommit()
        case .committedWithTimestamps(let text, let words):
            if !committedTail.hasSuffix(text) {
                committedTail = (committedTail + " " + text).trimmingCharacters(in: .whitespaces)
            }
            let endMilliseconds = words.map { Int64(($0.endSeconds * 1_000).rounded()) }.max()
            acknowledgeTimestampedFrames(throughMilliseconds: endMilliseconds)
        case .error(let failure):
            throw failure
        case .partial, .unknown:
            break
        }
    }

    private func sendFrame(_ frame: AudioFrame, previousText: String?) async throws {
        try await sendChunk(audio: frame.pcmData, commit: false, previousText: previousText)
    }

    private func sendChunk(audio: Data, commit: Bool, previousText: String?) async throws {
        let chunk = InputChunk(
            audioBase64: audio.base64EncodedString(),
            commit: commit,
            previousText: previousText
        )
        let data = try JSONEncoder().encode(chunk)
        let transport = transport
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await transport.send(data: data) }
            group.addTask {
                try await Task.sleep(for: Self.transportSendTimeout)
                await transport.close()
                throw TranscriptionFailure(
                    kind: .transient,
                    message: "Realtime audio send timed out."
                )
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw CancellationError()
            }
            return first
        }
    }

    private func normalizedFailure(_ error: any Error) -> TranscriptionFailure {
        if let failure = error as? TranscriptionFailure { return failure }
        if error is CancellationError {
            return TranscriptionFailure(kind: .cancelled, message: "Realtime transcription was cancelled.")
        }
        return TranscriptionFailure(kind: .transient, message: "Realtime connection was interrupted.")
    }

    private func transition(_ newState: RealtimeTranscriptionState) {
        state = newState
        broadcast(.state(newState))
    }

    private func broadcast(_ event: ScribeRealtimeClientEvent) {
        for continuation in continuations.values { continuation.yield(event) }
    }

    private func addContinuation(_ continuation: AsyncStream<ScribeRealtimeClientEvent>.Continuation, id: UUID) {
        continuations[id] = continuation
        continuation.yield(.state(state))
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func acknowledgeNextExplicitCommit() {
        if !pendingExplicitCommits.isEmpty {
            let request = pendingExplicitCommits.removeFirst()
            if let boundary = request.frameBoundary {
                pendingFrames.removeAll { $0.sequence <= boundary }
            }
            acknowledgedExplicitCommitID = max(acknowledgedExplicitCommitID, request.id)
        } else if pendingFrames.count > 8 {
            pendingFrames.removeFirst(pendingFrames.count - 8)
        }
    }

    private func acknowledgeTimestampedFrames(throughMilliseconds: Int64?) {
        if let throughMilliseconds {
            pendingFrames.removeAll {
                $0.frame.startMilliseconds + $0.frame.durationMilliseconds <= throughMilliseconds
            }
        }
    }

    private func waitForExplicitCommit(
        id: Int,
        connectionGeneration expectedGeneration: Int,
        deadline: ContinuousClock.Instant
    ) async -> Bool {
        let clock = ContinuousClock()
        while acknowledgedExplicitCommitID < id, clock.now < deadline, isActive {
            guard isConnected,
                  connectionGeneration == expectedGeneration,
                  pendingExplicitCommits.contains(where: { $0.id == id }) else {
                return false
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return acknowledgedExplicitCommitID >= id
    }

    private func resetMeetingState() {
        pendingFrames.removeAll(keepingCapacity: true)
        committedTail = ""
        nextSequence = 0
        pendingExplicitCommits.removeAll(keepingCapacity: true)
        nextExplicitCommitID = 0
        acknowledgedExplicitCommitID = 0
        connectionGeneration = 0
        lastPeriodicCommitMilliseconds = 0
    }
}
