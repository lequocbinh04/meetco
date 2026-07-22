import Foundation
import Testing
@testable import MeetcoCore

private actor RealtimeFixtureTransport: ScribeRealtimeTransport {
    private var sent: [Data] = []

    func connect(request: URLRequest) async throws {}

    func send(data: Data) async throws {
        sent.append(data)
    }

    func receive() async throws -> ScribeRealtimeMessage {
        try await Task.sleep(for: .seconds(60))
        throw CancellationError()
    }

    func close() async {}

    func sentCount() -> Int { sent.count }
}

private actor InterleavedCommitTransport: ScribeRealtimeTransport {
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
            return .data(Data(#"{"message_type":"session_started","session_id":"fixture"}"#.utf8))
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
            // The client only requests this event after handling both prior events.
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

private actor ReconnectDuringStopTransport: ScribeRealtimeTransport {
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

@Suite("Scribe realtime protocol")
struct ScribeRealtimeEventTests {
    @Test
    func decodesTimestampAndActionableErrorEvents() throws {
        let timestampJSON = Data(#"{"message_type":"committed_transcript_with_timestamps","text":"Xin chào","words":[{"text":"Xin","start":0.1,"end":0.3},{"text":" chào","start":0.3,"end":0.6}]}"#.utf8)
        let event = try ScribeRealtimeEvent.decode(timestampJSON)
        guard case .committedWithTimestamps(let text, let words) = event else {
            Issue.record("Expected timestamp event")
            return
        }
        #expect(text == "Xin chào")
        #expect(words.count == 2)
        #expect(words[1].endSeconds == 0.6)

        let authJSON = Data(#"{"message_type":"auth_error","message":"Invalid API key"}"#.utf8)
        guard case .error(let failure) = try ScribeRealtimeEvent.decode(authJSON) else {
            Issue.record("Expected error event")
            return
        }
        #expect(failure.kind == .authentication)
        #expect(!failure.isRetryable)
    }

    @Test
    func buildsDocumentedRequestAndBoundsPersistedBacklog() async throws {
        let request = try ScribeRealtimeClient.request(
            apiKey: "verification-key",
            configuration: .init(languageCode: "vi", keyterms: ["Meetco"])
        )
        #expect(request.url?.scheme == "wss")
        #expect(request.url?.query?.contains("model_id=scribe_v2_realtime") == true)
        #expect(request.url?.query?.contains("audio_format=pcm_16000") == true)
        #expect(request.url?.query?.contains("commit_strategy=manual") == true)

        let transport = RealtimeFixtureTransport()
        let client = ScribeRealtimeClient(transport: transport)
        try await client.startRealtime(apiKey: "verification-key", configuration: .init())
        let frame = AudioFrame(
            source: .mixed,
            startMilliseconds: 0,
            sampleCount: 4_000,
            pcmData: Data(count: 8_000)
        )
        for _ in 0...ScribeRealtimeClient.maximumQueuedFrames {
            try await client.send(frame)
        }
        let diagnostics = await client.diagnostics()
        #expect(diagnostics.queuedFrames == ScribeRealtimeClient.maximumQueuedFrames)
        #expect(await transport.sentCount() == ScribeRealtimeClient.maximumQueuedFrames + 1)
        await client.stopRealtime()
    }

    @Test
    func stopWaitsForItsExplicitCommitInsteadOfPriorTimestampEnrichment() async throws {
        let transport = InterleavedCommitTransport()
        let client = ScribeRealtimeClient(transport: transport)
        try await client.startRealtime(apiKey: "verification-key", configuration: .init())
        try await client.send(AudioFrame(
            source: .mixed,
            startMilliseconds: 0,
            sampleCount: 4_000,
            pcmData: Data(count: 8_000)
        ))
        try await client.commit()

        let stopTask = Task { await client.stopRealtime() }
        try await transport.waitUntilPriorCommitPairHandled()
        try await Task.sleep(for: .milliseconds(100))
        #expect(await client.diagnostics().state == .stopping)
        #expect(await transport.closed() == false)
        await transport.releaseFinalCommit()
        await stopTask.value
        #expect(await client.diagnostics().state == .finished)
    }

    @Test
    func stopReplaysAndRecommitsAfterTransientDisconnect() async throws {
        let transport = ReconnectDuringStopTransport()
        let client = ScribeRealtimeClient(transport: transport)
        try await client.startRealtime(apiKey: "verification-key", configuration: .init())
        try await client.send(AudioFrame(
            source: .mixed,
            startMilliseconds: 0,
            sampleCount: 4_000,
            pcmData: Data(count: 8_000)
        ))

        await client.stopRealtime()
        let counts = await transport.counts()
        #expect(counts.connections >= 2)
        #expect(counts.commits >= 2)
        #expect(await client.diagnostics().state == .finished)
    }
}
