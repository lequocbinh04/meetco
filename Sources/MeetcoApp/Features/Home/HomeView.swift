import MeetcoCore
import SwiftUI

public struct HomeView: View {
    public let state: HomeViewState
    public let onNewRecording: () -> Void
    public let onOpenMeeting: (UUID) -> Void
    public let onOpenActiveMeeting: () -> Void
    public let onOpenDiagnostics: () -> Void

    public init(
        state: HomeViewState,
        onNewRecording: @escaping () -> Void,
        onOpenMeeting: @escaping (UUID) -> Void,
        onOpenActiveMeeting: @escaping () -> Void,
        onOpenDiagnostics: @escaping () -> Void
    ) {
        self.state = state
        self.onNewRecording = onNewRecording
        self.onOpenMeeting = onOpenMeeting
        self.onOpenActiveMeeting = onOpenActiveMeeting
        self.onOpenDiagnostics = onOpenDiagnostics
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.xxLarge) {
                header
                if let activeMeeting = state.activeMeeting {
                    activeMeetingCard(activeMeeting)
                }
                studioOverview
                recentSection
            }
            .padding(.horizontal, MeetcoTheme.Spacing.xxLarge)
            .padding(.top, MeetcoTheme.Spacing.small)
            .padding(.bottom, MeetcoTheme.Spacing.xLarge)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MeetcoTheme.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.xSmall) {
            Text("YOUR MEETING STUDIO")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(MeetcoTheme.accent)
            Text(state.greeting)
                .font(.meetcoDisplay)
                .foregroundStyle(MeetcoTheme.textPrimary)
        }
    }

    private var studioOverview: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: MeetcoTheme.Spacing.large) {
                recordingHero.frame(minWidth: 360)
                readinessCard.frame(minWidth: 260, maxWidth: 330)
            }
            VStack(spacing: MeetcoTheme.Spacing.large) {
                recordingHero
                readinessCard
            }
        }
    }

    private var recordingHero: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: MeetcoTheme.Radius.hero, style: .continuous)
                .fill(MeetcoTheme.heroGradient)
                .overlay {
                    // Soft accent glow keeps the dark hero from feeling flat.
                    RoundedRectangle(cornerRadius: MeetcoTheme.Radius.hero, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [MeetcoTheme.accent.opacity(0.28), .clear],
                                center: .bottomTrailing,
                                startRadius: 20,
                                endRadius: 420
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MeetcoTheme.Radius.hero, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08))
                }
                .shadow(color: MeetcoTheme.ink.opacity(0.22), radius: 18, y: 8)

            StudioWaveformView(color: MeetcoTheme.accent, spacing: 7)
                .scaleEffect(1.55, anchor: .bottomTrailing)
                .opacity(0.4)
                .padding(.trailing, 34)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                Label("Local capture ready", systemImage: "circle.fill")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.success)

                VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                    Text("Start the next meeting")
                        .font(.meetcoHero)
                        .foregroundStyle(MeetcoTheme.inkText)
                    Text("Online or in the room. Meetco keeps the original capture local before optional transcription and notes.")
                        .font(.meetcoBody)
                        .foregroundStyle(MeetcoTheme.inkTextSecondary)
                        .frame(maxWidth: 520, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onNewRecording) {
                    Label("New recording", systemImage: "record.circle.fill")
                }
                .buttonStyle(MeetcoActionButtonStyle(tone: .recording))
            }
            .padding(MeetcoTheme.Spacing.xLarge)
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        }
    }

    private func activeMeetingCard(_ meeting: Meeting) -> some View {
        MeetcoCard {
            HStack(spacing: MeetcoTheme.Spacing.medium) {
                StatusBadge(
                    meeting.status == .paused ? "Paused" : "Recording",
                    systemImage: "record.circle",
                    tone: .recording
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting.title).font(.meetcoSection)
                    Text("Audio is being saved locally")
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                }
                Spacer()
                Button("Open live meeting", action: onOpenActiveMeeting)
            }
        }
    }

    private var readinessCard: some View {
        MeetcoCard {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Studio check").font(.meetcoTitle)
                        Text("Before you record")
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                    }
                    Spacer()
                    if state.readiness.contains(where: { !$0.isReady }) {
                        Button("Review", action: onOpenDiagnostics)
                    }
                }
                ForEach(state.readiness) { item in
                    HStack(spacing: MeetcoTheme.Spacing.small) {
                        Image(systemName: item.isReady ? "checkmark" : "exclamationmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(item.isReady ? MeetcoTheme.success : MeetcoTheme.warning)
                            .frame(width: 24, height: 24)
                            .background((item.isReady ? MeetcoTheme.success : MeetcoTheme.warning).opacity(0.12))
                            .clipShape(Circle())
                        Text(item.title).font(.meetcoBody)
                        Spacer()
                        Text(item.detail)
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(minHeight: 228, alignment: .top)
        }
    }

    @ViewBuilder private var recentSection: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
            HStack {
                Text("Recent meetings").font(.meetcoTitle)
                Spacer()
                Text("Stored on this Mac")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }
            if state.recentMeetings.isEmpty {
                HStack(spacing: MeetcoTheme.Spacing.large) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(MeetcoTheme.accent)
                        .frame(width: 48, height: 48)
                        .background(MeetcoTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No meetings yet").font(.meetcoSection)
                        Text("Your first recording will appear here with transcript, notes, and actions.")
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(MeetcoTheme.Spacing.large)
                .background(MeetcoTheme.surfaceMuted.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous))
            } else {
                MeetcoCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(state.recentMeetings.enumerated()), id: \.element.id) { index, meeting in
                            RecentMeetingRow(state: meeting) { onOpenMeeting(meeting.id) }
                                .padding(.horizontal, MeetcoTheme.Spacing.large)
                                .padding(.vertical, MeetcoTheme.Spacing.medium)
                            if index < state.recentMeetings.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }
}
