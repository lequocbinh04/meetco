import MeetcoCore
import SwiftUI

struct PreflightSectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.meetcoTitle)
            Text(detail)
                .font(.meetcoMetadata)
                .foregroundStyle(MeetcoTheme.textSecondary)
        }
    }
}

struct TranscriptionModeSelector: View {
    let selection: TranscriptionMode
    let onSelect: (TranscriptionMode) -> Void

    var body: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            choice(
                .realtime,
                title: "Live",
                detail: "Transcript + copilot",
                systemImage: "bolt.fill"
            )
            choice(
                .afterMeeting,
                title: "After meeting",
                detail: "Capture first, process later",
                systemImage: "clock.arrow.circlepath"
            )
            choice(
                .recordOnly,
                title: "Audio only",
                detail: "No provider required",
                systemImage: "waveform"
            )
        }
    }

    private func choice(
        _ mode: TranscriptionMode,
        title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        PreflightChoiceButton(
            title: title,
            detail: detail,
            systemImage: systemImage,
            isSelected: selection == mode,
            action: { onSelect(mode) }
        )
    }
}

private struct PreflightChoiceButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    let title: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MeetcoTheme.Spacing.medium) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.white.opacity(0.16) : MeetcoTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.meetcoSection)
                    Text(detail)
                        .font(.meetcoMetadata)
                        .opacity(0.72)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? MeetcoTheme.inkText : MeetcoTheme.textPrimary)
            .padding(MeetcoTheme.Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(isSelected ? MeetcoTheme.accent : (isHovering ? MeetcoTheme.elevated : MeetcoTheme.surface))
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.16) : MeetcoTheme.border)
            }
            .scaleEffect(isHovering && !reduceMotion ? 1.006 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(MeetcoMotion.micro(reduceMotion: reduceMotion), value: isHovering)
        .animation(MeetcoMotion.micro(reduceMotion: reduceMotion), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
