import Foundation
import MeetcoCore

public enum MeetcoFormatting {
    public static func duration(milliseconds: Int64) -> String {
        let totalSeconds = max(0, milliseconds / 1_000)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%lld:%02lld:%02lld", hours, minutes, seconds)
        }
        return String(format: "%02lld:%02lld", minutes, seconds)
    }

    public static func timestamp(milliseconds: Int64) -> String {
        duration(milliseconds: milliseconds)
    }

    public static func provider(_ provider: AgentProviderKind) -> String {
        switch provider {
        case .claudeAPI: "Claude API"
        case .claudeCLI: "Claude CLI"
        case .codexCLI: "Codex CLI"
        case .none: "No agent"
        }
    }

    public static func captureMode(_ mode: CaptureMode) -> String {
        mode == .online ? "Online meeting" : "On-site"
    }

    public static func transcriptionMode(_ mode: TranscriptionMode) -> String {
        switch mode {
        case .realtime: "Live"
        case .afterMeeting: "After meeting"
        case .recordOnly: "Audio only"
        }
    }
}
