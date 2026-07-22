import Foundation

public struct ScribeRealtimeWord: Equatable, Sendable {
    public var text: String
    public var startSeconds: Double
    public var endSeconds: Double

    public init(text: String, startSeconds: Double, endSeconds: Double) {
        self.text = text
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }
}

public enum ScribeRealtimeEvent: Equatable, Sendable {
    case sessionStarted(id: String?)
    case partial(text: String)
    case committed(text: String)
    case committedWithTimestamps(text: String, words: [ScribeRealtimeWord])
    case error(TranscriptionFailure)
    case unknown(type: String)

    public static func decode(_ data: Data) throws -> ScribeRealtimeEvent {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranscriptionFailure(kind: .invalidInput, message: "Scribe returned invalid JSON.")
        }
        let type = (object["message_type"] ?? object["type"]) as? String ?? "unknown"
        switch type {
        case "session_started":
            return .sessionStarted(id: object["session_id"] as? String)
        case "partial_transcript":
            return .partial(text: object["text"] as? String ?? "")
        case "committed_transcript":
            return .committed(text: object["text"] as? String ?? "")
        case "committed_transcript_with_timestamps":
            let words: [ScribeRealtimeWord] = (object["words"] as? [[String: Any]] ?? []).compactMap { word in
                guard let text = word["text"] as? String,
                      let start = number(word["start"]),
                      let end = number(word["end"]) else { return nil }
                return ScribeRealtimeWord(text: text, startSeconds: start, endSeconds: end)
            }
            return .committedWithTimestamps(text: object["text"] as? String ?? "", words: words)
        case _ where type.contains("error"):
            let code = (object["error_type"] ?? object["code"]) as? String ?? type
            let message = (object["message"] ?? object["error"]) as? String ?? "Scribe realtime failed."
            return .error(classify(code: code, message: message))
        default:
            return .unknown(type: type)
        }
    }

    public static func classify(code: String, message: String) -> TranscriptionFailure {
        let value = "\(code) \(message)".lowercased()
        let kind: TranscriptionFailureKind
        if value.contains("auth") || value.contains("api key") || value.contains("unauthorized") {
            kind = .authentication
        } else if value.contains("quota") || value.contains("credit") {
            kind = .quota
        } else if value.contains("term") {
            kind = .terms
        } else if value.contains("rate") || value.contains("thrott") {
            kind = .rateLimited
        } else if value.contains("input") || value.contains("chunk") || value.contains("format") {
            kind = .invalidInput
        } else if value.contains("queue") || value.contains("resource") || value.contains("session") {
            kind = .transient
        } else {
            kind = .unknown
        }
        return TranscriptionFailure(kind: kind, message: message)
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
