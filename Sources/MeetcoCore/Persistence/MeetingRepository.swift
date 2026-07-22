import Foundation

public enum MeetingRepositoryError: Error, LocalizedError, Sendable {
    case meetingNotFound(UUID)
    case invalidMeetingPath

    public var errorDescription: String? {
        switch self {
        case .meetingNotFound:
            "Meeting could not be found."
        case .invalidMeetingPath:
            "The meeting path is outside Meetco storage."
        }
    }
}

public actor MeetingRepository {
    private enum FileName {
        static let meeting = "meeting.json"
        static let transcript = "transcript.json"
        static let provisionalTranscript = "transcript-provisional.json"
        static let artifacts = "artifacts.json"
        static let chat = "chat.json"
        static let notes = "notes.txt"
    }

    public let paths: ApplicationPaths

    public init(paths: ApplicationPaths) throws {
        self.paths = paths
        try paths.prepare()
    }

    @discardableResult
    public func createMeeting(
        title: String = "Untitled meeting",
        configuration: MeetingConfiguration,
        now: Date = Date()
    ) throws -> Meeting {
        let meeting = Meeting(title: title, now: now, configuration: configuration)
        let directory = paths.meetingDirectory(id: meeting.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: paths.audioDirectory(id: meeting.id),
            withIntermediateDirectories: true
        )
        try AtomicFileWriter.write(meeting, to: fileURL(for: meeting.id, name: FileName.meeting))
        try AtomicFileWriter.write([TranscriptSegment](), to: fileURL(for: meeting.id, name: FileName.transcript))
        try AtomicFileWriter.write([TranscriptSegment](), to: fileURL(for: meeting.id, name: FileName.provisionalTranscript))
        try AtomicFileWriter.write(MeetingArtifacts(), to: fileURL(for: meeting.id, name: FileName.artifacts))
        try AtomicFileWriter.write([ChatMessage](), to: fileURL(for: meeting.id, name: FileName.chat))
        try AtomicFileWriter.write(Data(), to: fileURL(for: meeting.id, name: FileName.notes))
        return meeting
    }

    public func listMeetings() throws -> [Meeting] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: paths.meetingsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return urls.compactMap { directory in
            let url = directory.appendingPathComponent(FileName.meeting)
            return try? AtomicFileWriter.read(Meeting.self, from: url)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func loadMeeting(id: UUID) throws -> Meeting {
        let url = fileURL(for: id, name: FileName.meeting)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MeetingRepositoryError.meetingNotFound(id)
        }
        return try AtomicFileWriter.read(Meeting.self, from: url)
    }

    public func saveMeeting(_ meeting: Meeting) throws {
        try assertStored(meeting.id)
        try AtomicFileWriter.write(meeting, to: fileURL(for: meeting.id, name: FileName.meeting))
    }

    public func loadTranscript(id: UUID, version: TranscriptVersion = .final) throws -> [TranscriptSegment] {
        let name = version == .final ? FileName.transcript : FileName.provisionalTranscript
        return try AtomicFileWriter.read([TranscriptSegment].self, from: fileURL(for: id, name: name))
    }

    public func saveTranscript(_ segments: [TranscriptSegment], id: UUID, version: TranscriptVersion) throws {
        try assertStored(id)
        let name = version == .final ? FileName.transcript : FileName.provisionalTranscript
        try AtomicFileWriter.write(segments, to: fileURL(for: id, name: name))
    }

    public func loadArtifacts(id: UUID) throws -> MeetingArtifacts {
        try AtomicFileWriter.read(MeetingArtifacts.self, from: fileURL(for: id, name: FileName.artifacts))
    }

    public func saveArtifacts(_ artifacts: MeetingArtifacts, id: UUID) throws {
        try assertStored(id)
        try AtomicFileWriter.write(artifacts, to: fileURL(for: id, name: FileName.artifacts))
    }

    public func loadChat(id: UUID) throws -> [ChatMessage] {
        try AtomicFileWriter.read([ChatMessage].self, from: fileURL(for: id, name: FileName.chat))
    }

    public func saveChat(_ messages: [ChatMessage], id: UUID) throws {
        try assertStored(id)
        try AtomicFileWriter.write(messages, to: fileURL(for: id, name: FileName.chat))
    }

    @discardableResult
    public func appendChat(_ message: ChatMessage, id: UUID) throws -> [ChatMessage] {
        try assertStored(id)
        var messages = try loadChat(id: id)
        messages.append(message)
        try AtomicFileWriter.write(messages, to: fileURL(for: id, name: FileName.chat))
        return messages
    }

    @discardableResult
    public func appendChatTurn(
        user: ChatMessage,
        assistant: ChatMessage,
        id: UUID
    ) throws -> [ChatMessage] {
        try assertStored(id)
        guard user.meetingID == id,
              assistant.meetingID == id,
              user.role == .user,
              assistant.role == .assistant else {
            throw MeetingRepositoryError.invalidMeetingPath
        }
        var messages = try loadChat(id: id)
        messages.append(contentsOf: [user, assistant])
        try AtomicFileWriter.write(messages, to: fileURL(for: id, name: FileName.chat))
        return messages
    }

    @discardableResult
    public func updateChatMessage(_ message: ChatMessage, id: UUID) throws -> [ChatMessage] {
        try assertStored(id)
        guard message.meetingID == id else { throw MeetingRepositoryError.invalidMeetingPath }
        var messages = try loadChat(id: id)
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
            throw MeetingRepositoryError.meetingNotFound(id)
        }
        messages[index] = message
        try AtomicFileWriter.write(messages, to: fileURL(for: id, name: FileName.chat))
        return messages
    }

    public func loadNotes(id: UUID) throws -> String {
        let data = try Data(contentsOf: fileURL(for: id, name: FileName.notes))
        return String(decoding: data, as: UTF8.self)
    }

    public func saveNotes(_ notes: String, id: UUID) throws {
        try assertStored(id)
        try AtomicFileWriter.write(Data(notes.utf8), to: fileURL(for: id, name: FileName.notes))
    }

    public func recoverInterruptedMeetings(now: Date = Date()) throws -> [Meeting] {
        let interrupted: Set<MeetingStatus> = [.recording, .paused, .finalizing]
        var recovered: [Meeting] = []
        for var meeting in try listMeetings() {
            let hasLocalAudio = hasLocalAudioFiles(meetingID: meeting.id)
            if meeting.status == .recoverable {
                guard meeting.hasLocalAudio != hasLocalAudio else { continue }
                meeting.hasLocalAudio = hasLocalAudio
                meeting.updatedAt = now
                try saveMeeting(meeting)
                continue
            }
            guard interrupted.contains(meeting.status) else { continue }
            meeting.hasLocalAudio = hasLocalAudio
            meeting.status = .recoverable
            meeting.updatedAt = now
            meeting.failureMessage = meeting.hasLocalAudio
                ? "Meetco closed before this meeting finished. Local audio files are preserved."
                : "Meetco closed before this meeting finished, and no local audio files were found."
            try saveMeeting(meeting)
            recovered.append(meeting)
        }
        return recovered
    }

    public func deleteMeeting(id: UUID) throws {
        try assertStored(id)
        try FileManager.default.removeItem(at: paths.meetingDirectory(id: id))
    }

    private func fileURL(for id: UUID, name: String) -> URL {
        paths.meetingDirectory(id: id).appendingPathComponent(name, isDirectory: false)
    }

    private func assertStored(_ id: UUID) throws {
        let directory = paths.meetingDirectory(id: id).standardizedFileURL
        guard directory.path.hasPrefix(paths.meetingsRoot.standardizedFileURL.path),
              FileManager.default.fileExists(atPath: directory.path) else {
            throw MeetingRepositoryError.invalidMeetingPath
        }
    }

    private func hasLocalAudioFiles(meetingID: UUID) -> Bool {
        LocalAudioInspection.hasUsableAudio(in: paths.audioDirectory(id: meetingID))
    }
}
