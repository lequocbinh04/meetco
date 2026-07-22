import Foundation
import MeetcoCore

extension AppModel {
    func reconcileMCPSnapshotAfterBootstrap() async {
        guard let dependencies else { return }
        do {
            guard let meetingID = try await dependencies.snapshotExporter.restoreExistingSnapshot() else {
                return
            }
            let meeting = try await dependencies.repository.loadMeeting(id: meetingID)
            guard meeting.configuration.mcpEnabled, meeting.status == .completed else {
                try await dependencies.snapshotExporter.disable(meetingID: meetingID)
                return
            }
            try await refreshMCPSnapshotIfActive(meetingID: meetingID)
        } catch {
            try? await dependencies.snapshotExporter.disable()
            mcpDiagnosticHealth = ProviderHealth(
                state: .unavailable,
                detail: "A stale MCP snapshot was removed: \(error.localizedDescription)"
            )
        }
    }

    func refreshMCPSnapshotIfActive(meetingID: UUID) async throws {
        guard let dependencies,
              await dependencies.snapshotExporter.isActive(meetingID: meetingID) else { return }
        let snapshot = try await repositorySnapshot(meetingID: meetingID)
        try await dependencies.snapshotExporter.export(snapshot)
    }

    func repositorySnapshot(meetingID: UUID) async throws -> MeetingContextSnapshot {
        guard let dependencies else {
            throw AgentProviderError.unavailable("Meetco storage is unavailable.")
        }
        let meeting = try await dependencies.repository.loadMeeting(id: meetingID)
        let final = try await dependencies.repository.loadTranscript(id: meetingID, version: .final)
        let transcript = final.isEmpty
            ? try await dependencies.repository.loadTranscript(id: meetingID, version: .provisional)
            : final
        return MeetingContextSnapshot(
            meeting: meeting,
            transcript: transcript,
            artifacts: try await dependencies.repository.loadArtifacts(id: meetingID),
            chat: try await dependencies.repository.loadChat(id: meetingID),
            manualNotes: try await dependencies.repository.loadNotes(id: meetingID)
        )
    }
}
