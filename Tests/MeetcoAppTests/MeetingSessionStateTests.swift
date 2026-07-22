import MeetcoCore
import Testing
@testable import MeetcoApp

@Test("Only in-flight session phases are active")
func activeSessionPhases() {
    let active: [MeetingSessionPhase] = [
        .preparing,
        .recording,
        .paused,
        .stopping,
        .finalizing(.finalTranscript),
    ]
    for phase in active {
        #expect(MeetingSessionViewState(phase: phase).isActive)
    }

    let inactive: [MeetingSessionPhase] = [.idle, .completed, .failed("offline")]
    for phase in inactive {
        #expect(!MeetingSessionViewState(phase: phase).isActive)
    }
}

@Test("Meeting formatting stays stable for long recordings")
func durationFormatting() {
    #expect(MeetcoFormatting.duration(milliseconds: 0) == "00:00")
    #expect(MeetcoFormatting.duration(milliseconds: 65_000) == "01:05")
    #expect(MeetcoFormatting.duration(milliseconds: 3_661_000) == "1:01:01")
}
