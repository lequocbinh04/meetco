import Foundation

public enum TranscriptionFailureKind: String, Codable, Sendable {
    case missingKey
    case authentication
    case quota
    case terms
    case rateLimited
    case transient
    case invalidInput
    case cancelled
    case unknown
}

public struct TranscriptionFailure: Error, LocalizedError, Equatable, Sendable {
    public var kind: TranscriptionFailureKind
    public var message: String
    public var retryAfterSeconds: Double?

    public init(
        kind: TranscriptionFailureKind,
        message: String,
        retryAfterSeconds: Double? = nil
    ) {
        self.kind = kind
        self.message = message
        self.retryAfterSeconds = retryAfterSeconds
    }

    public var errorDescription: String? { message }
    public var isRetryable: Bool { kind == .transient || kind == .rateLimited }
}

public enum RealtimeTranscriptionState: Equatable, Sendable {
    case idle
    case connecting(attempt: Int)
    case connected(sessionID: String?)
    case delayed(queuedFrames: Int)
    case stopping
    case finished
    case failed(TranscriptionFailure)
}

public struct ScribeRealtimeConfiguration: Equatable, Sendable {
    public var languageCode: String?
    public var keyterms: [String]
    public var commitStrategy: String
    public var includeLanguageDetection: Bool

    public init(
        languageCode: String? = nil,
        keyterms: [String] = [],
        commitStrategy: String = "manual",
        includeLanguageDetection: Bool = true
    ) {
        self.languageCode = languageCode
        self.keyterms = ScribeKeyterms.realtime(keyterms)
        self.commitStrategy = commitStrategy
        self.includeLanguageDetection = includeLanguageDetection
    }
}

public enum ScribeRealtimeClientEvent: Equatable, Sendable {
    case state(RealtimeTranscriptionState)
    case server(ScribeRealtimeEvent)
}

public protocol TranscriptionService: Sendable {
    func events() -> AsyncStream<ScribeRealtimeClientEvent>
    func startRealtime(apiKey: String, configuration: ScribeRealtimeConfiguration) async throws
    func send(_ frame: AudioFrame) async throws
    func commit() async throws
    func stopRealtime() async
}
