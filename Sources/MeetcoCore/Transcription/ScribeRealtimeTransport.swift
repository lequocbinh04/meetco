import Foundation

public enum ScribeRealtimeMessage: Equatable, Sendable {
    case text(String)
    case data(Data)

    var data: Data {
        switch self {
        case .text(let text): Data(text.utf8)
        case .data(let data): data
        }
    }
}

public protocol ScribeRealtimeTransport: Sendable {
    func connect(request: URLRequest) async throws
    func send(data: Data) async throws
    func receive() async throws -> ScribeRealtimeMessage
    func close() async
}

public actor URLSessionScribeRealtimeTransport: ScribeRealtimeTransport {
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    public func connect(request: URLRequest) async throws {
        task?.cancel(with: .goingAway, reason: nil)
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
    }

    public func send(data: Data) async throws {
        guard let task else {
            throw TranscriptionFailure(kind: .transient, message: "Realtime connection is not open.")
        }
        try await task.send(.data(data))
    }

    public func receive() async throws -> ScribeRealtimeMessage {
        guard let task else {
            throw TranscriptionFailure(kind: .transient, message: "Realtime connection is not open.")
        }
        switch try await task.receive() {
        case .string(let text): return .text(text)
        case .data(let data): return .data(data)
        @unknown default:
            throw TranscriptionFailure(kind: .transient, message: "Realtime returned an unknown frame.")
        }
    }

    public func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
}
