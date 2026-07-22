import MeetcoCore
import SwiftUI

struct MeetcoSessionSurface: View {
    @ObservedObject var session: MeetingSessionCoordinator
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch session.viewState.phase {
            case .idle:
                unavailable("No active meeting", "Start a recording from Home.")
            case .preparing:
                progressSurface(
                    title: "Preparing your recording",
                    detail: session.viewState.localRecordingMessage
                )
            case .recording, .paused:
                if let state = MeetcoViewStateFactory.live(session, model: model) {
                    LiveMeetingView(
                        state: state,
                        onPauseResume: session.pauseOrResume,
                        onStop: session.stop,
                        onNotesChange: session.savePrivateNotes,
                        onSendMessage: session.sendChat,
                        onSelectTranscriptSegment: { _ in }
                    )
                }
            case .stopping:
                progressSurface(
                    title: "Saving the local recording",
                    detail: session.viewState.localRecordingMessage
                )
            case .finalizing(let stage):
                finalizationSurface(stage)
            case .completed:
                progressSurface(title: "Meeting saved", detail: "Opening your meeting library…")
            case .failed(let message):
                unavailable("Recording needs attention", message)
            }
        }
        .background(MeetcoTheme.canvas)
    }

    private func progressSurface(title: String, detail: String) -> some View {
        VStack(spacing: MeetcoTheme.Spacing.large) {
            ProgressView().controlSize(.large)
            VStack(spacing: MeetcoTheme.Spacing.small) {
                Text(title).font(.meetcoTitle)
                Text(detail)
                    .font(.meetcoBody)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }
            StatusBadge(
                "Local-first",
                systemImage: "internaldrive.fill",
                tone: .success
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func finalizationSurface(_ stage: FinalizationStage) -> some View {
        VStack(spacing: 0) {
            FinalizationRailView(stages: stageStates(current: stage), onRetry: { _ in })
                .padding(MeetcoTheme.Spacing.large)
            Divider()
            LiveTranscriptView(
                segments: session.viewState.transcript,
                version: session.viewState.transcript.first?.version ?? .provisional,
                onSelectSegment: { _ in }
            )
        }
        .navigationTitle(session.viewState.meeting?.title ?? "Finalizing meeting")
    }

    private func stageStates(current: FinalizationStage) -> [FinalizationStageState] {
        let currentIndex = FinalizationStage.allCases.firstIndex(of: current) ?? 0
        return FinalizationStage.allCases.enumerated().map { index, stage in
            FinalizationStageState(
                id: stage.rawValue,
                title: stage.title,
                status: index < currentIndex ? .completed : (index == currentIndex ? .running : .pending)
            )
        }
    }

    private func unavailable(_ title: String, _ detail: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "waveform.badge.exclamationmark")
        } description: {
            Text(detail)
        } actions: {
            Button("Back to Home") { model.selectDestination(.home) }
        }
    }
}
