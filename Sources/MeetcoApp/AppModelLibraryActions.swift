import AppKit
import AVFoundation
import Foundation
import MeetcoCore
import UniformTypeIdentifiers

extension AppModel {
    func refreshMeetings() async {
        guard let dependencies else { return }
        meetings = (try? await dependencies.repository.listMeetings()) ?? []
        var metadata: [UUID: MeetingLibraryMetadata] = [:]
        for meeting in meetings {
            let artifacts = (try? await dependencies.repository.loadArtifacts(id: meeting.id)) ?? .init()
            let final = (try? await dependencies.repository.loadTranscript(id: meeting.id, version: .final)) ?? []
            let provisional = final.isEmpty
                ? ((try? await dependencies.repository.loadTranscript(id: meeting.id, version: .provisional)) ?? [])
                : []
            metadata[meeting.id] = MeetingLibraryMetadata(
                actionCount: artifacts.actionItems.count,
                transcriptVersion: !final.isEmpty ? .final : (!provisional.isEmpty ? .provisional : nil)
            )
        }
        meetingMetadata = metadata
        if let selectedMeetingID { await loadMeeting(selectedMeetingID) }
    }

    func startRecording(title: String, configuration: MeetingConfiguration) {
        guard let session else { return }
        let configuration = configuration.normalizedForSession()
        settings.defaultConfiguration = configuration
        Task {
            try? await dependencies?.settingsStore.save(settings)
            isPreflightPresented = false
            destination = .home
            showsLiveMeeting = true
            await session.start(title: title, configuration: configuration)
            await refreshMeetings()
        }
    }

    func selectMeeting(_ id: UUID) {
        cancelSelectedAgentTask()
        cancelSelectedTranscriptRetry()
        showsLiveMeeting = false
        selectedMeetingID = id
        destination = .meetings
        Task { await loadMeeting(id) }
    }

    func clearMeetingSelection() {
        cancelSelectedAgentTask()
        cancelSelectedTranscriptRetry()
        selectedMeetingID = nil
        selectedMeeting = nil
    }

    func selectDestination(_ value: AppDestination) {
        if value != .meetings { cancelSelectedAgentTask() }
        if value != .meetings { cancelSelectedTranscriptRetry() }
        destination = value
        showsLiveMeeting = false
    }

    func presentPreflight() {
        draftConfiguration = settings.defaultConfiguration
        isPreflightPresented = true
    }

    func openLiveMeeting() {
        guard session?.viewState.meeting != nil else { return }
        showsLiveMeeting = true
    }

    func loadMeeting(_ id: UUID) async {
        guard let dependencies,
              let meeting = try? await dependencies.repository.loadMeeting(id: id) else {
            if selectedMeetingID == id { selectedMeeting = nil }
            return
        }
        let final = (try? await dependencies.repository.loadTranscript(id: id, version: .final)) ?? []
        let provisional = (try? await dependencies.repository.loadTranscript(id: id, version: .provisional)) ?? []
        let detail = MeetingDetailSnapshot(
            meeting: meeting,
            transcript: final.isEmpty ? provisional : final,
            transcriptVersion: !final.isEmpty ? .final : (!provisional.isEmpty ? .provisional : nil),
            artifacts: (try? await dependencies.repository.loadArtifacts(id: id)) ?? .init(),
            chat: (try? await dependencies.repository.loadChat(id: id)) ?? [],
            notes: (try? await dependencies.repository.loadNotes(id: id)) ?? ""
        )
        guard selectedMeetingID == id else { return }
        selectedMeeting = detail
    }

    func deleteSelectedMeeting() {
        guard let dependencies, let selectedMeetingID else { return }
        cancelSelectedAgentTask()
        cancelSelectedTranscriptRetry()
        Task {
            do {
                if let snapshot = try? SnapshotExporter.load(from: dependencies.paths.liveSnapshotURL),
                   snapshot.meeting.id == selectedMeetingID {
                    try? await dependencies.snapshotExporter.disable(meetingID: selectedMeetingID)
                }
                try await dependencies.repository.deleteMeeting(id: selectedMeetingID)
                self.selectedMeetingID = nil
                selectedMeeting = nil
                await refreshMeetings()
            } catch {
                startupError = error.localizedDescription
            }
        }
    }

    func exportSelectedMeeting(as format: MeetingExportFormat) {
        guard let dependencies, let selectedMeeting else { return }
        let snapshot = selectedMeeting.contextSnapshot
        let panel = NSSavePanel()
        panel.nameFieldStringValue = MeetingExporter.suggestedFileName(
            selectedMeeting.meeting,
            format: format
        )
        panel.allowedContentTypes = [contentType(for: format)]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }
            do {
                try MeetingExporter.write(
                    snapshot: snapshot,
                    format: format,
                    audioURL: dependencies.paths.audioDirectory(id: selectedMeeting.meeting.id)
                        .appendingPathComponent("final-mix.wav"),
                    to: destination
                )
            } catch {
                Task { @MainActor in self?.startupError = error.localizedDescription }
            }
        }
    }

    func playSelectedAudio(at milliseconds: Int64) {
        guard let dependencies, let detail = selectedMeeting else { return }
        let url = dependencies.paths.audioDirectory(id: detail.meeting.id)
            .appendingPathComponent("final-mix.wav")
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = max(0, Double(milliseconds) / 1_000)
            player.play()
            audioPlayer = player
        } catch {
            startupError = error.localizedDescription
        }
    }

    func openSelectedEvidence(_ evidence: EvidenceReference) {
        guard selectedMeeting?.meeting.hasLocalAudio == true else { return }
        if let milliseconds = evidence.startMilliseconds {
            playSelectedAudio(at: milliseconds)
            return
        }
        guard let firstID = evidence.segmentIDs.first,
              let segment = selectedMeeting?.transcript.first(where: { $0.id == firstID }) else { return }
        playSelectedAudio(at: segment.startMilliseconds)
    }

    func revealSelectedMeetingFiles() {
        guard let dependencies, let detail = selectedMeeting else { return }
        let directory = dependencies.paths.meetingDirectory(id: detail.meeting.id)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    private func contentType(for format: MeetingExportFormat) -> UTType {
        switch format {
        case .markdown: UTType(filenameExtension: "md") ?? .plainText
        case .json: .json
        case .audio: .wav
        }
    }
}
