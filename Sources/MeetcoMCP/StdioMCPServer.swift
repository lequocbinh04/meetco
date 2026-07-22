import Foundation
import MeetcoCore

public struct StdioMCPServer {
    public let snapshotURL: URL

    public init(snapshotURL: URL) {
        self.snapshotURL = snapshotURL
    }

    public func run() {
        while let line = readLine() {
            guard let output = handle(line: line) else { continue }
            FileHandle.standardOutput.write(output)
            FileHandle.standardOutput.write(Data([0x0A]))
        }
    }

    public func handle(line: String) -> Data? {
        let request: MCPRequest
        do {
            request = try JSONDecoder().decode(MCPRequest.self, from: Data(line.utf8))
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
        (try? JSONEncoder.sorted.encode(response)) ?? Data()
    }
}

private struct MethodNotFound: Error {
    let method: String
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
