import Combine
import Foundation
import MeetcoCapture
import MeetcoCore

@MainActor
final class MeetingSessionCoordinator: ObservableObject {
    @Published var viewState = MeetingSessionViewState()

    let dependencies: AppDependencies
    var assembler: RealtimeTranscriptAssembler?
    var captureEventsTask: Task<Void, Never>?
    var realtimeEventsTask: Task<Void, Never>?
    var timerTask: Task<Void, Never>?
    var notesSaveTask: Task<Void, Never>?
    var chatTask: Task<Void, Never>?
    var chatTaskID: UUID?
    var chatCancellationAssistantID: UUID?
    var realtimeEnabled = false
    var lastLevelUpdate = Date.distantPast
    var pausedAt: Date?
    var accumulatedPausedSeconds = 0.0
    var captureStreamReachedTerminalState = false
    var captureDrainContinuations: [UUID: CheckedContinuation<Bool, Never>] = [:]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func start(title: String, configuration: MeetingConfiguration) async {
        guard !viewState.isActive else { return }
        let configuration = configuration.normalizedForSession()
        cancelObservationTasks()
        captureStreamReachedTerminalState = false
        do {
            var meeting = try await dependencies.repository.createMeeting(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Untitled meeting"
                    : title,
                configuration: configuration
            )
            if configuration.mcpEnabled {
                try await dependencies.snapshotExporter.activate(meetingID: meeting.id)
            } else {
                try await dependencies.snapshotExporter.disable()
            }
            viewState = MeetingSessionViewState(
                phase: .preparing,
                meeting: meeting,
                localRecordingMessage: "Preparing local recording…",
                transcriptionMessage: transcriptionLabel(configuration.transcriptionMode),
                providerMessage: providerLabel(configuration.agentProvider)
            )
            assembler = RealtimeTranscriptAssembler(meetingID: meeting.id)
            pausedAt = nil
            accumulatedPausedSeconds = 0
            observeCaptureEvents()
            try await dependencies.capture.start(
                meetingID: meeting.id,
                mode: configuration.captureMode,
                audioDirectory: dependencies.paths.audioDirectory(id: meeting.id),
                microphoneDeviceUID: configuration.microphoneDeviceUID
            )
            meeting.status = .recording
            meeting.startedAt = Date()
            meeting.updatedAt = Date()
            meeting.hasLocalAudio = true
            try await dependencies.repository.saveMeeting(meeting)
            viewState.meeting = meeting
            viewState.phase = .recording
            viewState.localRecordingMessage = "Recording safely on this Mac"
            startTimer()
            if configuration.mcpEnabled {
                await publishSnapshot(for: meeting)
            }
            if configuration.transcriptionMode == .realtime {
                await startRealtime(configuration: configuration)
            }
        } catch {
            await failStart(error)
        }
    }

    func pauseOrResume() {
        Task {
            guard var meeting = viewState.meeting else { return }
            switch viewState.phase {
            case .recording:
                await dependencies.capture.pause()
                try? await dependencies.realtime.commit()
                pausedAt = Date()
                meeting.status = .paused
                viewState.phase = .paused
                viewState.localRecordingMessage = "Paused · local files are safe"
            case .paused:
                await dependencies.capture.resume()
                if let pausedAt { accumulatedPausedSeconds += Date().timeIntervalSince(pausedAt) }
                self.pausedAt = nil
                meeting.status = .recording
                viewState.phase = .recording
                viewState.localRecordingMessage = "Recording safely on this Mac"
            default:
                return
            }
            meeting.updatedAt = Date()
            try? await dependencies.repository.saveMeeting(meeting)
            viewState.meeting = meeting
        }
    }

    func resetCompletedSession() {
        guard !viewState.isActive else { return }
        cancelObservationTasks()
        viewState = MeetingSessionViewState()
    }

    private func startRealtime(configuration: MeetingConfiguration) async {
        realtimeEnabled = true
        do {
            let key = try dependencies.keychain.secret(for: .elevenLabsAPIKey) ?? ""
            try await dependencies.realtime.startRealtime(
                apiKey: key,
                configuration: ScribeRealtimeConfiguration(
                    languageCode: configuration.languageCode,
                    keyterms: configuration.keyterms
                )
            )
            observeRealtimeEvents()
            viewState.transcriptionMessage = "Live transcript · ElevenLabs"
        } catch {
            realtimeEnabled = false
            viewState.transcriptionMessage = "Live transcript unavailable"
            viewState.warning = "Recording will continue locally. \(error.localizedDescription)"
        }
    }

