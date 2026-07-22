import Foundation
import Network

/// Minimal MCP Streamable HTTP endpoint bound to localhost only.
/// Each `POST /mcp` carries one JSON-RPC message and receives the JSON
/// response directly (202 for notifications), which is the stateless subset
/// of the Streamable HTTP transport that Claude, Codex, and other MCP
/// clients accept. The snapshot file is re-read per request, so revoking the
/// snapshot immediately revokes the data without restarting the server.
public final class MCPHTTPServer: @unchecked Sendable {
    public static let defaultPort: UInt16 = 46321

    public let port: UInt16
    private let handler: MCPSnapshotMessageHandler
    private let queue = DispatchQueue(label: "com.meetco.mcp-http")
    private var listener: NWListener?

    public init(snapshotURL: URL, port: UInt16 = MCPHTTPServer.defaultPort) {
        self.handler = MCPSnapshotMessageHandler(snapshotURL: snapshotURL)
        self.port = port
    }

    public var endpointURL: String { "http://127.0.0.1:\(port)/mcp" }

    public func start() throws {
        guard listener == nil else { return }
        let parameters = NWParameters.tcp
        // Loopback-only: the meeting snapshot must never be reachable from the network.
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: port)!
        )
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.serve(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(connection, buffer: Data())
    }

    private func receiveRequest(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if error != nil {
                connection.cancel()
                return
            }
            if let request = HTTPRequest(parsing: buffer) {
                self.respond(to: request, on: connection)
            } else if isComplete || buffer.count > 4 << 20 {
                connection.cancel()
            } else {
                self.receiveRequest(connection, buffer: buffer)
            }
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        let response: Data
        switch (request.method, request.path) {
        case ("POST", "/mcp"):
            if let payload = handler.handle(message: String(decoding: request.body, as: UTF8.self)) {
                response = Self.httpResponse(status: "200 OK", body: payload)
            } else {
                response = Self.httpResponse(status: "202 Accepted", body: Data())
            }
        case ("GET", "/mcp"):
            // No server-initiated stream is offered; clients fall back to plain POSTs.
            response = Self.httpResponse(status: "405 Method Not Allowed", body: Data())
        case ("DELETE", "/mcp"):
            response = Self.httpResponse(status: "200 OK", body: Data())
        default:
            response = Self.httpResponse(status: "404 Not Found", body: Data())
        }
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func httpResponse(status: String, body: Data) -> Data {
        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        return Data(head.utf8) + body
    }
}

/// Just enough HTTP/1.1 parsing for single-message MCP requests.
private struct HTTPRequest {
    let method: String
    let path: String
    let body: Data

    init?(parsing data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerText = String(decoding: data[..<headerEnd.lowerBound], as: UTF8.self)
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            guard pair.count == 2,
                  pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else {
                continue
            }
            contentLength = Int(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0
        }

        let bodyStart = headerEnd.upperBound
        guard data.count - bodyStart >= contentLength else { return nil }

        self.method = String(parts[0])
        // Ignore query strings; the endpoint carries no parameters.
        self.path = String(parts[1].split(separator: "?").first ?? parts[1])
        self.body = data.subdata(in: bodyStart..<(bodyStart + contentLength))
    }
}
