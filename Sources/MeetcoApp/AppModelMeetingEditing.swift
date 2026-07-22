import Foundation
import MeetcoCore

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension AppModel {
    func saveSelectedNotes(_ notes: String) {
        guard let dependencies, var detail = selectedMeeting else { return }
        detail.notes = notes
        selectedMeeting = detail
        selectedNotesSaveTask?.cancel()
        selectedNotesSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                try await dependencies.repository.saveNotes(notes, id: detail.meeting.id)
                try await self?.refreshMCPSnapshotIfActive(meetingID: detail.meeting.id)
            } catch is CancellationError {
                return
            } catch {
                self?.startupError = error.localizedDescription
            }
        }
    }

    func toggleSelectedAction(_ id: UUID) {
        guard let dependencies, var detail = selectedMeeting,
              let index = detail.artifacts.actionItems.firstIndex(where: { $0.id == id }) else { return }
        detail.artifacts.actionItems[index].status = detail.artifacts.actionItems[index].status == .completed
            ? .accepted
            : .completed
        selectedMeeting = detail
        selectedArtifactsSaveTask?.cancel()
        selectedArtifactsSaveTask = Task { [weak self] in
            do {
                try Task.checkCancellation()
                try await dependencies.repository.saveArtifacts(detail.artifacts, id: detail.meeting.id)
                try await self?.refreshMCPSnapshotIfActive(meetingID: detail.meeting.id)
            } catch is CancellationError {
                return
            } catch {
                self?.startupError = error.localizedDescription
            }
        }
    }

    func editSelectedTranscript(_ id: UUID, text: String, speaker: String) {
        guard let dependencies, var detail = selectedMeeting,
              let index = detail.transcript.firstIndex(where: { $0.id == id }) else { return }
        detail.transcript[index].text = text
        detail.transcript[index].speakerName = speaker
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let version = detail.transcript[index].version
        selectedMeeting = detail
        selectedTranscriptSaveTask?.cancel()
        selectedTranscriptSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
                try Task.checkCancellation()
                try await dependencies.repository.saveTranscript(
                    detail.transcript,
                    id: detail.meeting.id,
                    version: version
                )
                try await self?.refreshMCPSnapshotIfActive(meetingID: detail.meeting.id)
            } catch is CancellationError {
                return
            } catch {
                self?.startupError = error.localizedDescription
            }
        }
    }

    func regenerateSelectedArtifacts() {
        guard let dependencies, let detail = selectedMeeting,
              detail.meeting.configuration.agentProvider != .none,
              selectedAgentTask == nil else { return }
        let taskID = UUID()
        isSelectedAgentResponding = true
        selectedAgentTaskID = taskID
        selectedAgentTask = Task { [weak self] in
            guard let self else { return }
            defer { finishSelectedAgentTask(taskID) }
            do {
                _ = try await dependencies.agents.generateArtifacts(
                    snapshot: detail.contextSnapshot,
                    provider: detail.meeting.configuration.agentProvider
                )
                guard isCurrentSelectedAgentTask(taskID, meetingID: detail.meeting.id) else { return }
                await loadMeeting(detail.meeting.id)
                try await refreshMCPSnapshotIfActive(meetingID: detail.meeting.id)
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentSelectedAgentTask(taskID, meetingID: detail.meeting.id) else { return }
                startupError = error.localizedDescription
            }
        }
    }

    func sendSelectedChat(_ message: String) {
        guard let dependencies, let detail = selectedMeeting,
              detail.meeting.configuration.agentProvider != .none,
              selectedAgentTask == nil else { return }
        let taskID = UUID()
        isSelectedAgentResponding = true
        selectedAgentTaskID = taskID
        selectedAgentTask = Task { [weak self] in
            guard let self else { return }
            defer { finishSelectedAgentTask(taskID) }
            do {
                let stream = await dependencies.agents.chat(
                    snapshot: detail.contextSnapshot,
                    message: message,
                    provider: detail.meeting.configuration.agentProvider
                )
                for try await _ in stream {
                    try Task.checkCancellation()
                }
                guard isCurrentSelectedAgentTask(taskID, meetingID: detail.meeting.id) else { return }
                await loadMeeting(detail.meeting.id)
                try await refreshMCPSnapshotIfActive(meetingID: detail.meeting.id)
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentSelectedAgentTask(taskID, meetingID: detail.meeting.id) else { return }
                await loadMeeting(detail.meeting.id)
                try? await refreshMCPSnapshotIfActive(meetingID: detail.meeting.id)
                startupError = error.localizedDescription
            }
        }
    }

    func cancelSelectedAgentTask() {
        let task = selectedAgentTask
        let meetingID = selectedMeetingID
        task?.cancel()
        selectedAgentTask = nil
        selectedAgentTaskID = nil
        isSelectedAgentResponding = false
        if let task, let meetingID {
            Task { [weak self] in
                await task.value
                try? await self?.refreshMCPSnapshotIfActive(meetingID: meetingID)
            }
        }
    }

    private func isCurrentSelectedAgentTask(_ taskID: UUID, meetingID: UUID) -> Bool {
        !Task.isCancelled
            && selectedAgentTaskID == taskID
            && selectedMeetingID == meetingID
    }

    private func finishSelectedAgentTask(_ taskID: UUID) {
        guard selectedAgentTaskID == taskID else { return }
        selectedAgentTask = nil
        selectedAgentTaskID = nil
        isSelectedAgentResponding = false
    }
}
