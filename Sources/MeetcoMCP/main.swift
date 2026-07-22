import Foundation
import MeetcoCore

let arguments = CommandLine.arguments
let explicitIndex = arguments.firstIndex(of: "--snapshot")
let explicitPath = explicitIndex.flatMap { index in
    arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
}
let snapshotURL: URL
if let explicitPath {
    snapshotURL = URL(fileURLWithPath: explicitPath)
} else if let environmentPath = ProcessInfo.processInfo.environment["MEETCO_SNAPSHOT_PATH"] {
    snapshotURL = URL(fileURLWithPath: environmentPath)
} else {
    snapshotURL = try ApplicationPaths.live().liveSnapshotURL
}

// `--http [port]` serves the Streamable HTTP endpoint instead of stdio.
if let httpIndex = arguments.firstIndex(of: "--http") {
    var port = MCPHTTPServer.defaultPort
    if arguments.indices.contains(httpIndex + 1), let parsed = UInt16(arguments[httpIndex + 1]) {
        port = parsed
    }
    let server = MCPHTTPServer(snapshotURL: snapshotURL, port: port)
    try server.start()
    FileHandle.standardError.write(Data("MeetcoMCP listening on \(server.endpointURL)\n".utf8))
    dispatchMain()
} else {
    StdioMCPServer(snapshotURL: snapshotURL).run()
}
