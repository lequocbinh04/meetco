import MeetcoCore
import SwiftUI

public struct CaptureModeCard: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    public let mode: CaptureMode
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(mode: CaptureMode, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.mode = mode
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                HStack {
                    Image(systemName: mode == .online ? "macbook.and.iphone" : "person.2.wave.2")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? MeetcoTheme.accent : MeetcoTheme.textSecondary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? MeetcoTheme.accent : MeetcoTheme.border)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode == .online ? "Online meeting" : "On-site")
                        .font(.meetcoSection)
                        .foregroundStyle(MeetcoTheme.textPrimary)
                    Text(mode == .online ? "System audio + microphone" : "Microphone in the room")
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                }
            }
            .padding(MeetcoTheme.Spacing.large)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(isSelected ? MeetcoTheme.accentSoft : (isHovering ? MeetcoTheme.elevated : MeetcoTheme.surface))
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous)
                    .stroke(
                        isSelected ? MeetcoTheme.accent : MeetcoTheme.border,
                        lineWidth: isSelected || contrast == .increased ? 2 : 1
                    )
            }
            .shadow(color: isSelected ? MeetcoTheme.accent.opacity(0.16) : .clear, radius: 10, y: 4)
            .scaleEffect(isHovering && !reduceMotion ? 1.008 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(MeetcoMotion.micro(reduceMotion: reduceMotion), value: isHovering)
        .animation(MeetcoMotion.micro(reduceMotion: reduceMotion), value: isSelected)
        .accessibilityLabel(mode == .online ? "Online meeting, system audio and microphone" : "On-site, microphone in the room")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
