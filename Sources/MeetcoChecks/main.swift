import AVFoundation
import Foundation
import MeetcoCapture
import MeetcoCore
import Security

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw CheckFailure(description: message) }
}

private actor RealtimeCheckTransport: ScribeRealtimeTransport {
    private var payloads: [Data] = []

    func connect(request: URLRequest) async throws {}

    func send(data: Data) async throws {
        payloads.append(data)
    }

    func receive() async throws -> ScribeRealtimeMessage {
        try await Task.sleep(for: .seconds(60))
        throw CancellationError()
    }

    func close() async {}

    func payloadCount() -> Int { payloads.count }
}

private actor InterleavedCommitCheckTransport: ScribeRealtimeTransport {
    private var explicitCommitCount = 0
    private var receiveIndex = 0
    private var priorCommitPairHandled = false
    private var finalCommitAllowed = false
    private var isClosed = false

    func connect(request: URLRequest) async throws {}

    func send(data: Data) async throws {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if object?["commit"] as? Bool == true { explicitCommitCount += 1 }
    }

    func receive() async throws -> ScribeRealtimeMessage {
        let index = receiveIndex
        receiveIndex += 1
        if index == 0 {
            return .data(Data(#"{"message_type":"session_started","session_id":"check"}"#.utf8))
        }
        while explicitCommitCount < 2 {
            try await Task.sleep(for: .milliseconds(5))
        }
        if index == 1 {
            return .data(Data(#"{"message_type":"committed_transcript","text":"earlier"}"#.utf8))
        }
        if index == 2 {
            return .data(Data(#"{"message_type":"committed_transcript_with_timestamps","text":"earlier","words":[{"text":"earlier","start":0.0,"end":0.2}]}"#.utf8))
        }
        if index == 3 {
            priorCommitPairHandled = true
            while !finalCommitAllowed {
                try await Task.sleep(for: .milliseconds(5))
            }
            return .data(Data(#"{"message_type":"committed_transcript","text":"final"}"#.utf8))
        }
        try await Task.sleep(for: .seconds(60))
        throw CancellationError()
    }

    func close() async { isClosed = true }

    func waitUntilPriorCommitPairHandled() async throws {
        while !priorCommitPairHandled {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    func releaseFinalCommit() { finalCommitAllowed = true }
    func closed() -> Bool { isClosed }
}

private actor ReconnectDuringStopCheckTransport: ScribeRealtimeTransport {
    private var connectionCount = 0
    private var explicitCommitCount = 0
    private var receiveIndex = 0

    func connect(request: URLRequest) async throws { connectionCount += 1 }

    func send(data: Data) async throws {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if object?["commit"] as? Bool == true { explicitCommitCount += 1 }
    }

    func receive() async throws -> ScribeRealtimeMessage {
        let index = receiveIndex
        receiveIndex += 1
        if index == 0 {
            return .data(Data(#"{"message_type":"session_started","session_id":"first"}"#.utf8))
        }
        if index == 1 {
            while explicitCommitCount < 1 { try await Task.sleep(for: .milliseconds(5)) }
            throw TranscriptionFailure(kind: .transient, message: "fixture disconnect")
        }
        if index == 2 {
            return .data(Data(#"{"message_type":"session_started","session_id":"second"}"#.utf8))
        }
        if index == 3 {
            while explicitCommitCount < 2 { try await Task.sleep(for: .milliseconds(5)) }
            return .data(Data(#"{"message_type":"committed_transcript","text":"replayed final"}"#.utf8))
        }
        try await Task.sleep(for: .seconds(60))
        throw CancellationError()
    }

    func close() async {}
    func counts() -> (connections: Int, commits: Int) { (connectionCount, explicitCommitCount) }
}

private final class FixtureAgentProvider: AgentProvider, @unchecked Sendable {
    let kind: AgentProviderKind
    let capabilities = AgentCapabilities(
        streaming: true,
        structuredOutput: true,
        usesLocalCLIAuth: false
    )
    private let lock = NSLock()
    private var responses: [String]
    private var requests: [AgentRequest] = []

    init(kind: AgentProviderKind, responses: [String]) {
        self.kind = kind
        self.responses = responses
    }

    func healthCheck() async -> ProviderHealth {
        ProviderHealth(state: .ready, detail: "Fixture provider is ready.")
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        let response = lock.withLock { () -> String in
            requests.append(request)
            return responses.isEmpty ? "" : responses.removeFirst()
        }
        return AsyncThrowingStream { continuation in
            continuation.yield(.textDelta(response))
            continuation.yield(.completed(response))
            continuation.finish()
        }
    }

    func capturedRequests() -> [AgentRequest] {
        lock.withLock { requests }
    }
}

private struct FailingFixtureAgentProvider: AgentProvider {
    let kind = AgentProviderKind.codexCLI
    let capabilities = AgentCapabilities(
        streaming: true,
        structuredOutput: true,
        usesLocalCLIAuth: true
    )

    func healthCheck() async -> ProviderHealth {
        ProviderHealth(state: .ready, detail: "Fixture provider is ready.")
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("Partial grounded answer"))
            continuation.finish(throwing: AgentProviderError.invalidResponse("Fixture failure"))
        }
    }
}

@main
enum MeetcoChecks {
    static func main() async throws {
        try checkModels()
        try await checkRepository()
        try checkKeychain()
        try checkCaptureContracts()
        try await checkCapturePipeline()
        try await checkTranscriptionPipeline()
        try await checkAgentAndMCPPipeline()
        print("PASS: Meetco foundation, capture, transcription, agent, and MCP checks")
    }

    private static func checkModels() throws {
        let meeting = Meeting(title: "Check", now: Date(timeIntervalSince1970: 1_000))
        let segment = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 0,
            endMilliseconds: 250,
            text: "Ship Meetco",
            version: .final
        )
        let snapshot = MeetingContextSnapshot(meeting: meeting, transcript: [segment])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MeetingContextSnapshot.self, from: data)
        try require(decoded == snapshot, "Meeting snapshot did not round-trip")

        let audioOnly = MeetingConfiguration(
            transcriptionMode: .realtime,
            audioRetention: .audioOnly,
            languageCode: "  ",
            keyterms: ["  Meetco  ", "MEETCO", "<unsafe>"]
        ).normalizedForSession()
        try require(
            audioOnly.transcriptionMode == .recordOnly
                && audioOnly.audioRetention == .audioOnly
                && !audioOnly.polishWithBatchAfterRealtime,
            "Audio-only retention did not normalize dependent transcription settings"
        )
        try require(
            audioOnly.languageCode == nil && audioOnly.keyterms == ["Meetco", "unsafe"],
            "Session transcription fields were not normalized"
        )

        let frame = AudioFrame(
            source: .mixed,
            startMilliseconds: 0,
            sampleCount: 4_000,
            pcmData: Data(count: 8_000)
        )
        try require(frame.durationMilliseconds == 250, "Audio frame duration is incorrect")
    }

    private static func checkRepository() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoChecks-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ApplicationPaths.testing(root: root)
        let repository = try MeetingRepository(paths: paths)
        var meeting = try await repository.createMeeting(title: "Repository", configuration: .init())
        meeting.status = .recording
        try await repository.saveMeeting(meeting)
        try Data(count: LocalAudioInspection.maximumHeaderOnlyCAFByteCount + 1).write(
            to: paths.audioDirectory(id: meeting.id).appendingPathComponent("microphone-01.caf")
        )
        let recovered = try await repository.recoverInterruptedMeetings()
        try require(recovered.map(\.id) == [meeting.id], "Interrupted meeting was not recovered")
        try require(recovered[0].hasLocalAudio, "Recovery lost the preserved-audio state")
        try require(
            FileManager.default.fileExists(atPath: paths.audioDirectory(id: meeting.id).path),
            "Recovery removed local audio directory"
        )

        var missingAudio = try await repository.createMeeting(title: "Missing audio", configuration: .init())
        missingAudio.status = .finalizing
        missingAudio.hasLocalAudio = true
        try await repository.saveMeeting(missingAudio)
        try FileManager.default.removeItem(at: paths.audioDirectory(id: missingAudio.id))
        _ = try await repository.recoverInterruptedMeetings()
        let recoveredWithoutAudio = try await repository.loadMeeting(id: missingAudio.id)
        try require(!recoveredWithoutAudio.hasLocalAudio, "Recovery claimed missing audio was preserved")
        var staleRecoverable = recoveredWithoutAudio
        staleRecoverable.hasLocalAudio = true
        try await repository.saveMeeting(staleRecoverable)
        _ = try await repository.recoverInterruptedMeetings()
        let reconciledRecoverable = try await repository.loadMeeting(id: missingAudio.id)
        try require(
            !reconciledRecoverable.hasLocalAudio,
            "Launch did not reconcile stale audio metadata on a recoverable meeting"
        )
        let headerOnlyDirectory = root.appendingPathComponent("header-only-audio", isDirectory: true)
        try FileManager.default.createDirectory(at: headerOnlyDirectory, withIntermediateDirectories: true)
        let headerOnlyMix = headerOnlyDirectory.appendingPathComponent("final-mix.wav")
        try Data(count: LocalAudioInspection.pcmWAVHeaderByteCount).write(to: headerOnlyMix)
        try require(
            !LocalAudioInspection.hasUsableAudio(in: headerOnlyDirectory),
            "A header-only final mix was advertised as usable audio"
        )
    }

    private static func checkKeychain() throws {
        let store = KeychainStore(service: "com.meetco.checks.\(UUID().uuidString)")
        defer { try? store.deleteSecret(for: .elevenLabsAPIKey) }
        do {
            try store.setSecret("verification-only", for: .elevenLabsAPIKey)
            let storedSecret = try store.secret(for: .elevenLabsAPIKey)
            try require(
                storedSecret == "verification-only",
                "Keychain secret lifecycle failed"
            )
        } catch let error as KeychainError where error.status == errSecNotAvailable {
            print("SKIP: Keychain unavailable in command-line environment")
        }
    }

    private static func checkCaptureContracts() throws {
        let status = CaptureStatus(
            microphone: .microphonePermissionRequired,
            systemAudio: .screenRecordingPermissionRequired
        )
        try require(status.microphone == .microphonePermissionRequired, "Mic status changed")
        try require(
            CaptureAvailability.microphonePermissionDenied != .microphonePermissionRequired,
            "Denied microphone access lost its recovery state"
        )
    }

    private static func checkCapturePipeline() async throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800) else {
            throw CheckFailure(description: "Could not allocate verification audio")
        }
        buffer.frameLength = 4_800
        for channelIndex in 0..<2 {
            guard let channel = buffer.floatChannelData?[channelIndex] else {
                throw CheckFailure(description: "Missing verification audio channel")
            }
            for sampleIndex in 0..<4_800 {
                channel[sampleIndex] = channelIndex == 0 ? 0.5 : -0.25
            }
        }
        guard let captured = CapturedAudioBuffer(
            source: .system,
            presentationTimeSeconds: 0,
            copying: buffer
        ) else {
            throw CheckFailure(description: "Could not copy verification audio")
        }
        let converted = try AudioBufferConverter().convert(captured, startMilliseconds: 120)
        try require(converted.startMilliseconds == 120, "Conversion lost timeline position")
        try require(
            abs(converted.samples.count - 1_600) <= 2,
            "Conversion did not produce 16 kHz mono audio"
        )

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
        let prematureFrames = await mixer.append(microphone)
        try require(prematureFrames.isEmpty, "Mixer emitted before both sources arrived")
        let mixedFrames = await mixer.append(system)
        try require(mixedFrames.count == 1, "Mixer did not emit an aligned frame")
        let mixedSamples = mixedFrames[0].pcmData.withUnsafeBytes {
            Array($0.bindMemory(to: Int16.self))
        }
        try require(mixedSamples.first == 6_000, "Mixer did not average aligned sources")

        let stalledMixer = AudioTimelineMixer(expectedSources: [.microphone, .system])
        var boundedFrames: [AudioFrame] = []
        for index in 0..<5 {
            boundedFrames += await stalledMixer.append(ConvertedAudioChunk(
                source: .microphone,
                startMilliseconds: Int64(index * 250),
                samples: Array(repeating: 8_000, count: 4_000)
            ))
        }
        try require(boundedFrames.count == 1, "A stalled online source left the mixer unbounded")
        let boundedSamples = boundedFrames[0].pcmData.withUnsafeBytes {
            Array($0.bindMemory(to: Int16.self))
        }
        try require(boundedSamples.first == 4_000, "Stalled source silence was not mixed correctly")

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoCaptureChecks-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let meetingID = UUID()
        let archive = try AudioArchiveWriter(meetingID: meetingID, directory: root)
        try await archive.append(captured, atMilliseconds: 0)
        let manifestURL = try await archive.finish(now: Date(timeIntervalSince1970: 50))
        let manifest = try AtomicFileWriter.read(AudioArchiveManifest.self, from: manifestURL)
        try require(manifest.meetingID == meetingID, "Archive manifest lost meeting identity")
        try require(manifest.tracks.count == 1, "Archive did not retain its source track")
        try require(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(manifest.tracks[0].fileName).path
            ),
            "Archive manifest points to a missing source track"
        )

        let wavURL = root.appendingPathComponent("final-mix.wav")
        let wavWriter = try PCM16WAVWriter(url: wavURL)
        try await wavWriter.append(mixedFrames[0])
        _ = try await wavWriter.finish()
        let header = try Data(contentsOf: wavURL).prefix(12)
        try require(String(decoding: header.prefix(4), as: UTF8.self) == "RIFF", "WAV RIFF header missing")
        try require(String(decoding: header.suffix(4), as: UTF8.self) == "WAVE", "WAV format header missing")
    }

    private static func checkTranscriptionPipeline() async throws {
        let eventData = Data(#"{"message_type":"committed_transcript_with_timestamps","text":"Xin chào","words":[{"text":"Xin","start":0.1,"end":0.3},{"text":" chào","start":0.3,"end":0.6}]}"#.utf8)
        guard case .committedWithTimestamps(let text, let words) = try ScribeRealtimeEvent.decode(eventData) else {
            throw CheckFailure(description: "Realtime timestamp event was not decoded")
        }
        try require(text == "Xin chào" && words.count == 2, "Realtime event payload changed")
        let authData = Data(#"{"message_type":"auth_error","message":"Invalid API key"}"#.utf8)
        guard case .error(let authFailure) = try ScribeRealtimeEvent.decode(authData) else {
            throw CheckFailure(description: "Realtime error event was not decoded")
        }
        try require(authFailure.kind == .authentication, "Realtime auth error is not actionable")

        let assembler = RealtimeTranscriptAssembler(meetingID: UUID())
        _ = await assembler.apply(.sessionStarted(id: "check-session"))
        _ = await assembler.apply(.partial(text: "Xin ch"))
        _ = await assembler.apply(.committed(text: "Xin chào"))
        let assembled = await assembler.apply(.committedWithTimestamps(text: text, words: words))
        try require(assembled.partial == nil, "Committed transcript did not clear partial text")
        try require(assembled.committed.count == 1, "Timestamp enrichment duplicated committed text")
        try require(assembled.committed[0].endMilliseconds == 600, "Timestamp enrichment was lost")

        let transport = RealtimeCheckTransport()
        let realtime = ScribeRealtimeClient(transport: transport)
        try await realtime.startRealtime(apiKey: "verification-key", configuration: .init())
        let frame = AudioFrame(
            source: .mixed,
            startMilliseconds: 0,
            sampleCount: 4_000,
            pcmData: Data(count: 8_000)
        )
        for _ in 0...ScribeRealtimeClient.maximumQueuedFrames {
            try await realtime.send(frame)
        }
        let diagnostics = await realtime.diagnostics()
        try require(
            diagnostics.queuedFrames == ScribeRealtimeClient.maximumQueuedFrames,
            "Realtime persisted backlog is not bounded"
        )
        let sentCount = await transport.payloadCount()
        try require(
            sentCount == ScribeRealtimeClient.maximumQueuedFrames + 1,
            "Realtime transport dropped connected audio"
        )
        await realtime.stopRealtime()
        let afterStop = await realtime.diagnostics()
        try require(afterStop.queuedFrames == 0, "Realtime retained audio after stop")
        try await realtime.startRealtime(apiKey: "verification-key", configuration: .init())
        let afterRestart = await realtime.diagnostics()
        try require(afterRestart.queuedFrames == 0, "Realtime replayed a previous meeting")
        await realtime.stopRealtime()

        let interleavedTransport = InterleavedCommitCheckTransport()
        let boundaryClient = ScribeRealtimeClient(transport: interleavedTransport)
        try await boundaryClient.startRealtime(apiKey: "verification-key", configuration: .init())
        try await boundaryClient.send(frame)
        try await boundaryClient.commit()
        let boundaryStop = Task { await boundaryClient.stopRealtime() }
        try await interleavedTransport.waitUntilPriorCommitPairHandled()
        try await Task.sleep(for: .milliseconds(100))
        let stateDuringPriorTimestamp = await boundaryClient.diagnostics().state
        try require(
            stateDuringPriorTimestamp == .stopping,
            "A prior timestamp event incorrectly acknowledged the final explicit commit"
        )
        let closedBeforeFinalCommit = await interleavedTransport.closed()
        try require(
            !closedBeforeFinalCommit,
            "Realtime closed before the final explicit commit acknowledgement"
        )
        await interleavedTransport.releaseFinalCommit()
        await boundaryStop.value

        let reconnectTransport = ReconnectDuringStopCheckTransport()
        let reconnectClient = ScribeRealtimeClient(transport: reconnectTransport)
        try await reconnectClient.startRealtime(apiKey: "verification-key", configuration: .init())
        try await reconnectClient.send(frame)
        await reconnectClient.stopRealtime()
        let reconnectCounts = await reconnectTransport.counts()
        try require(
            reconnectCounts.connections >= 2 && reconnectCounts.commits >= 2,
            "Stop did not replay and recommit after a transient disconnect"
        )

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoTranscriptionChecks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audioURL = root.appendingPathComponent("final.wav")
        try Data("RIFFverification".utf8).write(to: audioURL)
        let upload = try ScribeBatchClient.makeUpload(
            audioURL: audioURL,
            apiKey: "verification-key",
            languageCode: "vi",
            keyterms: ["Meetco", "Q4 forecast", "one two three four five six"],
            numberOfSpeakers: 2,
            temporaryDirectory: root
        )
        let uploadBody = try String(decoding: Data(contentsOf: upload.body.url), as: UTF8.self)
        try require(uploadBody.contains("scribe_v2"), "Batch upload omitted the Scribe v2 model")
        try require(uploadBody.contains("name=\"diarize\"\r\n\r\ntrue"), "Batch upload omitted diarization")
        try require(
            uploadBody.contains("name=\"keyterms\"\r\n\r\nMeetco")
                && uploadBody.contains("name=\"keyterms\"\r\n\r\nQ4 forecast")
                && uploadBody.contains("name=\"keyterms\"\r\n\r\none two three four five\r\n")
                && !uploadBody.contains("one two three four five six"),
            "Batch upload omitted configured keyterms"
        )

        let meetingID = UUID()
        let batchResponse = ScribeBatchResponse(
            languageCode: "vi",
            languageProbability: 0.98,
            text: "Xin chào. Quyết định xong.",
            words: [
                .init(text: "Xin", start: 0, end: 0.2, speakerID: "speaker_0"),
                .init(text: "chào", start: 0.2, end: 0.5, speakerID: "speaker_0"),
                .init(text: ".", start: 0.5, end: 0.55, speakerID: "speaker_0"),
                .init(text: "Quyết định", start: 1, end: 1.4, speakerID: "speaker_1"),
                .init(text: "xong", start: 1.4, end: 1.8, speakerID: "speaker_1"),
                .init(text: ".", start: 1.8, end: 1.9, speakerID: "speaker_1"),
            ]
        )
        let finalSegments = ScribeBatchClient.segments(from: batchResponse, meetingID: meetingID)
        try require(finalSegments.map(\.text) == ["Xin chào.", "Quyết định xong."], "Batch word grouping changed")
        let reconciliation = TranscriptReconciler.reconcile(
            provisional: assembled.committed,
            final: finalSegments
        )
        try require(reconciliation.provisional.count == 1, "Reconciliation discarded provisional text")
        try require(reconciliation.final.count == 2, "Reconciliation discarded final text")
        let remapped = TranscriptReconciler.remap(
            EvidenceReference(segmentIDs: [assembled.committed[0].id]),
            using: reconciliation
        )
        try require(
            remapped.segmentIDs == [finalSegments[0].id],
            "Reconciliation did not preserve live evidence against the final transcript"
        )

        let remapRepository = try MeetingRepository(paths: .testing(
            root: root.appendingPathComponent("evidence-remap", isDirectory: true)
        ))
        let remapMeeting = try await remapRepository.createMeeting(configuration: .init())
        try await remapRepository.saveChat([
            ChatMessage(
                meetingID: remapMeeting.id,
                role: .assistant,
                content: "Grounded",
                evidenceSegmentIDs: [assembled.committed[0].id]
            )
        ], id: remapMeeting.id)
        try await remapRepository.saveArtifacts(MeetingArtifacts(
            decisions: [EvidenceLinkedText(
                text: "Decision",
                evidence: EvidenceReference(segmentIDs: [assembled.committed[0].id])
            )]
        ), id: remapMeeting.id)
        let persistedRemap = try await PersistedEvidenceRemapper.remap(
            meetingID: remapMeeting.id,
            reconciliation: reconciliation,
            repository: remapRepository
        )
        try require(
            persistedRemap.chat[0].evidenceSegmentIDs == [finalSegments[0].id]
                && persistedRemap.artifacts.decisions[0].evidence.segmentIDs == [finalSegments[0].id],
            "Final transcript reconciliation did not remap persisted evidence"
        )
    }

    private static func checkAgentAndMCPPipeline() async throws {
        var configuration = MeetingConfiguration()
        configuration.mcpEnabled = true
        let meeting = Meeting(title: "Agent and MCP", configuration: configuration)
        let segment = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            text: "Cris owns the launch checklist for Friday.",
            version: .final
        )
        let snapshot = MeetingContextSnapshot(
            meeting: meeting,
            transcript: [segment],
            artifacts: MeetingArtifacts(summary: "Prepare the Friday launch.")
        )
        let context = MeetingContextBuilder.build(
            snapshot: snapshot,
            query: "Who owns the launch checklist?",
            characterBudget: 3_000
        )
        try require(context.text.contains("UNTRUSTED MEETING TRANSCRIPT"), "Agent context lacks a trust boundary")
        try require(context.includedSegmentIDs == [segment.id], "Agent context lost relevant evidence")

        let artifactOutput = """
        {"summary":"Launch prep","keyPoints":[],"decisions":[],"actionItems":[{"title":"Own launch checklist","owner":"Cris","dueDate":null,"evidenceSegmentIDs":["\(segment.id.uuidString)"],"confidence":0.9}],"openQuestions":[],"risks":[],"followUpDraft":null}
        """
        let artifacts = try ArtifactParser.parse(
            artifactOutput,
            snapshot: snapshot,
            provider: .claudeAPI,
            now: Date(timeIntervalSince1970: 100)
        )
        try require(artifacts.actionItems[0].evidence.segmentIDs == [segment.id], "Artifact evidence was not retained")
        do {
            _ = try ArtifactParser.parse(
                artifactOutput.replacingOccurrences(of: segment.id.uuidString, with: UUID().uuidString),
                snapshot: snapshot,
                provider: .claudeAPI
            )
            throw CheckFailure(description: "Artifact parser accepted invented evidence")
        } catch is ArtifactParserError {}

        let sse = Data(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"Grounded answer"}}"#.utf8)
        let parsedSSE = try ClaudeAPIProvider.parseSSE(sse)
        try require(
            parsedSSE == .textDelta("Grounded answer"),
            "Claude SSE delta parsing changed"
        )
        let apiRequest = try ClaudeAPIProvider.urlRequest(
            AgentRequest(systemPrompt: "system", userPrompt: "question"),
            apiKey: "verification-key",
            model: "verification-model"
        )
        try require(apiRequest.value(forHTTPHeaderField: "x-api-key") == "verification-key", "Claude auth header missing")
        try require(
            !(String(decoding: apiRequest.httpBody ?? Data(), as: UTF8.self).contains("verification-key")),
            "Claude key leaked into request body"
        )

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoAgentChecks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try MeetingRepository(paths: .testing(root: root))
        var selectedRecipeConfiguration = configuration
        selectedRecipeConfiguration.artifactRecipe.actionItems = false
        let storedMeeting = try await repository.createMeeting(
            title: "Provider switching",
            configuration: selectedRecipeConfiguration
        )
        let storedSegment = TranscriptSegment(
            meetingID: storedMeeting.id,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            text: segment.text,
            version: .final
        )
        try await repository.saveTranscript([storedSegment], id: storedMeeting.id, version: .final)
        let livePartial = TranscriptSegment(
            meetingID: storedMeeting.id,
            startMilliseconds: 2_000,
            endMilliseconds: 2_500,
            text: "unfinished partial thought",
            version: .provisional,
            isCommitted: false
        )
        let storedSnapshot = MeetingContextSnapshot(
            meeting: storedMeeting,
            transcript: [storedSegment, livePartial]
        )
        let claudeFixture = FixtureAgentProvider(kind: .claudeAPI, responses: ["Cris owns it."])
        let codexFixture = FixtureAgentProvider(kind: .codexCLI, responses: ["Cris owns it."])
        let service = AgentService(
            providers: [claudeFixture, codexFixture],
            repository: repository
        )
        for providerKind in [AgentProviderKind.claudeAPI, .codexCLI] {
            let stream = await service.chat(
                snapshot: storedSnapshot,
                message: "Who owns the launch checklist?",
                provider: providerKind
            )
            for try await _ in stream {}
        }
        let persistedChat = try await repository.loadChat(id: storedMeeting.id)
        try require(persistedChat.count == 4, "Provider switching overwrote local chat history")
        try require(
            persistedChat.filter { $0.role == .assistant }.allSatisfy {
                $0.status == .complete && !$0.evidenceSegmentIDs.contains(livePartial.id)
            },
            "Canonical chat persisted evidence for an ephemeral partial segment"
        )
        let claudePrompt = claudeFixture.capturedRequests().first?.userPrompt ?? ""
        let codexPrompt = codexFixture.capturedRequests().first?.userPrompt ?? ""
        try require(claudePrompt.contains(storedSegment.id.uuidString), "Claude did not receive grounded context")
        try require(codexPrompt.contains(storedSegment.id.uuidString), "Codex did not receive grounded context")

        let concurrentFixture = FixtureAgentProvider(
            kind: .claudeAPI,
            responses: ["First concurrent answer.", "Second concurrent answer."]
        )
        let concurrentService = AgentService(
            providers: [concurrentFixture],
            repository: repository
        )
        let firstConcurrent = await concurrentService.chat(
            snapshot: storedSnapshot,
            message: "First concurrent question",
            provider: .claudeAPI
        )
        let secondConcurrent = await concurrentService.chat(
            snapshot: storedSnapshot,
            message: "Second concurrent question",
            provider: .claudeAPI
        )
        async let firstConsumption: Void = consume(firstConcurrent)
        async let secondConsumption: Void = consume(secondConcurrent)
        _ = try await (firstConsumption, secondConsumption)
        let concurrentChat = try await repository.loadChat(id: storedMeeting.id)
        try require(concurrentChat.count == 8, "Concurrent agent turns overwrote chat history")

        let failingService = AgentService(
            providers: [FailingFixtureAgentProvider()],
            repository: repository
        )
        let failedUserID = UUID()
        let failedAssistantID = UUID()
        do {
            let failingStream = await failingService.chat(
                snapshot: storedSnapshot,
                message: "Preserve this failed turn",
                provider: .codexCLI,
                userMessageID: failedUserID,
                assistantMessageID: failedAssistantID
            )
            for try await _ in failingStream {}
            throw CheckFailure(description: "Failing provider unexpectedly completed")
        } catch is CheckFailure {
            throw CheckFailure(description: "Failing provider unexpectedly completed")
        } catch {}
        let failedChat = try await repository.loadChat(id: storedMeeting.id)
        try require(failedChat.count == 10, "A failed chat turn was only partially persisted")
        try require(
            failedChat[8].role == .user
                && failedChat[8].id == failedUserID
                && failedChat[9].role == .assistant
                && failedChat[9].id == failedAssistantID
                && failedChat[9].status == .failed
                && failedChat[9].content == "Partial grounded answer",
            "Failed chat did not persist a canonical assistant terminal state"
        )

        let invalidArtifacts = "not JSON"
        let validArtifacts = artifactOutput.replacingOccurrences(
            of: segment.id.uuidString,
            with: storedSegment.id.uuidString
        )
        let repairFixture = FixtureAgentProvider(
            kind: .claudeAPI,
            responses: [invalidArtifacts, validArtifacts]
        )
        let repairService = AgentService(providers: [repairFixture], repository: repository)
        let repaired = try await repairService.generateArtifacts(
            snapshot: storedSnapshot,
            provider: .claudeAPI,
            now: Date(timeIntervalSince1970: 120)
        )
        try require(repaired.summary == "Launch prep", "Artifact repair did not recover valid output")
        try require(repaired.actionItems.isEmpty, "Agent returned an artifact the user disabled")
        try require(repairFixture.capturedRequests().count == 2, "Artifact repair did not stop after one retry")

        let runner = ProcessRunner()
        let echo = try await runner.run(.init(
            executableURL: URL(fileURLWithPath: "/bin/cat"),
            arguments: [],
            standardInput: Data("meeting context".utf8),
            workingDirectory: root,
            timeoutSeconds: 3
        ))
        try require(String(decoding: echo.standardOutput, as: UTF8.self) == "meeting context", "Process stdin was not delivered")
        let pwd = try await runner.run(.init(
            executableURL: URL(fileURLWithPath: "/bin/pwd"),
            arguments: [],
            workingDirectory: root,
            timeoutSeconds: 3
        ))
        let reportedCWD = URL(fileURLWithPath: String(decoding: pwd.standardOutput, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)).resolvingSymlinksInPath()
        try require(
            reportedCWD == root.resolvingSymlinksInPath(),
            "Process runner did not isolate its working directory"
        )
        do {
            _ = try await runner.run(.init(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["2"],
                workingDirectory: root,
                timeoutSeconds: 0.1
            ))
            throw CheckFailure(description: "Process timeout did not terminate the child")
        } catch AgentProviderError.timedOut {}

        let snapshotURL = root.appendingPathComponent("mcp-snapshot.json")
        let exporter = SnapshotExporter(url: snapshotURL)
        try await exporter.activate(meetingID: meeting.id)
        try await exporter.export(snapshot)
        var nextConfiguration = MeetingConfiguration()
        nextConfiguration.mcpEnabled = true
        let nextMeeting = Meeting(title: "Next MCP meeting", configuration: nextConfiguration)
        let nextSnapshot = MeetingContextSnapshot(meeting: nextMeeting)
        try await exporter.activate(meetingID: nextMeeting.id)
        try await exporter.export(snapshot)
        try require(
            !FileManager.default.fileExists(atPath: snapshotURL.path),
            "An old meeting rewrote the snapshot after a new meeting activated"
        )
        try await exporter.export(nextSnapshot)
        let publishedSnapshot = try SnapshotExporter.load(from: snapshotURL)
        try require(
            publishedSnapshot.meeting.id == nextMeeting.id,
            "The active MCP meeting snapshot was not published"
        )
        let restoredExporter = SnapshotExporter(url: snapshotURL)
        let restoredMeetingID = try await restoredExporter.restoreExistingSnapshot()
        try require(restoredMeetingID == nextMeeting.id, "MCP activation was not restored after relaunch")
        var editedNextSnapshot = nextSnapshot
        editedNextSnapshot.manualNotes = "Edited after relaunch"
        try await restoredExporter.export(editedNextSnapshot)
        let snapshotAfterEdit = try SnapshotExporter.load(from: snapshotURL)
        try require(
            snapshotAfterEdit.manualNotes == "Edited after relaunch",
            "An active MCP snapshot stayed stale after an edit"
        )
        try await exporter.disable(meetingID: meeting.id)
        let snapshotAfterStaleDelete = try SnapshotExporter.load(from: snapshotURL)
        try require(
            snapshotAfterStaleDelete.meeting.id == nextMeeting.id,
            "Deleting an old meeting disabled the new active MCP snapshot"
        )
        try await exporter.activate(meetingID: meeting.id)
        try await exporter.export(snapshot)
        let router = try MCPToolRouter(snapshot: snapshot)
        let searchResult = try router.call(
            name: "meeting.search_transcript",
            arguments: .object(["query": .string("launch")])
        )
        let searchText = String(decoding: try JSONEncoder().encode(searchResult), as: UTF8.self)
        try require(searchText.contains(segment.id.uuidString), "MCP search lost its matching segment")

        guard let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() else {
            throw CheckFailure(description: "Could not locate verification executables")
        }
        let mcpExecutable = executableDirectory.appendingPathComponent("MeetcoMCP")
        try require(FileManager.default.isExecutableFile(atPath: mcpExecutable.path), "MeetcoMCP executable is missing")
        let summaryURI = "meetco://meetings/\(meeting.id.uuidString.lowercased())/summary"
        let requests = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
            #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"meeting.search_transcript","arguments":{"query":"launch"}}}"#,
            #"{"jsonrpc":"2.0","id":4,"method":"resources/list"}"#,
            "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"resources/read\",\"params\":{\"uri\":\"\(summaryURI)\"}}",
            #"{"jsonrpc":"2.0","id":6,"method":"unknown/method"}"#,
        ].joined(separator: "\n") + "\n"
        let serverResult = try await runner.run(.init(
            executableURL: mcpExecutable,
            arguments: ["--snapshot", snapshotURL.path],
            standardInput: Data(requests.utf8),
            workingDirectory: root,
            timeoutSeconds: 5
        ))
        let serverError = String(decoding: serverResult.standardError, as: UTF8.self)
        try require(
            serverResult.exitCode == 0,
            "MeetcoMCP server exited with code \(serverResult.exitCode): \(serverError)"
        )
        let responseLines = serverResult.standardOutput.split(separator: 0x0A)
        let responses = try responseLines.map { line in
            try JSONDecoder().decode(MCPResponse.self, from: Data(line))
        }
        try require(responses.count == 6, "MeetcoMCP did not return one response per request")
        try require(responses[0].error == nil, "MCP initialize failed")
        try require(responses[5].error?.code == -32601, "MCP unknown method error is not spec-shaped")
        let allOutput = String(decoding: serverResult.standardOutput, as: UTF8.self)
        try require(allOutput.contains("meeting.get_snapshot"), "MCP tools/list omitted snapshot")
        try require(allOutput.contains("Prepare the Friday launch"), "MCP resource read omitted summary")
        try require(!allOutput.contains(snapshotURL.path), "MCP leaked an absolute snapshot path")
    }

    private static func consume(
        _ stream: AsyncThrowingStream<AgentEvent, any Error>
    ) async throws {
        for try await _ in stream {}
    }
}
