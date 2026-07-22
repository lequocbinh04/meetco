import Foundation
import Testing
@testable import MeetcoCore

@Suite("Meetco MCP router")
struct MCPToolRouterTests {
    @Test
    func exposesOnlyEnabledReadOnlyMeetingData() throws {
        var configuration = MeetingConfiguration()
        configuration.mcpEnabled = true
        let meeting = Meeting(title: "MCP", configuration: configuration)
        let segment = TranscriptSegment(
            meetingID: meeting.id,
            startMilliseconds: 0,
            endMilliseconds: 1_000,
            text: "The launch decision is Friday."
        )
        let snapshot = MeetingContextSnapshot(
            meeting: meeting,
            transcript: [segment],
            artifacts: MeetingArtifacts(summary: "Launch summary")
        )
        let router = try MCPToolRouter(snapshot: snapshot)
        let tools = try JSONEncoder().encode(router.toolsList())
        let toolsText = String(decoding: tools, as: UTF8.self)
        #expect(toolsText.contains("meeting.get_snapshot"))
        #expect(!toolsText.contains("write"))

        let result = try router.call(
            name: "meeting.search_transcript",
            arguments: .object(["query": .string("launch")])
        )
        let resultText = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        #expect(resultText.contains(segment.id.uuidString))

        let resources = try JSONEncoder().encode(router.resourcesList())
        let resourcesText = String(decoding: resources, as: UTF8.self)
        #expect(resourcesText.contains("meetco:"))
    }

    @Test
    func exporterRejectsAStaleMeetingAfterActivationChanges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoSnapshotExporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current-meeting.json")
        var configuration = MeetingConfiguration()
        configuration.mcpEnabled = true
        let oldSnapshot = MeetingContextSnapshot(
            meeting: Meeting(title: "Old", configuration: configuration)
        )
        let newSnapshot = MeetingContextSnapshot(
            meeting: Meeting(title: "New", configuration: configuration)
        )
        let exporter = SnapshotExporter(url: url)
        try await exporter.activate(meetingID: oldSnapshot.meeting.id)
        try await exporter.export(oldSnapshot)
        try await exporter.activate(meetingID: newSnapshot.meeting.id)
        try await exporter.export(oldSnapshot)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try await exporter.export(newSnapshot)
        try await exporter.disable(meetingID: oldSnapshot.meeting.id)
        #expect(try SnapshotExporter.load(from: url).meeting.id == newSnapshot.meeting.id)
    }

    @Test
    func exporterRestoresTheCurrentSnapshotAcrossAppLaunches() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetcoSnapshotRestoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current-meeting.json")
        var configuration = MeetingConfiguration()
        configuration.mcpEnabled = true
        var meeting = Meeting(title: "Restored", configuration: configuration)
        meeting.status = .completed
        let initial = MeetingContextSnapshot(meeting: meeting, manualNotes: "Before edit")
        let firstLaunch = SnapshotExporter(url: url)
        try await firstLaunch.activate(meetingID: meeting.id)
        try await firstLaunch.export(initial)

        let nextLaunch = SnapshotExporter(url: url)
        #expect(try await nextLaunch.restoreExistingSnapshot() == meeting.id)
        #expect(await nextLaunch.isActive(meetingID: meeting.id))
        var edited = initial
        edited.manualNotes = "After edit"
        try await nextLaunch.export(edited)
        #expect(try SnapshotExporter.load(from: url).manualNotes == "After edit")
        try await nextLaunch.disable(meetingID: meeting.id)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