    private func observeCaptureEvents() {
        captureEventsTask?.cancel()
        captureEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in dependencies.capture.events() {
                if Task.isCancelled { return }
                await handleCaptureEvent(event)
            }
        }
    }

    private func observeRealtimeEvents() {
        realtimeEventsTask?.cancel()
        realtimeEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in dependencies.realtime.events() {
                if Task.isCancelled { return }
                await handleRealtimeEvent(event)
            }
        }
    }

    private func handleCaptureEvent(_ event: AudioCaptureEvent) async {
        switch event {
        case .level(let level):
            guard Date().timeIntervalSince(lastLevelUpdate) >= 0.05 else { return }
            lastLevelUpdate = Date()
            viewState.audioLevels[level.source] = level
        case .realtimeFrame(let frame):
            if realtimeEnabled {
                do { try await dependencies.realtime.send(frame) }
                catch { viewState.warning = "Recording locally · live transcript delayed" }
            }
        case .discontinuity(_, let milliseconds):
            viewState.warning = "Audio device changed near \(milliseconds / 1_000)s; local tracks were preserved."
        case .warning(let message):
            viewState.warning = message
        case .state(.failed(let message)):
            markCaptureEventsDrained()
            if viewState.phase == .recording || viewState.phase == .paused {
                await preserveFailedCapture(message)
            } else {
                viewState.warning = message
            }
        case .state(.finished):
            markCaptureEventsDrained()
        case .state:
            break
        }
    }

    private func handleRealtimeEvent(_ event: ScribeRealtimeClientEvent) async {
        switch event {
        case .state(.connected):
            viewState.transcriptionMessage = "Live transcript connected · ElevenLabs"
        case .state(.delayed):
            viewState.transcriptionMessage = "Live transcript delayed · recording locally"
        case .state(.failed(let failure)):
            viewState.transcriptionMessage = "Live transcript paused"
            viewState.warning = failure.message
        case .state:
            break
        case .server(let serverEvent):
            guard let assembler else { return }
            let snapshot = await assembler.apply(serverEvent)
            viewState.transcript = snapshot.committed
            viewState.partialTranscript = snapshot.partial
            if case .committed = serverEvent {
                try? await persistProvisional(snapshot.committed)
            } else if case .committedWithTimestamps = serverEvent {
                try? await persistProvisional(snapshot.committed)
            }
        }
    }

    private func persistProvisional(_ transcript: [TranscriptSegment]) async throws {
        guard let meeting = viewState.meeting else { return }
        try await dependencies.repository.saveTranscript(
            transcript,
            id: meeting.id,
            version: .provisional
        )
        if meeting.configuration.mcpEnabled { await publishSnapshot(for: meeting) }
    }

    private func startTimer() {
        timerTask?.cancel()
        notesSaveTask?.cancel()
        chatTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let startedAt = viewState.meeting?.startedAt, viewState.phase == .recording {
                    let elapsed = Date().timeIntervalSince(startedAt) - accumulatedPausedSeconds
                    viewState.elapsedMilliseconds = Int64(max(0, elapsed) * 1_000)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func cancelObservationTasks() {
        captureEventsTask?.cancel()
        realtimeEventsTask?.cancel()
        timerTask?.cancel()
        notesSaveTask?.cancel()
        cancelChatTask()
        captureEventsTask = nil
        realtimeEventsTask = nil
        timerTask = nil
        notesSaveTask = nil
        markCaptureEventsDrained()
    }

    func waitForCaptureEventsToDrain() async -> Bool {
        guard !captureStreamReachedTerminalState else { return true }
        let waiterID = UUID()
        return await withCheckedContinuation { continuation in
            if captureStreamReachedTerminalState {
                continuation.resume(returning: true)
            } else {
                captureDrainContinuations[waiterID] = continuation
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(6))
                    self?.resolveCaptureDrain(waiterID, drained: false)
                }
            }
        }
    }

    private func markCaptureEventsDrained() {
        captureStreamReachedTerminalState = true
        let continuations = captureDrainContinuations
        captureDrainContinuations.removeAll()
        continuations.values.forEach { $0.resume(returning: true) }
    }

    private func resolveCaptureDrain(_ waiterID: UUID, drained: Bool) {
        captureDrainContinuations.removeValue(forKey: waiterID)?.resume(returning: drained)
    }

    func cancelChatTask() {
        chatTask?.cancel()
        chatTask = nil
        chatTaskID = nil
        chatCancellationAssistantID = nil
    }

    func cancelChatTaskAndWait() async {
        guard let task = chatTask else { return }
        let expectedID = chatTaskID
        let expectedAssistantID = chatCancellationAssistantID
        let meetingID = viewState.meeting?.id
        task.cancel()
        await task.value
        if let meetingID, viewState.meeting?.id == meetingID {
            await reloadCanonicalChatAfterCancellation(
                meetingID: meetingID,
                expectedAssistantID: expectedAssistantID
            )
            if let provider = viewState.meeting?.configuration.agentProvider {
                viewState.providerMessage = providerLabel(provider)
            }
        }
        if chatTaskID == expectedID {
            chatTask = nil
            chatTaskID = nil
            chatCancellationAssistantID = nil
        }
    }

    private func reloadCanonicalChatAfterCancellation(
        meetingID: UUID,
        expectedAssistantID: UUID?
    ) async {
        var chat: [ChatMessage] = []
        for attempt in 0..<20 {
            chat = (try? await dependencies.repository.loadChat(id: meetingID)) ?? chat
            let expectedAssistant = expectedAssistantID.flatMap { id in
                chat.first(where: { $0.id == id })
            }
            let reachedTerminalState = expectedAssistantID == nil
                || (expectedAssistant != nil && expectedAssistant?.status != .sending)
            if reachedTerminalState {
                viewState.chat = chat
                return
            }
            if attempt < 19 { try? await Task.sleep(for: .milliseconds(50)) }
        }
        guard let expectedAssistantID,
              let index = chat.firstIndex(where: {
                  $0.id == expectedAssistantID && $0.role == .assistant && $0.status == .sending
              }) else {
            viewState.chat = chat
            return
        }
        chat[index].status = .failed
        if chat[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chat[index].content = "Response cancelled."
        }
        do {
            try await dependencies.repository.saveChat(chat, id: meetingID)
            viewState.chat = chat
        } catch {
            viewState.chat = chat
            viewState.warning = "The cancelled chat state could not be saved: \(error.localizedDescription)"
        }
    }

    func isCurrentChatTask(_ taskID: UUID, meetingID: UUID) -> Bool {
        !Task.isCancelled
            && chatTaskID == taskID
            && viewState.meeting?.id == meetingID
    }

    func finishChatTask(_ taskID: UUID) {
        guard chatTaskID == taskID else { return }
        chatTask = nil
        chatTaskID = nil
        chatCancellationAssistantID = nil
    }

    private func failStart(_ error: any Error) async {
        realtimeEnabled = false
        await dependencies.realtime.stopRealtime()
        _ = try? await dependencies.capture.stop()
        if var meeting = viewState.meeting {
            meeting.status = .failed
            meeting.failureMessage = error.localizedDescription
            meeting.updatedAt = Date()
            try? await dependencies.repository.saveMeeting(meeting)
            if meeting.configuration.mcpEnabled {
                try? await dependencies.snapshotExporter.disable(meetingID: meeting.id)
            }
            viewState.meeting = meeting
        }
        viewState.phase = .failed(error.localizedDescription)
        viewState.localRecordingMessage = "Recording did not start"
    }

    private func transcriptionLabel(_ mode: TranscriptionMode) -> String {
        switch mode {
        case .realtime: "Preparing ElevenLabs live transcript"
        case .afterMeeting: "Transcript after meeting · ElevenLabs"
        case .recordOnly: "Local recording only"
        }
    }

    private func providerLabel(_ provider: AgentProviderKind) -> String {
        switch provider {
        case .claudeAPI: "Copilot · Claude API"
        case .claudeCLI: "Copilot · Claude CLI"
        case .codexCLI: "Copilot · Codex CLI"
        case .none: "Copilot off"
        }
    }
}
