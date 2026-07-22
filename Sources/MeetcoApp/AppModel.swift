import AVFoundation
import Combine
import Foundation
import MeetcoCapture
import MeetcoCore

enum AppDestination: String, CaseIterable, Hashable {
    case home
    case meetings
    case settings

    var title: String {
        switch self {
        case .home: "Home"
        case .meetings: "Meetings"
        case .settings: "Settings"
        }
    }
}

struct MeetingDetailSnapshot: Equatable {
    var meeting: Meeting
    var transcript: [TranscriptSegment]
    var transcriptVersion: TranscriptVersion?
    var artifacts: MeetingArtifacts
    var chat: [ChatMessage]
    var notes: String

    var contextSnapshot: MeetingContextSnapshot {
        MeetingContextSnapshot(
            meeting: meeting,
            transcript: transcript,
            artifacts: artifacts,
            chat: chat,
            manualNotes: notes
        )
    }
}

struct MeetingLibraryMetadata: Equatable {
    var actionCount: Int
    var transcriptVersion: TranscriptVersion?
}

@MainActor
final class AppModel: ObservableObject {
    @Published var destination: AppDestination = .home
    @Published var settingsSection: MeetcoSettingsSection = .connections
    @Published var meetings: [Meeting] = []
    @Published var settings = AppSettings()
    @Published var meetingMetadata: [UUID: MeetingLibraryMetadata] = [:]
    @Published var selectedMeetingID: UUID?
    @Published var selectedMeeting: MeetingDetailSnapshot?
    @Published var isPreflightPresented = false
    @Published var isOnboardingPresented = false
    @Published var onboardingStep = OnboardingStep.localFirst
    @Published var draftConfiguration = MeetingConfiguration()
    @Published var showsLiveMeeting = false
    @Published var startupError: String?
    @Published var providerHealth: [AgentProviderKind: ProviderHealth] = [:]
    @Published var captureStatus = CaptureStatus(
        microphone: .microphonePermissionRequired,
        systemAudio: .screenRecordingPermissionRequired
    )
    @Published var hasElevenLabsKey = false
    @Published var hasAnthropicKey = false
    @Published var isSelectedAgentResponding = false
    @Published var isSelectedTranscriptRetrying = false
    @Published var mcpDiagnosticHealth: ProviderHealth?

    let dependencies: AppDependencies?
    let session: MeetingSessionCoordinator?
    var audioPlayer: AVAudioPlayer?
    var selectedAgentTask: Task<Void, Never>?
    var selectedAgentTaskID: UUID?
    var selectedNotesSaveTask: Task<Void, Never>?
    var selectedArtifactsSaveTask: Task<Void, Never>?
    var selectedTranscriptSaveTask: Task<Void, Never>?
    var selectedTranscriptRetryTask: Task<Void, Never>?
    var selectedTranscriptRetryTaskID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    private var lastSessionPhase = MeetingSessionPhase.idle

    init() {
        do {
            let dependencies = try AppDependencies.live()
            self.dependencies = dependencies
            let session = MeetingSessionCoordinator(dependencies: dependencies)
            self.session = session
            session.$viewState
                .map(\.phase)
                .sink { [weak self] phase in self?.sessionPhaseChanged(phase) }
                .store(in: &cancellables)
            session.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
            Task { await bootstrap() }
        } catch {
            self.dependencies = nil
            self.session = nil
            self.startupError = error.localizedDescription
        }
    }

    func bootstrap() async {
        guard let dependencies else { return }
        _ = try? await dependencies.repository.recoverInterruptedMeetings()
        settings = await dependencies.settingsStore.load()
        draftConfiguration = settings.defaultConfiguration
        isOnboardingPresented = !settings.hasCompletedOnboarding
        await reconcileMCPSnapshotAfterBootstrap()
        await refreshMeetings()
        await refreshDiagnostics()
    }

    private func sessionPhaseChanged(_ phase: MeetingSessionPhase) {
        guard phase != lastSessionPhase else { return }
        lastSessionPhase = phase
        if phase == .completed, let meetingID = session?.viewState.meeting?.id {
            showsLiveMeeting = false
            selectedMeetingID = meetingID
            destination = .meetings
            Task {
                await refreshMeetings()
                await loadMeeting(meetingID)
            }
        } else if case .failed = phase {
            Task { await refreshMeetings() }
        }
    }
}
