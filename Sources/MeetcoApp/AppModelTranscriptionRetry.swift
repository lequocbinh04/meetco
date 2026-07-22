import Foundation
import MeetcoCore

extension AppModel {
    func retrySelectedFinalTranscript() {
        guard let dependencies,
              let detail = selectedMeeting,
              detail.meeting.hasLocalAudio,
              detail.meeting.configuration.transcriptionMode != .recordOnly,
              selectedTranscriptRetryTask == nil,
              selectedAgentTask == nil else { return }

        let meetingID = detail.meeting.id
        let taskID = UUID()
        selectedTranscriptRetryTaskID = taskID
        isSelectedTranscriptRetrying = true
        selectedTranscriptRetryTask = Task { [weak self] in
            guard let self else { return }
            defer { finishSelectedTranscriptRetry(taskID) }
            do {
                let audioURL = dependencies.paths.audioDirectory(id: meetingID)
                    .appendingPathComponent("final-mix.wav")
                guard LocalAudioInspection.hasUsableFinalMix(at: audioURL) else {
                    throw MeetingExporterRetryError.audioUnavailable
                }
                let key = try dependencies.keychain.secret(for: .elevenLabsAPIKey) ?? ""
                let finalTranscript = try await dependencies.batch.transcribe(
                    meetingID: meetingID,
                    audioURL: audioURL,
                    apiKey: key,
                    languageCode: detail.meeting.configuration.languageCode,
                    keyterms: detail.meeting.configuration.keyterms
                )
                try Task.checkCancellation()

                let provisional = try await dependencies.repository.loadTranscript(
                    id: meetingID,
                    version: .provisional
                )
                let reconciliation = TranscriptReconciler.reconcile(
                    provisional: provisional,
                    final: finalTranscript
                )
                try await dependencies.repository.saveTranscript(
                    reconciliation.final,
                    id: meetingID,
                    version: .final
                )
                _ = try await PersistedEvidenceRemapper.remap(
                    meetingID: meetingID,
                    reconciliation: reconciliation,
                    repository: dependencies.repository
                )

                var meeting = try await dependencies.repository.loadMeeting(id: meetingID)
                meeting.status = .completed
                meeting.updatedAt = Date()
                meeting.failureMessage = nil
                if meeting.configuration.audioRetention == .transcriptOnly,
                   !reconciliation.final.isEmpty {
                    let audioDirectory = dependencies.paths.audioDirectory(id: meetingID)
                    do {
                        try FileManager.default.removeItem(at: audioDirectory)
                        meeting.hasLocalAudio = false
                    } catch {
                        meeting.hasLocalAudio = true
                        meeting.failureMessage = "Final transcript was saved, but local audio cleanup failed: \(error.localizedDescription)"
                    }
                }
                try await dependencies.repository.saveMeeting(meeting)

                if hasEnabledArtifacts(meeting.configuration.artifactRecipe),
                   meeting.configuration.agentProvider != .none,
                   !reconciliation.final.isEmpty {
                    do {
                        let snapshot = try await repositorySnapshot(meetingID: meetingID)
                        _ = try await dependencies.agents.generateArtifacts(
                            snapshot: snapshot,
                            provider: meeting.configuration.agentProvider
                        )
                    } catch {
                        meeting.failureMessage = "Final transcript was saved, but meeting notes need retry: \(error.localizedDescription)"
                        try? await dependencies.repository.saveMeeting(meeting)
                    }
                }

                try await refreshMCPSnapshotIfActive(meetingID: meetingID)
                guard isCurrentSelectedTranscriptRetry(taskID, meetingID: meetingID) else { return }
                await loadMeeting(meetingID)
                await refreshMeetings()
            } catch is CancellationError {
                return
            } catch {
                await persistTranscriptRetryFailure(error, meetingID: meetingID)
                guard isCurrentSelectedTranscriptRetry(taskID, meetingID: meetingID) else { return }
                await loadMeeting(meetingID)
                startupError = error.localizedDescription
            }
        }
    }

    func cancelSelectedTranscriptRetry() {
        selectedTranscriptRetryTask?.cancel()
        selectedTranscriptRetryTask = nil
        selectedTranscriptRetryTaskID = nil
        isSelectedTranscriptRetrying = false
    }

    private func persistTranscriptRetryFailure(_ error: any Error, meetingID: UUID) async {
        guard let dependencies,
              var meeting = try? await dependencies.repository.loadMeeting(id: meetingID) else { return }
        meeting.hasLocalAudio = LocalAudioInspection.hasUsableAudio(
            in: dependencies.paths.audioDirectory(id: meetingID)
        )
        meeting.status = .recoverable
        meeting.updatedAt = Date()
        meeting.failureMessage = "Final transcript retry failed: \(error.localizedDescription)"
        try? await dependencies.repository.saveMeeting(meeting)
        try? await refreshMCPSnapshotIfActive(meetingID: meetingID)
    }

    private func isCurrentSelectedTranscriptRetry(_ taskID: UUID, meetingID: UUID) -> Bool {
        !Task.isCancelled
            && selectedTranscriptRetryTaskID == taskID
            && selectedMeetingID == meetingID
    }

    private func finishSelectedTranscriptRetry(_ taskID: UUID) {
        guard selectedTranscriptRetryTaskID == taskID else { return }
        selectedTranscriptRetryTask = nil
        selectedTranscriptRetryTaskID = nil
        isSelectedTranscriptRetrying = false
    }

    private func hasEnabledArtifacts(_ recipe: ArtifactRecipe) -> Bool {
        recipe.summary || recipe.keyPoints || recipe.decisions || recipe.actionItems
            || recipe.openQuestions || recipe.risks || recipe.followUpDraft
    }
}

private enum MeetingExporterRetryError: Error, LocalizedError {
    case audioUnavailable

    var errorDescription: String? {
        "The retained final mix is unavailable, so the transcript cannot be retried."
    }
}
