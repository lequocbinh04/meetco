import MeetcoCore
import SwiftUI

public struct LiveTranscriptView: View {
    public let segments: [TranscriptSegment]
    public let version: TranscriptVersion
    public let scrollToSegmentID: UUID?
    public let onSelectSegment: (UUID) -> Void

    public init(
        segments: [TranscriptSegment],
        version: TranscriptVersion,
        scrollToSegmentID: UUID? = nil,
        onSelectSegment: @escaping (UUID) -> Void
    ) {
        self.segments = segments
        self.version = version
        self.scrollToSegmentID = scrollToSegmentID
        self.onSelectSegment = onSelectSegment
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcript").font(.meetcoTitle)
                StatusBadge(
                    version == .final ? "Final" : "Provisional",
                    systemImage: version == .final ? "checkmark.circle.fill" : "clock",
                    tone: version == .final ? .success : .warning
                )
                Spacer()
            }
            .padding(MeetcoTheme.Spacing.large)
            Divider()

            if segments.isEmpty {
                EmptyStateView(
                    title: "Listening",
                    message: "Transcript text will appear when speech is detected.",
                    systemImage: "waveform"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                            ForEach(segments) { segment in
                                segmentRow(segment)
                                    .id(segment.id)
                            }
                        }
                        .padding(MeetcoTheme.Spacing.xLarge)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: segments.last?.id) { _, id in
                        guard let id else { return }
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                    .onChange(of: scrollToSegmentID) { _, id in
                        guard let id else { return }
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .background(MeetcoTheme.canvas)
        .accessibilityLabel("\(version == .final ? "Final" : "Provisional") transcript")
    }

    private func segmentRow(_ segment: TranscriptSegment) -> some View {
        HStack(alignment: .top, spacing: MeetcoTheme.Spacing.medium) {
            Button(MeetcoFormatting.timestamp(milliseconds: segment.startMilliseconds)) {
                onSelectSegment(segment.id)
            }
            .buttonStyle(.plain)
            .font(.meetcoMetadata.monospacedDigit())
            .foregroundStyle(MeetcoTheme.textSecondary)
            .accessibilityLabel("Jump to \(MeetcoFormatting.timestamp(milliseconds: segment.startMilliseconds))")
            .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                HStack(spacing: MeetcoTheme.Spacing.small) {
                    Text(speakerName(segment)).font(.meetcoMetadata)
                    if segment.version == .provisional {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(MeetcoTheme.warning)
                            .accessibilityLabel("Provisional")
                    }
                }
                Text(segment.text)
                    .font(.meetcoBody)
                    .foregroundStyle(segment.isCommitted ? MeetcoTheme.textPrimary : MeetcoTheme.textSecondary)
                    .italic(!segment.isCommitted)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func speakerName(_ segment: TranscriptSegment) -> String {
        if let speakerName = segment.speakerName, !speakerName.isEmpty { return speakerName }
        return switch segment.source {
        case .microphone: "You"
        case .system: "Meeting"
        case .mixed: "Room"
        case .unknown: "Speaker"
        }
    }
}
