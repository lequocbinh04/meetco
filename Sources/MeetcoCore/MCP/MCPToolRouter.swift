import Foundation

public enum MCPToolRouterError: Error, LocalizedError, Sendable {
    case disabled
    case unknownTool(String)
    case invalidArguments(String)
    case unknownResource(String)

    public var errorDescription: String? {
        switch self {
        case .disabled: "MCP access is disabled for this meeting."
        case .unknownTool(let name): "Unknown tool: \(name)."
        case .invalidArguments(let message): message
        case .unknownResource(let uri): "Unknown resource: \(uri)."
        }
    }
}

public struct MCPToolRouter: Sendable {
    public let snapshot: MeetingContextSnapshot

    public init(snapshot: MeetingContextSnapshot) throws {
        guard snapshot.mcpEnabled else { throw MCPToolRouterError.disabled }
        self.snapshot = snapshot
    }

    public func toolsList() -> JSONValue {
        .object(["tools": .array([
            tool(
                name: "meeting.get_snapshot",
                description: "Get the enabled Meetco meeting snapshot.",
                properties: [:],
                required: []
            ),
            tool(
                name: "meeting.search_transcript",
                description: "Search transcript text with optional time bounds.",
                properties: [
                    "query": .object(["type": .string("string")]),
                    "startMilliseconds": .object(["type": .string("number")]),
                    "endMilliseconds": .object(["type": .string("number")]),
                    "limit": .object(["type": .string("number")]),
                ],
                required: ["query"]
            ),
            tool(
                name: "meeting.get_segment",
                description: "Get transcript segments by UUID.",
                properties: [
                    "ids": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                    ]),
                ],
                required: ["ids"]
            ),
        ])])
    }

    public func resourcesList() -> JSONValue {
        .object(["resources": .array([
            .object([
                "uri": .string(summaryURI),
                "name": .string("Meetco meeting summary"),
                "description": .string("The current generated summary for this meeting."),
                "mimeType": .string("text/plain"),
            ]),
        ])])
    }

    public func call(name: String, arguments: JSONValue?) throws -> JSONValue {
        let result: JSONValue
        switch name {
        case "meeting.get_snapshot":
            result = try JSONValue.encode(snapshot)
        case "meeting.search_transcript":
            result = try JSONValue.encode(search(arguments))
        case "meeting.get_segment":
            result = try JSONValue.encode(segments(arguments))
        default:
            throw MCPToolRouterError.unknownTool(name)
        }
        return .object(["content": .array([
            .object([
                "type": .string("text"),
                "text": .string(try jsonString(result)),
            ]),
        ])])
    }

    public func readResource(uri: String) throws -> JSONValue {
        guard uri == summaryURI else { throw MCPToolRouterError.unknownResource(uri) }
        return .object(["contents": .array([
            .object([
                "uri": .string(uri),
                "mimeType": .string("text/plain"),
                "text": .string(snapshot.artifacts.summary),
            ]),
        ])])
    }

    private var summaryURI: String {
        "meetco://meetings/\(snapshot.meeting.id.uuidString.lowercased())/summary"
    }

    private func search(_ arguments: JSONValue?) throws -> [TranscriptSegment] {
        let object = arguments?.objectValue ?? [:]
        guard let query = object["query"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            throw MCPToolRouterError.invalidArguments("query is required.")
        }
        let start = boundedInt64(object["startMilliseconds"]?.numberValue, default: 0)
        let end = boundedInt64(object["endMilliseconds"]?.numberValue, default: .max)
        let limit = min(max(Int(object["limit"]?.numberValue ?? 20), 1), 50)
        return snapshot.transcript.filter {
            $0.endMilliseconds >= start
                && $0.startMilliseconds <= end
                && $0.text.localizedCaseInsensitiveContains(query)
        }.prefix(limit).map { $0 }
    }

    private func segments(_ arguments: JSONValue?) throws -> [TranscriptSegment] {
        let object = arguments?.objectValue ?? [:]
        guard case .array(let values) = object["ids"] else {
            throw MCPToolRouterError.invalidArguments("ids must be an array of transcript UUIDs.")
        }
        let ids = Set(values.compactMap(\.stringValue).compactMap(UUID.init(uuidString:)))
        return snapshot.transcript.filter { ids.contains($0.id) }
    }

    private func tool(
        name: String,
        description: String,
        properties: [String: JSONValue],
        required: [String]
    ) -> JSONValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object(properties),
                "required": .array(required.map(JSONValue.string)),
                "additionalProperties": .bool(false),
            ]),
        ])
    }

    private func jsonString(_ value: JSONValue) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private func boundedInt64(_ value: Double?, default fallback: Int64) -> Int64 {
        guard let value, value.isFinite else { return fallback }
        if value >= Double(Int64.max) { return .max }
        if value <= Double(Int64.min) { return .min }
        return Int64(value)
    }
}
