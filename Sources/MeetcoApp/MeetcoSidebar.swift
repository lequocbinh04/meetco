import MeetcoCore
import SwiftUI

struct MeetcoSidebar: View {
    let selection: AppDestination?
    let activeMeeting: Meeting?
    let onSelect: (AppDestination) -> Void
    let onOpenLiveMeeting: () -> Void
    let onNewRecording: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.bottom, MeetcoTheme.Spacing.xxLarge)

            VStack(spacing: MeetcoTheme.Spacing.small) {
                destination(.home, icon: "square.grid.2x2")
                destination(.meetings, icon: "waveform")
                destination(.settings, icon: "slider.horizontal.3")
            }

            if let activeMeeting {
                liveMeeting(activeMeeting)
                    .padding(.top, MeetcoTheme.Spacing.xLarge)
            }

            Spacer(minLength: MeetcoTheme.Spacing.xLarge)

            localStatus
                .padding(.bottom, MeetcoTheme.Spacing.medium)

            Button(action: onNewRecording) {
                Label("New recording", systemImage: "record.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MeetcoActionButtonStyle(tone: .recording))
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(MeetcoTheme.Spacing.large)
        .padding(.top, -MeetcoTheme.Spacing.large)
        .background(MeetcoTheme.ink.ignoresSafeArea())
        .navigationSplitViewColumnWidth(min: 205, ideal: 224, max: 248)
    }

    private var brand: some View {
        HStack(spacing: MeetcoTheme.Spacing.medium) {
            MeetcoBrandMark(size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text("Meetco")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MeetcoTheme.inkText)
                Text("Meeting Studio")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MeetcoTheme.inkTextSecondary)
            }
        }
        .padding(.leading, MeetcoTheme.Spacing.xSmall)
    }

    private func destination(_ destination: AppDestination, icon: String) -> some View {
        SidebarDestinationButton(
            title: destination.title,
            systemImage: icon,
            isSelected: selection == destination,
            action: { onSelect(destination) }
        )
    }

    private func liveMeeting(_ meeting: Meeting) -> some View {
        Button(action: onOpenLiveMeeting) {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                Label(meeting.status == .paused ? "Paused" : "Recording", systemImage: "record.circle.fill")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.recording)
                Text(meeting.title)
                    .font(.meetcoSection)
                    .foregroundStyle(MeetcoTheme.inkText)
                    .lineLimit(2)
            }
            .padding(MeetcoTheme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MeetcoTheme.inkElevated)
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous)
                    .stroke(MeetcoTheme.recording.opacity(0.35))
            }
        }
        .buttonStyle(.plain)
    }

    private var localStatus: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            Image(systemName: "internaldrive.fill")
                .foregroundStyle(MeetcoTheme.success)
            VStack(alignment: .leading, spacing: 1) {
                Text("Local-first")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.inkText)
                Text("Audio starts on this Mac")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MeetcoTheme.inkTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SidebarDestinationButton: View {
    @State private var isHovering = false
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MeetcoTheme.Spacing.medium) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? MeetcoTheme.accent : MeetcoTheme.inkTextSecondary)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? MeetcoTheme.inkText : MeetcoTheme.inkTextSecondary)
                Spacer()
            }
            .padding(.horizontal, MeetcoTheme.Spacing.medium)
            .frame(minHeight: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                        .fill(MeetcoTheme.inkElevated)
                        .overlay {
                            RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06))
                        }
                } else if isHovering {
                    RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
