import AVFoundation
import AppKit
import CoreGraphics
import Foundation

public struct CapturePermissionService: Sendable {
    private static let screenRequestAttemptedKey = "meetco.screen-recording-request-attempted"

    public init() {}

    public func microphoneAvailability() -> CaptureAvailability {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            .ready
        case .notDetermined:
            .microphonePermissionRequired
        case .denied, .restricted:
            .microphonePermissionDenied
        @unknown default:
            .unavailable("Unknown microphone authorization state")
        }
    }

    public func requestMicrophoneAccess() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { return true }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func systemAudioAvailability() -> CaptureAvailability {
        if CGPreflightScreenCaptureAccess() { return .ready }
        return UserDefaults.standard.bool(forKey: Self.screenRequestAttemptedKey)
            ? .screenRecordingPermissionDenied
            : .screenRecordingPermissionRequired
    }

    public func requestScreenRecordingAccess() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        UserDefaults.standard.set(!granted, forKey: Self.screenRequestAttemptedKey)
        return granted
    }

    @MainActor
    public func openMicrophoneSettings() {
        openPrivacyPane(anchor: "Privacy_Microphone")
    }

    @MainActor
    public func openScreenRecordingSettings() {
        openPrivacyPane(anchor: "Privacy_ScreenCapture")
    }

    @MainActor
    private func openPrivacyPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
