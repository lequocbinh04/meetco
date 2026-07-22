import Foundation

/// Transport-agnostic JSON-RPC handling for the read-only meeting snapshot.
/// Both the stdio helper and the in-app HTTP server delegate here so every
/// transport exposes exactly the same read-only surface.
public struct MCPSnapshotMessageHandler: Sendable {
    public let snapshotURL: URL

    public init(snapshotURL: URL) {
        self.snapshotURL = snapshotURL
    }

    /// Processes one JSON-RPC message. Returns nil for notifications,
    /// which produce no response payload.
    public func handle(message: String) -> Data? {
        let request: MCPRequest
        do {
            request = try JSONDecoder().decode(MCPRequest.self, from: Data(message.utf8))
        } catch {
            return encode(.failure(id: .null, code: -32700, message: "Parse error"))
        }
        guard request.jsonrpc == "2.0" else {
            return request.id.map { encode(.failure(id: $0, code: -32600, message: "Invalid Request")) }
        }
        guard let id = request.id else { return nil }
        do {
            let result = try dispatch(request)
            return encode(.success(id: id, result: result))
        } catch is MethodNotFound {
            return encode(.failure(id: id, code: -32601, message: "Method not found"))
        } catch let error as MCPToolRouterError {
            return encode(.failure(id: id, code: -32602, message: error.localizedDescription))
        } catch {
            return encode(.failure(id: id, code: -32000, message: "Meetco snapshot is unavailable."))
        }
    }

    private func dispatch(_ request: MCPRequest) throws -> JSONValue {
        switch request.method {
        case "initialize":
            let requested = request.params?.objectValue?["protocolVersion"]?.stringValue
            return .object([
                "protocolVersion": .string(requested ?? "2025-11-25"),
                "capabilities": .object([
                    "tools": .object(["listChanged": .bool(false)]),
                    "resources": .object(["listChanged": .bool(false)]),
                ]),
                "serverInfo": .object([
                    "name": .string("MeetcoMCP"),
                    "version": .string("0.1.0"),
                ]),
            ])
        case "ping":
            return .object([:])
        case "tools/list":
            return try router().toolsList()
        case "resources/list":
            return try router().resourcesList()
        case "tools/call":
            let object = request.params?.objectValue ?? [:]
            guard let name = object["name"]?.stringValue else {
                throw MCPToolRouterError.invalidArguments("Tool name is required.")
            }
            return try router().call(name: name, arguments: object["arguments"])
        case "resources/read":
            let object = request.params?.objectValue ?? [:]
            guard let uri = object["uri"]?.stringValue else {
                throw MCPToolRouterError.invalidArguments("Resource URI is required.")
            }
            return try router().readResource(uri: uri)
        default:
            throw MethodNotFound(method: request.method)
        }
    }

    private func router() throws -> MCPToolRouter {
        try MCPToolRouter(snapshot: SnapshotExporter.load(from: snapshotURL))
    }

    private func encode(_ response: MCPResponse) -> Data {
        (try? JSONEncoder.mcpSorted.encode(response)) ?? Data()
    }
}

private struct MethodNotFound: Error {
    let method: String
}

extension JSONEncoder {
    /// Deterministic key order keeps handshake output stable for diagnostics.
    public static var mcpSorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
