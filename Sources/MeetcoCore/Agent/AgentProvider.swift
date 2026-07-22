import Foundation

public struct AgentCapabilities: Equatable, Sendable {
    public var streaming: Bool
    public var structuredOutput: Bool
    public var usesLocalCLIAuth: Bool

    public init(streaming: Bool, structuredOutput: Bool, usesLocalCLIAuth: Bool) {
        self.streaming = streaming
        self.structuredOutput = structuredOutput
        self.usesLocalCLIAuth = usesLocalCLIAuth
    }
}

public struct AgentRequest: Equatable, Sendable {
    public var systemPrompt: String
    public var userPrompt: String
    public var maximumOutputTokens: Int
    public var expectsJSON: Bool

    public init(
        systemPrompt: String,
        userPrompt: String,
        maximumOutputTokens: Int = 2_048,
        expectsJSON: Bool = false
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.maximumOutputTokens = maximumOutputTokens
        self.expectsJSON = expectsJSON
    }

    public var stdinPrompt: Data {
        Data("SYSTEM INSTRUCTIONS:\n\(systemPrompt)\n\nUSER REQUEST:\n\(userPrompt)\n".utf8)
    }
}

public protocol AgentProvider: Sendable {
    var kind: AgentProviderKind { get }
    var capabilities: AgentCapabilities { get }
    func healthCheck() async -> ProviderHealth
    func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error>
}

final class IncrementalLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) -> [Data] {
        lock.withLock {
            storage.append(data)
            var lines: [Data] = []
            while let newline = storage.firstIndex(of: 0x0A) {
                lines.append(Data(storage[..<newline]))
                storage.removeSubrange(...newline)
            }
            return lines
        }
    }

    func finish() -> Data? {
        lock.withLock {
            guard !storage.isEmpty else { return nil }
            defer { storage.removeAll() }
            return storage
        }
    }
}

final class AgentTextAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""

    var text: String { lock.withLock { storage } }
    var isEmpty: Bool { lock.withLock { storage.isEmpty } }

    func append(_ value: String) {
        lock.withLock { storage += value }
    }
}
