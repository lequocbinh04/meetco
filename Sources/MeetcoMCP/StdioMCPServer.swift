import Foundation
import MeetcoCore

public struct StdioMCPServer {
    public let snapshotURL: URL
    private let handler: MCPSnapshotMessageHandler

    public init(snapshotURL: URL) {
        self.snapshotURL = snapshotURL
        self.handler = MCPSnapshotMessageHandler(snapshotURL: snapshotURL)
    }

    public func run() {
        while let line = readLine() {
            guard let output = handle(line: line) else { continue }
            FileHandle.standardOutput.write(output)
            FileHandle.standardOutput.write(Data([0x0A]))
        }
    }

    public func handle(line: String) -> Data? {
        handler.handle(message: line)
    }
}
