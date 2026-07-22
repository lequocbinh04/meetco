import Foundation
import Testing
@testable import MeetcoCore

@Suite("Meeting repository")
struct MeetingRepositoryTests {
    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test
    func createSaveAndLoadMeetingData() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try MeetingRepository(paths: .testing(root: root))
        var meeting = try await repository.createMeeting(
            title: "Architecture",
            configuration: MeetingConfiguration(captureMode: .online)
        )
        meeting.status = .recording
        meeting.updatedAt = Date(timeIntervalSince1970: 42)
        try await repository.saveMeeting(meeting)

        let segment = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 0,
            endMilliseconds: 500,
            text: "Hello",
            version: .provisional
        )
        try await repository.saveTranscript([segment], id: meeting.id, version: .provisional)
        try await repository.saveNotes("Private note", id: meeting.id)

        #expect(try await repository.loadMeeting(id: meeting.id) == meeting)
        #expect(try await repository.loadTranscript(id: meeting.id, version: .provisional) == [segment])
        #expect(try await repository.loadNotes(id: meeting.id) == "Private note")
        #expect(try await repository.listMeetings().map(\.id) == [meeting.id])
    }

    @Test
    func interruptedMeetingsBecomeRecoverableWithoutDeletingFiles() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ApplicationPaths.testing(root: root)
        let repository = try MeetingRepository(paths: paths)
        var meeting = try await repository.createMeeting(configuration: .init())
        meeting.status = .finalizing
        try await repository.saveMeeting(meeting)
        try Data(count: LocalAudioInspection.maximumHeaderOnlyCAFByteCount + 1).write(
            to: paths.audioDirectory(id: meeting.id).appendingPathComponent("microphone-01.caf")
        )

        let recovered = try await repository.recoverInterruptedMeetings(now: Date(timeIntervalSince1970: 100))

        #expect(recovered.map(\.id) == [meeting.id])
        #expect(try await repository.loadMeeting(id: meeting.id).status == .recoverable)
        #expect(try await repository.loadMeeting(id: meeting.id).hasLocalAudio)
        #expect(FileManager.default.fileExists(atPath: paths.audioDirectory(id: meeting.id).path))
    }

    @Test
    func recoveryDoesNotClaimMissingAudioIsPreserved() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ApplicationPaths.testing(root: root)
        let repository = try MeetingRepository(paths: paths)
        var meeting = try await repository.createMeeting(configuration: .init())
        meeting.status = .recording
        meeting.hasLocalAudio = true
        try await repository.saveMeeting(meeting)
        try FileManager.default.removeItem(at: paths.audioDirectory(id: meeting.id))

        _ = try await repository.recoverInterruptedMeetings()
        let recovered = try await repository.loadMeeting(id: meeting.id)
        #expect(!recovered.hasLocalAudio)
        #expect(recovered.failureMessage?.contains("no local audio files") == true)
    }

    @Test
    func launchReconcilesAudioTruthForAlreadyRecoverableMeetings() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ApplicationPaths.testing(root: root)
        let repository = try MeetingRepository(paths: paths)
        var meeting = try await repository.createMeeting(configuration: .init())
        meeting.status = .recoverable
        meeting.hasLocalAudio = true
        try await repository.saveMeeting(meeting)
        try FileManager.default.removeItem(at: paths.audioDirectory(id: meeting.id))

        let newlyRecovered = try await repository.recoverInterruptedMeetings()
        let reconciled = try await repository.loadMeeting(id: meeting.id)
        #expect(newlyRecovered.isEmpty)
        #expect(!reconciled.hasLocalAudio)
        #expect(reconciled.status == .recoverable)
    }

    @Test
    func headerOnlyAudioIsNotAdvertisedAsUsable() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mixURL = root.appendingPathComponent("final-mix.wav")
        try Data(count: LocalAudioInspection.pcmWAVHeaderByteCount).write(to: mixURL)
        #expect(!LocalAudioInspection.hasUsableAudio(in: root))
        #expect(!LocalAudioInspection.hasUsableFinalMix(at: mixURL))

        var audio = Data(count: LocalAudioInspection.pcmWAVHeaderByteCount)
        audio.append(contentsOf: [0, 0])
        try audio.write(to: mixURL)
        #expect(LocalAudioInspection.hasUsableAudio(in: root))
        #expect(LocalAudioInspection.hasUsableFinalMix(at: mixURL))
    }

    @Test
    func orphanTemporaryFileCannotReplaceLastValidMeeting() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ApplicationPaths.testing(root: root)
        let repository = try MeetingRepository(paths: paths)
        let meeting = try await repository.createMeeting(title: "Stable", configuration: .init())
        let orphan = paths.meetingDirectory(id: meeting.id).appendingPathComponent(".meeting.json.interrupted.tmp")
        try Data("not-json".utf8).write(to: orphan)

        #expect(try await repository.loadMeeting(id: meeting.id) == meeting)
    }
}
