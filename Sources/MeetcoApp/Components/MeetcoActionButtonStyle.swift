import SwiftUI

public enum MeetcoActionTone: Sendable {
    case accent
    case recording
    case ink
}

public struct MeetcoActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    public let tone: MeetcoActionTone

    public init(tone: MeetcoActionTone = .accent) {
        self.tone = tone
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(MeetcoTheme.inkText.opacity(isEnabled ? 1 : 0.62))
            .padding(.horizontal, 18)
            .frame(minHeight: 40)
            .background {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                    .fill(background)
                    .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.34)
            }
            .overlay {
                // Faint top bevel keeps filled buttons from reading as flat slabs.
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: shadowColor.opacity(isEnabled ? 0.3 : 0),
                radius: configuration.isPressed ? 2 : 7,
                y: 3
            )
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.985 : 1)
            .animation(MeetcoMotion.micro(reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    private var background: AnyShapeStyle {
        switch tone {
        case .accent: AnyShapeStyle(MeetcoTheme.accentGradient)
        case .recording: AnyShapeStyle(MeetcoTheme.recordingGradient)
        case .ink: AnyShapeStyle(MeetcoTheme.inkElevated)
        }
    }

    private var shadowColor: Color {
        switch tone {
        case .accent: MeetcoTheme.accent
        case .recording: MeetcoTheme.recording
        case .ink: Color.black
        }
    }
}

public struct MeetcoSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(MeetcoTheme.textPrimary.opacity(isEnabled ? 1 : 0.46))
            .padding(.horizontal, 18)
            .frame(minHeight: 40)
            .background(
                MeetcoTheme.surface.opacity(
                    isEnabled ? (configuration.isPressed ? 0.68 : 1) : 0.42
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                    .stroke(MeetcoTheme.border)
            }
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.985 : 1)
            .animation(MeetcoMotion.micro(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
