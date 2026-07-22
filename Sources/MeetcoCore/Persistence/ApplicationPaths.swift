import Foundation

public struct ApplicationPaths: Equatable, Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

    public static func live(fileManager: FileManager = .default) throws -> ApplicationPaths {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return ApplicationPaths(root: support.appendingPathComponent("Meetco", isDirectory: true))
    }

    public static func testing(root: URL) -> ApplicationPaths {
        ApplicationPaths(root: root.appendingPathComponent("MeetcoTests", isDirectory: true))
    }

    public var meetingsRoot: URL {
        root.appendingPathComponent("Meetings", isDirectory: true)
    }

    public var liveSnapshotURL: URL {
        root.appendingPathComponent("Live", isDirectory: true)
            .appendingPathComponent("current-meeting.json", isDirectory: false)
    }

    public func meetingDirectory(id: UUID) -> URL {
        meetingsRoot.appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }

    public func audioDirectory(id: UUID) -> URL {
        meetingDirectory(id: id).appendingPathComponent("audio", isDirectory: true)
    }

    public func prepare(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: meetingsRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: liveSnapshotURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
