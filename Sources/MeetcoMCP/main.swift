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

StdioMCPServer(snapshotURL: snapshotURL).run()
