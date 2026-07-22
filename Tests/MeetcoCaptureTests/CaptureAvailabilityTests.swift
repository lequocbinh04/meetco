import Testing
@testable import MeetcoCapture

@Suite("Capture availability")
struct CaptureAvailabilityTests {
    @Test
    func availabilityCarriesActionableState() {
        let status = CaptureStatus(
            microphone: .microphonePermissionRequired,
            systemAudio: .screenRecordingPermissionRequired
        )
        #expect(status.microphone == .microphonePermissionRequired)
        #expect(status.systemAudio == .screenRecordingPermissionRequired)
        #expect(CaptureAvailability.microphonePermissionDenied != .microphonePermissionRequired)
    }
}
