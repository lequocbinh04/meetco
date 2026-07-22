import MeetcoCore

@MainActor
enum MeetcoViewStateFactory {
    static func home(_ model: AppModel) -> HomeViewState {
        HomeViewState(
            greeting: greeting(),
            readiness: [
                readiness(
                    id: "microphone",
                    title: "Microphone",
                    availability: model.captureStatus.microphone
                ),
                readiness(
                    id: "system-audio",
                    title: "System audio",
                    availability: model.captureStatus.systemAudio
                ),
                HomeReadinessItem(
                    id: "elevenlabs",
                    title: "ElevenLabs Scribe",
                    detail: model.hasElevenLabsKey ? "Connected" : "API key needed for transcription",
                    isReady: model.hasElevenLabsKey
                ),
            ],
            recentMeetings: model.meetings.prefix(8).map { meeting in
                let metadata = model.meetingMetadata[meeting.id]
                return RecentMeetingState(
                    meeting: meeting,
                    actionCount: metadata?.actionCount ?? 0,
                    transcriptVersion: metadata?.transcriptVersion
                )
            },
            activeMeeting: model.session?.viewState.isActive == true
                ? model.session?.viewState.meeting
                : nil
        )
    }

    static func meetingList(_ model: AppModel) -> MeetingListState {
        MeetingListState(
            meetings: model.meetings.map { meeting in
                let metadata = model.meetingMetadata[meeting.id]
                return MeetingListItemState(
                    meeting: meeting,
                    transcriptVersion: metadata?.transcriptVersion,
                    actionCount: metadata?.actionCount ?? 0
                )
            },
            selectedMeetingID: model.selectedMeetingID
        )
    }

    static func preflight(_ model: AppModel) -> RecordingPreflightState {
        let configuration = model.draftConfiguration
        let captureIssue = captureBlockingReason(
            configuration.captureMode,
            status: model.captureStatus
        )
        let transcriptionIssue = configuration.transcriptionMode == .recordOnly || model.hasElevenLabsKey
            ? nil
            : "Add an ElevenLabs API key, or choose Record only."
        let blockingReason = captureIssue ?? transcriptionIssue

        return RecordingPreflightState(
            configuration: configuration,
            transcriptionHealth: transcriptionHealth(model),
            agentHealth: configuration.agentProvider == .none
                ? nil
                : model.providerHealth[configuration.agentProvider],
            localStorageDetail: retentionLabel(configuration.audioRetention),
            canStart: blockingReason == nil && model.session?.viewState.isActive != true,
            blockingReason: model.session?.viewState.isActive == true
                ? "Finish the current meeting before starting another."
                : blockingReason
        )
    }

    static func onboarding(_ model: AppModel) -> OnboardingViewState {
        let provider = model.settings.defaultConfiguration.agentProvider
        return OnboardingViewState(
            step: model.onboardingStep,
            transcriptionHealth: transcriptionHealth(model),
            selectedAgent: provider,
            agentHealth: provider == .none ? nil : model.providerHealth[provider],
            canContinue: true
        )
    }
}
