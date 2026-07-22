import Foundation
import MeetcoCore
import Testing

private struct EndToEndFixtureProvider: AgentProvider {
    let kind = AgentProviderKind.claudeAPI
    let capabilities = AgentCapabilities(
        streaming: true,
        structuredOutput: true,
        usesLocalCLIAuth: false
    )
    let response: String

    func healthCheck() async -> ProviderHealth {
        ProviderHealth(state: .ready, detail: "Fixture ready")
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.textDelta(response))
            continuation.yield(.completed(response))
            continuation.finish()
        }
    }
}

private struct FailingEndToEndFixtureProvider: AgentProvider {
    let kind = AgentProviderKind.codexCLI
    let capabilities = AgentCapabilities(
        streaming: true,
        structuredOutput: true,
        usesLocalCLIAuth: true
    )

    func healthCheck() async -> ProviderHealth {
        ProviderHealth(state: .ready, detail: "Fixture ready")
    }

    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("Partial grounded answer"))
            continuation.finish(throwing: AgentProviderError.invalidResponse("Fixture failure"))
        }
    }
}

@Test("Repository, selected artifact recipe, and MCP share one canonical snapshot")
func canonicalSnapshotFixture() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("MeetcoE2E-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    var configuration = MeetingConfiguration()
    configuration.mcpEnabled = true
    configuration.artifactRecipe = ArtifactRecipe(
        summary: true,
        keyPoints: false,
        decisions: false,
        actionItems: false,
        openQuestions: false,
        risks: false,
        followUpDraft: false
    )
    let repository = try MeetingRepository(paths: .testing(root: root))
    let meeting = try await repository.createMeeting(
        title: "Canonical fixture",
        configuration: configuration
    )
    let segment = TranscriptSegment(
        meetingID: meeting.id,
        startMilliseconds: 0,
        endMilliseconds: 1_000,
        text: "Cris will ship on Friday.",
        version: .final
    )
    try await repository.saveTranscript([segment], id: meeting.id, version: .final)
    let response = """
    {"summary":"Friday ship","keyPoints":[],"decisions":[],"actionItems":[{"title":"Ship","owner":"Cris","dueDate":null,"evidenceSegmentIDs":["\(segment.id.uuidString)"],"confidence":0.9}],"openQuestions":[],"risks":[],"followUpDraft":null}
    """
    let service = AgentService(
        providers: [EndToEndFixtureProvider(response: response)],
        repository: repository
    )
    let snapshot = MeetingContextSnapshot(meeting: meeting, transcript: [segment])
    let artifacts = try await service.generateArtifacts(
        snapshot: snapshot,
        provider: .claudeAPI
    )
    #expect(artifacts.summary == "Friday ship")
    #expect(artifacts.actionItems.isEmpty)

    let canonical = MeetingContextSnapshot(
        meeting: meeting,
        transcript: [segment],
        artifacts: try await repository.loadArtifacts(id: meeting.id)
    )
    let router = try MCPToolRouter(snapshot: canonical)
    let result = try router.call(name: "meeting.get_snapshot", arguments: nil)
    let encoded = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
    #expect(encoded.contains("Friday ship"))
    #expect(!encoded.contains("\"title\":\"Ship\""))
}

@Test("Chat persists canonical terminal states and excludes partial transcript evidence")
func canonicalChatPersistenceFixture() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("MeetcoChatE2E-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = try MeetingRepository(paths: .testing(root: root))
    var configuration = MeetingConfiguration()
    configuration.agentProvider = .claudeAPI
    let meeting = try await repository.createMeeting(
        title: "Chat fixture",
        configuration: configuration
    )
    let committed = TranscriptSegment(
        meetingID: meeting.id,
        startMilliseconds: 0,
        endMilliseconds: 1_000,
        text: "The committed launch plan is Friday.",
        version: .provisional,
        isCommitted: true
    )
    let partial = TranscriptSegment(
        meetingID: meeting.id,
        startMilliseconds: 1_000,
        endMilliseconds: 1_500,
        text: "unfinished partial thought",
        version: .provisional,
        isCommitted: false
    )
    let snapshot = MeetingContextSnapshot(meeting: meeting, transcript: [committed, partial])
    let success = AgentService(
        providers: [EndToEndFixtureProvider(response: "Friday is the committed plan.")],
        repository: repository
    )
    let userID = UUID()
    let assistantID = UUID()
    for try await _ in await success.chat(
        snapshot: snapshot,
        message: "When is launch?",
        provider: .claudeAPI,
        userMessageID: userID,
        assistantMessageID: assistantID
    ) {}

    var messages = try await repository.loadChat(id: meeting.id)
    #expect(messages.count == 2)
    #expect(messages.map(\.id) == [userID, assistantID])
    #expect(messages[1].status == .complete)
    #expect(messages[1].evidenceSegmentIDs.contains(committed.id))
    #expect(!messages[1].evidenceSegmentIDs.contains(partial.id))

    let failure = AgentService(
        providers: [FailingEndToEndFixtureProvider()],
        repository: repository
    )
    do {
        for try await _ in await failure.chat(
            snapshot: snapshot,
            message: "What failed?",
            provider: .codexCLI
        ) {}
    } catch {}

    messages = try await repository.loadChat(id: meeting.id)
    #expect(messages.count == 4)
    #expect(messages[2].role == .user)
    #expect(messages[3].role == .assistant)
    #expect(messages[3].status == .failed)
    #expect(messages[3].content == "Partial grounded answer")
}
