import MeetcoCore

extension MeetcoViewStateFactory {
    static func live(
        _ session: MeetingSessionCoordinator,
        model: AppModel
    ) -> LiveMeetingState? {
        let value = session.viewState
        guard let meeting = value.meeting else { return nil }
        var transcript = value.transcript
        if let partial = value.partialTranscript { transcript.append(partial) }

        return LiveMeetingState(
            meetingID: meeting.id,
            title: meeting.title,
            controls: RecordingControlState(
                status: meeting.status == .paused ? .paused : .recording,
                elapsedMilliseconds: value.elapsedMilliseconds,
                microphoneLevel: value.audioLevels[.microphone]?.linear ?? 0,
                systemLevel: meeting.configuration.captureMode == .online
                    ? value.audioLevels[.system]?.linear ?? 0
                    : nil,
                localStatus: value.localRecordingMessage
            ),
            transcript: transcript,
            transcriptVersion: .provisional,
            transcriptNotice: value.warning ?? value.transcriptionMessage,
            privateNotes: value.privateNotes,
            chat: value.chat,
            provider: meeting.configuration.agentProvider,
            providerHealth: meeting.configuration.agentProvider == .none
                ? nil
                : model.providerHealth[meeting.configuration.agentProvider],
            quickPrompts: quickPrompts,
            isCopilotResponding: value.providerMessage.contains("thinking")
        )
    }

    static func detail(_ model: AppModel) -> MeetingDetailState? {
        guard let detail = model.selectedMeeting else { return nil }
        let provider = detail.meeting.configuration.agentProvider
        return MeetingDetailState(
            snapshot: detail.contextSnapshot,
            finalizationStages: [],
            providerHealth: provider == .none ? nil : model.providerHealth[provider],
            isAgentResponding: model.isSelectedAgentResponding,
            isTranscriptionRetrying: model.isSelectedTranscriptRetrying
        )
    }

    static func menuBar(_ model: AppModel) -> MeetcoMenuBarState {
        let session = model.session?.viewState
        let active: Meeting?
        if session?.meeting?.status == .recording || session?.meeting?.status == .paused {
            active = session?.meeting
        } else {
            active = nil
        }
        let canStart = captureBlockingReason(
            model.settings.defaultConfiguration.captureMode,
            status: model.captureStatus
        ) == nil && session?.isActive != true

        return MeetcoMenuBarState(
            activeMeetingTitle: active?.title,
            recordingStatus: active?.status,
            elapsedMilliseconds: session?.elapsedMilliseconds ?? 0,
            lastPreset: model.settings.defaultConfiguration,
            canStart: canStart,
            readinessDetail: canStart
                ? "Local capture is ready"
                : "Review capture permissions in Meetco"
        )
    }

    private static var quickPrompts: [CopilotQuickPrompt] {
        [
            CopilotQuickPrompt(
                id: "recap",
                title: "Recap so far",
                prompt: "Give me a concise recap of the meeting so far, with evidence."
            ),
            CopilotQuickPrompt(
                id: "decisions",
                title: "Decisions",
                prompt: "What decisions have been made so far? Cite the supporting transcript."
            ),
            CopilotQuickPrompt(
                id: "actions",
                title: "Next actions",
                prompt: "List current action items, owners, and deadlines. Mark anything uncertain."
            ),
        ]
    }
}
