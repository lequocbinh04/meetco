import Foundation
import MeetcoCapture
import MeetcoCore

extension MeetcoViewStateFactory {
    static func transcriptionHealth(_ model: AppModel) -> ProviderHealth {
        ProviderHealth(
            state: model.hasElevenLabsKey ? .ready : .notConfigured,
            detail: model.hasElevenLabsKey
                ? "API key stored in macOS Keychain"
                : "Add your ElevenLabs API key for Scribe"
        )
    }

    static func providerConnection(
        _ kind: AgentProviderKind,
        model: AppModel
    ) -> ProviderConnectionState {
        ProviderConnectionState(
            id: kind.rawValue,
            name: MeetcoFormatting.provider(kind),
            kind: kind,
            health: model.providerHealth[kind]
                ?? ProviderHealth(state: .unavailable, detail: "Checking connection…")
        )
    }

    static func readiness(
        id: String,
        title: String,
        availability: CaptureAvailability
    ) -> HomeReadinessItem {
        HomeReadinessItem(
            id: id,
            title: title,
            detail: availabilityDetail(availability),
            isReady: availability == .ready
        )
    }

    static func permission(
        id: String,
        title: String,
        detail: String,
        systemImage: String,
        availability: CaptureAvailability
    ) -> PermissionDiagnosticItem {
        PermissionDiagnosticItem(
            id: id,
            title: title,
            detail: "\(detail) · \(availabilityDetail(availability))",
            systemImage: systemImage,
            status: permissionStatus(availability)
        )
    }

    static func permissionStatus(_ availability: CaptureAvailability) -> PermissionDiagnosticStatus {
        switch availability {
        case .ready: .granted
        case .microphonePermissionRequired, .screenRecordingPermissionRequired: .notRequested
        case .microphonePermissionDenied, .screenRecordingPermissionDenied: .denied
        case .unavailable: .unavailable
        }
    }

    static func availabilityDetail(_ availability: CaptureAvailability) -> String {
        switch availability {
        case .ready: "Ready"
        case .microphonePermissionRequired: "Permission required"
        case .microphonePermissionDenied: "Denied · open System Settings"
        case .screenRecordingPermissionRequired: "Permission required"
        case .screenRecordingPermissionDenied: "Denied · open System Settings"
        case .unavailable(let detail): detail
        }
    }

    static func captureBlockingReason(
        _ mode: CaptureMode,
        status: CaptureStatus
    ) -> String? {
        if status.microphone != .ready {
            return "Microphone permission is required before recording."
        }
        if mode == .online, status.systemAudio != .ready {
            return "Screen Recording permission is required for system audio."
        }
        return nil
    }

    static func retentionLabel(_ retention: AudioRetention) -> String {
        switch retention {
        case .keepAudio: "Keep local audio and transcript"
        case .transcriptOnly: "Remove audio after a final transcript is saved"
        case .audioOnly: "Keep local audio without requiring a transcript"
        }
    }

    static func greeting(now: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        return switch hour {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }
}
