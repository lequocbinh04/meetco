import SwiftUI

public enum MeetcoStatusTone: Sendable {
    case neutral
    case accent
    case success
    case warning
    case error
    case recording
}

public struct StatusBadge: View {
    public let label: String
    public let systemImage: String
    public let tone: MeetcoStatusTone

    public init(_ label: String, systemImage: String, tone: MeetcoStatusTone = .neutral) {
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        Label(label, systemImage: systemImage)
            .font(.meetcoMetadata)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(foreground.opacity(0.18))
            }
            .accessibilityLabel(label)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: MeetcoTheme.textSecondary
        case .accent: MeetcoTheme.accent
        case .success: MeetcoTheme.success
        case .warning: MeetcoTheme.warning
        case .error: MeetcoTheme.error
        case .recording: MeetcoTheme.recording
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: MeetcoTheme.border.opacity(0.42)
        case .accent: MeetcoTheme.accentSoft
        case .success: MeetcoTheme.success.opacity(0.12)
        case .warning: MeetcoTheme.warning.opacity(0.12)
        case .error: MeetcoTheme.error.opacity(0.12)
        case .recording: MeetcoTheme.recording.opacity(0.12)
        }
    }
}
