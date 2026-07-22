import Foundation

public actor SnapshotExporter {
    private let url: URL
    private var activeMeetingID: UUID?

    public init(url: URL) {
        self.url = url
    }

    public func activate(meetingID: UUID) throws {
        guard activeMeetingID != meetingID else { return }
        activeMeetingID = meetingID
        try removeSnapshot()
    }

    @discardableResult
    public func restoreExistingSnapshot() throws -> UUID? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            activeMeetingID = nil
            return nil
        }
        let snapshot = try Self.load(from: url)
        guard snapshot.mcpEnabled else {
            try disable()
            return nil
        }
        activeMeetingID = snapshot.meeting.id
        return snapshot.meeting.id
    }

    public func isActive(meetingID: UUID) -> Bool {
        activeMeetingID == meetingID
    }

    public func export(_ snapshot: MeetingContextSnapshot) throws {
        guard snapshot.mcpEnabled else {
            try disable()
            return
        }
        guard snapshot.meeting.id == activeMeetingID else { return }
        try AtomicFileWriter.write(snapshot, to: url)
    }

    public func disable() throws {
        activeMeetingID = nil
        try removeSnapshot()
    }

    public func disable(meetingID expectedMeetingID: UUID) throws {
        if let activeMeetingID {
            guard activeMeetingID == expectedMeetingID else { return }
            self.activeMeetingID = nil
            try removeSnapshot()
            return
        }
        guard FileManager.default.fileExists(atPath: url.path),
              try Self.load(from: url).meeting.id == expectedMeetingID else { return }
        try removeSnapshot()
    }

    private func removeSnapshot() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public static func load(from url: URL) throws -> MeetingContextSnapshot {
        try AtomicFileWriter.read(MeetingContextSnapshot.self, from: url)
    }
}
