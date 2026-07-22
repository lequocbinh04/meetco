import Foundation
import MeetcoCore

enum MeetingSessionPhase: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopping
    case finalizing(FinalizationStage)
    case completed
    case failed(String)
}

enum FinalizationStage: String, CaseIterable, Equatable {
    case closingRecording
    case finalTranscript
    case meetingNotes
    case publishingSnapshot

    var title: String {
        switch self {
        case .closingRecording: "Saving local recording"
        case .finalTranscript: "Final transcript"
        case .meetingNotes: "Meeting notes"
        case .publishingSnapshot: "Finishing up"
        }
    }
}

struct MeetingSessionViewState: Equatable {
    var phase: MeetingSessionPhase = .idle
    var meeting: Meeting?
    var elapsedMilliseconds: Int64 = 0
    var audioLevels: [AudioSource: AudioLevel] = [:]
    var transcript: [TranscriptSegment] = []
    var partialTranscript: TranscriptSegment?
    var chat: [ChatMessage] = []
    var privateNotes = ""
    var localRecordingMessage = "Ready to record locally"
    var transcriptionMessage = "Transcription not started"
    var providerMessage = "Copilot not started"
    var warning: String?

    var isActive: Bool {
        switch phase {
        case .preparing, .recording, .paused, .stopping, .finalizing: true
        case .idle, .completed, .failed: false
        }
    }
}
