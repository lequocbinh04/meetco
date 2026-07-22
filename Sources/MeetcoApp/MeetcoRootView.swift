import MeetcoCore
import SwiftUI

struct MeetcoRootView: View {
    @ObservedObject var model: AppModel
    @State private var meetingPendingDeletion: UUID?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            content
        }
        .navigationSplitViewStyle(.balanced)
        // Brand accent for system controls (prominent buttons, pickers, toggles).
        .tint(MeetcoTheme.accent)
        .sheet(isPresented: $model.isPreflightPresented) { preflight }
        .sheet(isPresented: $model.isOnboardingPresented) { onboarding }
        .confirmationDialog(
            "Delete this meeting?",
            isPresented: deletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Meeting", role: .destructive) { model.deleteSelectedMeeting() }
            Button("Cancel", role: .cancel) { meetingPendingDeletion = nil }
        } message: {
            Text("This permanently removes its local transcript, artifacts, notes, and retained audio.")
        }
        .alert("Meetco needs attention", isPresented: errorPresentation) {
            Button("OK") { model.startupError = nil }
        } message: {
            Text(model.startupError ?? "An unexpected error occurred.")
        }
    }

    private var sidebar: some View {
        MeetcoSidebar(
            selection: model.showsLiveMeeting ? nil : model.destination,
            activeMeeting: model.session?.viewState.isActive == true
                ? model.session?.viewState.meeting
                : nil,
            onSelect: model.selectDestination,
            onOpenLiveMeeting: model.openLiveMeeting,
            onNewRecording: model.presentPreflight
        )
    }

    @ViewBuilder private var content: some View {
        if model.showsLiveMeeting, let session = model.session {
            MeetcoSessionSurface(session: session, model: model)
        } else {
            switch model.destination {
            case .home:
                HomeView(
                    state: MeetcoViewStateFactory.home(model),
                    onNewRecording: model.presentPreflight,
                    onOpenMeeting: model.selectMeeting,
                    onOpenActiveMeeting: model.openLiveMeeting,
                    onOpenDiagnostics: {
                        model.settingsSection = .permissions
                        model.selectDestination(.settings)
                    }
                )
            case .meetings:
                meetingLibrary
            case .settings:
                MeetcoSettingsContainer(model: model)
            }
        }
    }

    private var meetingLibrary: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 860 {
                HSplitView {
                    meetingList
                        .frame(minWidth: 280, idealWidth: 340, maxWidth: 430)
                    meetingDetail
                        .frame(minWidth: 540)
                }
            } else if model.selectedMeeting != nil {
                meetingDetail
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button("All meetings", systemImage: "chevron.left") {
                                model.clearMeetingSelection()
                            }
                        }
                    }
            } else {
                meetingList
            }
        }
    }

    private var meetingList: some View {
        MeetingListView(
            state: MeetcoViewStateFactory.meetingList(model),
            onSelect: model.selectMeeting,
            onNewRecording: model.presentPreflight
        )
    }

    @ViewBuilder private var meetingDetail: some View {
        if let state = MeetcoViewStateFactory.detail(model) {
            MeetingDetailView(
                state: state,
                onExport: model.exportSelectedMeeting,
                onDelete: { meetingPendingDeletion = state.snapshot.meeting.id },
                onRevealLocalFiles: model.revealSelectedMeetingFiles,
                onOpenEvidence: model.openSelectedEvidence,
                onToggleAction: model.toggleSelectedAction,
                onRegenerateArtifacts: model.regenerateSelectedArtifacts,
                onRetryFinalTranscript: model.retrySelectedFinalTranscript,
                onEditTranscript: model.editSelectedTranscript,
                onPlayAudio: model.playSelectedAudio,
                onNotesChange: model.saveSelectedNotes,
                onSendMessage: model.sendSelectedChat
            )
            .id(state.snapshot.meeting.id)
        } else {
            ContentUnavailableView {
                Label("Select a meeting", systemImage: "waveform")
            } description: {
                Text("Choose a local meeting to review its transcript, notes, and actions.")
            }
        }
    }

    private var preflight: some View {
        RecordingPreflightView(
            state: MeetcoViewStateFactory.preflight(model),
            onConfigurationChange: { model.draftConfiguration = $0 },
            onStart: { title in
                model.startRecording(
                    title: title,
                    configuration: model.draftConfiguration
                )
            },
            onOpenConnections: {
                model.isPreflightPresented = false
                model.settingsSection = .connections
                model.selectDestination(.settings)
            }
        )
    }

    private var onboarding: some View {
        MeetcoOnboardingContainer(model: model)
    }

    private var deletionConfirmation: Binding<Bool> {
        Binding(
            get: { meetingPendingDeletion != nil },
            set: { if !$0 { meetingPendingDeletion = nil } }
        )
    }

    private var errorPresentation: Binding<Bool> {
        Binding(
            get: { model.startupError != nil },
            set: { if !$0 { model.startupError = nil } }
        )
    }
}
