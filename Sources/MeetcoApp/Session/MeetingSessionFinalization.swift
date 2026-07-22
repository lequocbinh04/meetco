import Foundation
import MeetcoCore

extension MeetingSessionCoordinator {
    func stop() {
        Task { await stopAndFinalize() }
    }

    func savePrivateNotes(_ notes: String) {
        viewState.privateNotes = notes
        notesSaveTask?.cancel()
        guard let meetingID = viewState.meeting?.id else { return }
        notesSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            try? await dependencies.repository.saveNotes(notes, id: meetingID)
            if let meeting = viewState.meeting, meeting.configuration.mcpEnabled {
                await publishSnapshot(for: meeting)
            }
        }
    }

    func preserveFailedCapture(_ message: String) async {
        guard var meeting = viewState.meeting,
              viewState.phase == .recording || viewState.phase == .paused else { return }
        viewState.phase = .stopping
        viewState.localRecordingMessage = "Closing a partial local recording…"
        await cancelChatTaskAndWait()
        timerTask?.cancel()
        notesSaveTask?.cancel()
        try? await dependencies.repository.saveNotes(viewState.privateNotes, id: meeting.id)

        do {
            let result = try await dependencies.capture.stop()
            await sendTrailingRealtimeFrames(result.trailingRealtimeFrames)
            await stopRealtimeIfNeeded()
            meeting.durationMilliseconds = result.durationMilliseconds
            meeting.endedAt = Date()
            meeting.updatedAt = Date()
            meeting.status = .recoverable
            meeting.hasLocalAudio = LocalAudioInspection.hasUsableAudio(
                in: dependencies.paths.audioDirectory(id: meeting.id)
            )
            meeting.failureMessage = meeting.hasLocalAudio
                ? "Capture stopped early: \(message)"
                : "Capture stopped before usable audio was written: \(message)"
            try await dependencies.repository.saveMeeting(meeting)
            if meeting.configuration.mcpEnabled {
                try? await dependencies.snapshotExporter.disable(meetingID: meeting.id)
            }
            viewState.meeting = meeting
            viewState.elapsedMilliseconds = result.durationMilliseconds
            viewState.localRecordingMessage = "Partial local recording saved"
            viewState.warning = meeting.failureMessage
            viewState.phase = .failed(meeting.failureMessage ?? message)
        } catch {
            await stopRealtimeIfNeeded()
            meeting.hasLocalAudio = LocalAudioInspection.hasUsableAudio(
                in: dependencies.paths.audioDirectory(id: meeting.id)
            )
            meeting.status = .recoverable
            meeting.updatedAt = Date()
            meeting.failureMessage = "Capture stopped early and needs file recovery: \(error.localizedDescription)"
            try? await dependencies.repository.saveMeeting(meeting)
            if meeting.configuration.mcpEnabled {
                try? await dependencies.snapshotExporter.disable(meetingID: meeting.id)
            }
            viewState.meeting = meeting
            viewState.warning = meeting.failureMessage
            viewState.phase = .failed(meeting.failureMessage ?? message)
        }
        cancelObservationTasks()
    }

    func sendChat(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let meeting = viewState.meeting,
              meeting.configuration.agentProvider != .none,
              chatTask == nil else { return }
        let taskID = UUID()
        chatTaskID = taskID
        chatTask = Task { [weak self] in
            guard let self else { return }
            defer { finishChatTask(taskID) }
            do {
                guard isCurrentChatTask(taskID, meetingID: meeting.id) else { return }
                var liveTranscript = viewState.transcript
                if let partial = viewState.partialTranscript { liveTranscript.append(partial) }
                let snapshot = try await contextSnapshot(for: meeting, transcript: liveTranscript)
                guard isCurrentChatTask(taskID, meetingID: meeting.id) else { return }
                let userID = UUID()
                let user = ChatMessage(
                    id: userID,
                    meetingID: meeting.id,
                    role: .user,
                    content: trimmed,
                    provider: meeting.configuration.agentProvider
                )
                let assistantID = UUID()
                var assistant = ChatMessage(
                    id: assistantID,
                    meetingID: meeting.id,
                    role: .assistant,
                    content: "",
                    provider: meeting.configuration.agentProvider,
                    status: .sending
                )
                chatCancellationAssistantID = assistantID
                viewState.chat.append(contentsOf: [user, assistant])
                viewState.providerMessage = "Copilot is thinking…"
                let stream = await dependencies.agents.chat(
                    snapshot: snapshot,
                    message: trimmed,
                    provider: meeting.configuration.agentProvider,
                    userMessageID: userID,
                    assistantMessageID: assistantID
                )
                for try await event in stream {
                    try Task.checkCancellation()
                    guard isCurrentChatTask(taskID, meetingID: meeting.id) else { return }
                    if case .textDelta(let text) = event {
                        assistant.content += text
                        if let index = viewState.chat.firstIndex(where: { $0.id == assistantID }) {
                            viewState.chat[index] = assistant
                        }
                    }
                }
                let persistedChat = try await dependencies.repository.loadChat(id: meeting.id)
                guard isCurrentChatTask(taskID, meetingID: meeting.id) else { return }
                viewState.chat = persistedChat
                viewState.providerMessage = providerReadyLabel(meeting.configuration.agentProvider)
                if meeting.configuration.mcpEnabled {
                    await publishSnapshot(for: meeting, chatTaskID: taskID)
                }
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentChatTask(taskID, meetingID: meeting.id) else { return }
                viewState.providerMessage = "Copilot needs attention"
                viewState.warning = error.localizedDescription
                viewState.chat = (try? await dependencies.repository.loadChat(id: meeting.id))
                    ?? viewState.chat
                if meeting.configuration.mcpEnabled {
                    await publishSnapshot(for: meeting, chatTaskID: taskID)
                }
            }
        }
    }

    private func stopAndFinalize() async {
        guard var meeting = viewState.meeting,
              viewState.phase == .recording || viewState.phase == .paused else { return }
        viewState.phase = .stopping
        viewState.localRecordingMessage = "Closing local recording first…"
        await cancelChatTaskAndWait()
        timerTask?.cancel()
        notesSaveTask?.cancel()
        try? await dependencies.repository.saveNotes(
            viewState.privateNotes,
            id: meeting.id
        )
        do {
            let result = try await dependencies.capture.stop()
            let captureEventsDrained = await waitForCaptureEventsToDrain()
            if !captureEventsDrained {
                viewState.warning = "Local audio is safe. Live transcript delivery timed out while stopping."
            }
            await sendTrailingRealtimeFrames(result.trailingRealtimeFrames)
            await stopRealtimeIfNeeded()
            meeting.durationMilliseconds = result.durationMilliseconds
            meeting.endedAt = Date()
            meeting.updatedAt = Date()
            meeting.status = .finalizing
            meeting.hasLocalAudio = LocalAudioInspection.hasUsableAudio(
                in: dependencies.paths.audioDirectory(id: meeting.id)
            )
            try await dependencies.repository.saveMeeting(meeting)
            viewState.meeting = meeting
            viewState.elapsedMilliseconds = result.durationMilliseconds
            viewState.phase = .finalizing(.closingRecording)
            viewState.localRecordingMessage = "Local recording saved"
            await finalize(meeting: &meeting, mixURL: result.mixURL)
        } catch {
            await stopRealtimeIfNeeded()
            meeting.hasLocalAudio = LocalAudioInspection.hasUsableAudio(
                in: dependencies.paths.audioDirectory(id: meeting.id)
            )
            meeting.status = .recoverable
            meeting.failureMessage = error.localizedDescription
            meeting.updatedAt = Date()
            try? await dependencies.repository.saveMeeting(meeting)
            if meeting.configuration.mcpEnabled {
                try? await dependencies.snapshotExporter.disable(meetingID: meeting.id)
            }
            viewState.meeting = meeting
            viewState.phase = .failed(error.localizedDescription)
            viewState.warning = "Local recording needs recovery. \(error.localizedDescription)"
        }
    }

    private func stopRealtimeIfNeeded() async {
        guard realtimeEnabled else { return }
        realtimeEnabled = false
        await dependencies.realtime.stopRealtime()
    }

    private func sendTrailingRealtimeFrames(_ frames: [AudioFrame]) async {
        guard realtimeEnabled else { return }
        for frame in frames {
            do {
                try await dependencies.realtime.send(frame)
            } catch {
                viewState.warning = "Local audio is safe. The final live transcript frame could not be sent."
                return
            }
        }
    }

    private func finalize(meeting: inout Meeting, mixURL: URL) async {
        var transcript = viewState.transcript
        var finalTranscriptFailure: String?
        var artifactFailure: String?
        var retentionFailure: String?
        let shouldBatch = meeting.configuration.transcriptionMode == .afterMeeting
            || (meeting.configuration.transcriptionMode == .realtime
                && meeting.configuration.polishWithBatchAfterRealtime)
        if shouldBatch, !meeting.hasLocalAudio {
            finalTranscriptFailure = "Final transcript unavailable because no usable audio was written."
            viewState.warning = finalTranscriptFailure
            viewState.transcriptionMessage = "No usable audio for transcription"
        } else if shouldBatch {
            viewState.phase = .finalizing(.finalTranscript)
            do {
                let key = try dependencies.keychain.secret(for: .elevenLabsAPIKey) ?? ""
                let batchTranscript = try await dependencies.batch.transcribe(
                    meetingID: meeting.id,
                    audioURL: mixURL,
                    apiKey: key,
                    languageCode: meeting.configuration.languageCode,
                    keyterms: meeting.configuration.keyterms
                )
                let reconciliation = TranscriptReconciler.reconcile(
                    provisional: transcript,
                    final: batchTranscript
                )
                transcript = reconciliation.final
                try await dependencies.repository.saveTranscript(
                    transcript,
                    id: meeting.id,
                    version: .final
                )
                let remapped = try await PersistedEvidenceRemapper.remap(
                    meetingID: meeting.id,
                    reconciliation: reconciliation,
                    repository: dependencies.repository
                )
                viewState.chat = remapped.chat
                viewState.transcript = transcript
                viewState.partialTranscript = nil
                viewState.transcriptionMessage = "Final transcript · ElevenLabs"
            } catch {
                finalTranscriptFailure = "Final transcript failed: \(error.localizedDescription)"
                viewState.warning = "Local recording is safe. \(finalTranscriptFailure ?? "Final transcript needs retry.")"
                viewState.transcriptionMessage = transcript.isEmpty
                    ? "Final transcript needs retry"
                    : "Provisional transcript available"
            }
        }

        if recipeEnabled(meeting.configuration.artifactRecipe),
           meeting.configuration.agentProvider != .none,
           !transcript.isEmpty {
            viewState.phase = .finalizing(.meetingNotes)
            do {
                let snapshot = try await contextSnapshot(for: meeting, transcript: transcript)
                _ = try await dependencies.agents.generateArtifacts(
                    snapshot: snapshot,
                    provider: meeting.configuration.agentProvider
                )
                viewState.providerMessage = "Meeting notes ready"
            } catch {
                artifactFailure = "Meeting notes failed: \(error.localizedDescription)"
                viewState.warning = "Recording and transcript are safe. \(artifactFailure ?? "Notes need retry.")"
                viewState.providerMessage = "Notes need retry"
            }
        }

        meeting.updatedAt = Date()
        if meeting.configuration.audioRetention == .transcriptOnly,
           !transcript.isEmpty,
           finalTranscriptFailure == nil {
            let audioDirectory = dependencies.paths.audioDirectory(id: meeting.id)
            do {
                if FileManager.default.fileExists(atPath: audioDirectory.path) {
                    try FileManager.default.removeItem(at: audioDirectory)
                }
                meeting.hasLocalAudio = false
            } catch {
                meeting.hasLocalAudio = true
                retentionFailure = "Audio cleanup failed; retained audio is still local: \(error.localizedDescription)"
            }
        }
        meeting.status = finalTranscriptFailure == nil ? .completed : .recoverable
        meeting.failureMessage = [finalTranscriptFailure, artifactFailure, retentionFailure]
            .compactMap { $0 }
            .joined(separator: " ")
        if meeting.failureMessage?.isEmpty == true { meeting.failureMessage = nil }

        do {
            try await dependencies.repository.saveMeeting(meeting)
        } catch {
            meeting.status = .recoverable
            meeting.failureMessage = "Final metadata could not be saved: \(error.localizedDescription)"
            if meeting.configuration.mcpEnabled {
                try? await dependencies.snapshotExporter.disable(meetingID: meeting.id)
            }
            viewState.meeting = meeting
            viewState.warning = meeting.failureMessage
            viewState.phase = .failed(meeting.failureMessage ?? error.localizedDescription)
            cancelObservationTasks()
            return
        }
        viewState.meeting = meeting
        viewState.phase = .finalizing(.publishingSnapshot)
        do {
            if meeting.configuration.mcpEnabled {
                let snapshot = try await contextSnapshot(for: meeting, transcript: transcript)
                try await dependencies.snapshotExporter.export(snapshot)
            } else {
                try await dependencies.snapshotExporter.disable()
            }
        } catch {
            viewState.warning = "Meeting saved, but the MCP snapshot could not be updated: \(error.localizedDescription)"
        }
        viewState.phase = .completed
        viewState.localRecordingMessage = "Saved locally"
        cancelObservationTasks()
    }

    func contextSnapshot(
        for meeting: Meeting,
        transcript suppliedTranscript: [TranscriptSegment]? = nil
    ) async throws -> MeetingContextSnapshot {
        let transcript: [TranscriptSegment]
        if let suppliedTranscript {
            transcript = suppliedTranscript
        } else {
            let final = (try? await dependencies.repository.loadTranscript(id: meeting.id, version: .final)) ?? []
            transcript = final.isEmpty
                ? ((try? await dependencies.repository.loadTranscript(id: meeting.id, version: .provisional)) ?? [])
                : final
        }
        return MeetingContextSnapshot(
            meeting: meeting,
            transcript: transcript,
            artifacts: (try? await dependencies.repository.loadArtifacts(id: meeting.id)) ?? .init(),
            chat: (try? await dependencies.repository.loadChat(id: meeting.id)) ?? [],
            manualNotes: (try? await dependencies.repository.loadNotes(id: meeting.id)) ?? ""
        )
    }

    func publishSnapshot(for meeting: Meeting, chatTaskID expectedTaskID: UUID? = nil) async {
        guard meeting.configuration.mcpEnabled,
              viewState.meeting?.id == meeting.id else { return }
        if let expectedTaskID,
           !isCurrentChatTask(expectedTaskID, meetingID: meeting.id) { return }
        let snapshot: MeetingContextSnapshot
        do {
            snapshot = try await contextSnapshot(for: meeting)
        } catch {
            viewState.warning = "MCP snapshot could not be prepared: \(error.localizedDescription)"
            return
        }
        guard viewState.meeting?.id == meeting.id else { return }
        if let expectedTaskID,
           !isCurrentChatTask(expectedTaskID, meetingID: meeting.id) { return }
        do {
            try await dependencies.snapshotExporter.export(snapshot)
        } catch {
            viewState.warning = "MCP snapshot could not be updated: \(error.localizedDescription)"
        }
    }

    private func recipeEnabled(_ recipe: ArtifactRecipe) -> Bool {
        recipe.summary || recipe.keyPoints || recipe.decisions || recipe.actionItems
            || recipe.openQuestions || recipe.risks || recipe.followUpDraft
    }

    private func providerReadyLabel(_ provider: AgentProviderKind) -> String {
        switch provider {
        case .claudeAPI: "Copilot ready · Claude API"
        case .claudeCLI: "Copilot ready · Claude CLI"
        case .codexCLI: "Copilot ready · Codex CLI"
        case .none: "Copilot off"
        }
    }
}
