import Foundation

public struct AgentUsage: Equatable, Sendable {
    public var inputTokens: Int?
    public var outputTokens: Int?

    public init(inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public enum AgentEvent: Equatable, Sendable {
    case status(String)
    case textDelta(String)
    case usage(AgentUsage)
    case warning(String)
    case completed(String)
}

public enum AgentProviderError: Error, LocalizedError, Equatable, Sendable {
    case unavailable(String)
    case authentication(String)
    case invalidResponse(String)
    case timedOut
    case cancelled
    case processFailed(code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message), .authentication(let message), .invalidResponse(let message):
            message
        case .timedOut:
            "The agent took too long to respond."
        case .cancelled:
            "The agent request was cancelled."
        case .processFailed(_, let message):
            message
        }
    }
}
