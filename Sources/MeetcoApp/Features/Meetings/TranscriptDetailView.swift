import MeetcoCore
import SwiftUI

public struct TranscriptDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query = ""
    public let segments: [TranscriptSegment]
    public let focusedSegmentID: UUID?
    public let hasAudio: Bool
    public let onEdit: (UUID, String, String) -> Void
    public let onPlay: (Int64) -> Void

    public init(
        segments: [TranscriptSegment],
        focusedSegmentID: UUID? = nil,
        hasAudio: Bool = true,
        onEdit: @escaping (UUID, String, String) -> Void,
        onPlay: @escaping (Int64) -> Void
    ) {
        self.segments = segments
        self.focusedSegmentID = focusedSegmentID
        self.hasAudio = hasAudio
        self.onEdit = onEdit
        self.onPlay = onPlay
    }

    public var body: some View {
        Group {
            if segments.isEmpty {
                EmptyStateView(
                    title: "No transcript",
                    message: "This meeting does not have transcript text yet.",
                    systemImage: "doc.text"
                )
            } else if filteredSegments.isEmpty {
                EmptyStateView(
                    title: "No transcript matches",
                    message: "Try a different search term.",
                    systemImage: "magnifyingglass"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: MeetcoTheme.Spacing.medium) {
                            ForEach(filteredSegments) { segment in
                                TranscriptEditorRow(
                                    segment: segment,
                                    isFocused: segment.id == focusedSegmentID,
                                    hasAudio: hasAudio,
                                    onEdit: onEdit,
                                    onPlay: onPlay
                                )
                                .id(segment.id)
                            }
                        }
                        .padding(MeetcoTheme.Spacing.xLarge)
                        .frame(maxWidth: 780)
                        .frame(maxWidth: .infinity)
                    }
                    .onAppear { focusSegment(using: proxy) }
                    .onChange(of: focusedSegmentID) { _, _ in focusSegment(using: proxy) }
                }
            }
        }
        .searchable(text: $query, prompt: "Search transcript")
    }

    private var filteredSegments: [TranscriptSegment] {
        guard !query.isEmpty else { return segments }
        return segments.filter {
            $0.text.localizedStandardContains(query)
                || ($0.speakerName?.localizedStandardContains(query) ?? false)
        }
    }

    private func focusSegment(using proxy: ScrollViewProxy) {
        guard let focusedSegmentID else { return }
        query = ""
        withAnimation(MeetcoMotion.panel(reduceMotion: reduceMotion)) {
            proxy.scrollTo(focusedSegmentID, anchor: .center)
        }
    }
}

private struct TranscriptEditorRow: View {
    @State private var speaker: String
    @State private var text: String
    private let segment: TranscriptSegment
    private let isFocused: Bool
    private let hasAudio: Bool
    private let onEdit: (UUID, String, String) -> Void
    private let onPlay: (Int64) -> Void

    init(
        segment: TranscriptSegment,
        isFocused: Bool,
        hasAudio: Bool,
        onEdit: @escaping (UUID, String, String) -> Void,
        onPlay: @escaping (Int64) -> Void
    ) {
        self.segment = segment
        self.isFocused = isFocused
        self.hasAudio = hasAudio
        self.onEdit = onEdit
        self.onPlay = onPlay
        _speaker = State(initialValue: segment.speakerName ?? segment.speakerID ?? "Speaker")
        _text = State(initialValue: segment.text)
    }

    var body: some View {
        MeetcoCard {
            HStack(alignment: .top, spacing: MeetcoTheme.Spacing.medium) {
                if hasAudio {
                    Button { onPlay(segment.startMilliseconds) } label: {
                        timestampLabel(systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MeetcoTheme.accent)
                    .accessibilityLabel("Play audio at \(MeetcoFormatting.timestamp(milliseconds: segment.startMilliseconds))")
                } else {
                    timestampLabel(systemImage: "text.quote")
                        .foregroundStyle(MeetcoTheme.textSecondary)
                        .accessibilityLabel("Transcript at \(MeetcoFormatting.timestamp(milliseconds: segment.startMilliseconds)); audio not retained")
                }

                VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                    HStack {
                        TextField("Speaker", text: $speaker)
                            .textFieldStyle(.plain)
                            .font(.meetcoMetadata)
                            .onSubmit(commit)
                        Spacer()
                        StatusBadge(
                            segment.version == .final ? "Final" : "Provisional",
                            systemImage: segment.version == .final ? "checkmark.circle" : "clock",
                            tone: segment.version == .final ? .success : .warning
                        )
                    }
                    TextField("Transcript text", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.meetcoBody)
                        .lineLimit(1...8)
                        .onSubmit(commit)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card)
                .stroke(isFocused ? MeetcoTheme.accent : .clear, lineWidth: 2)
        }
        .onDisappear(perform: commit)
    }

    private func timestampLabel(systemImage: String) -> some View {
        VStack(spacing: MeetcoTheme.Spacing.small) {
            Image(systemName: systemImage).font(.system(size: 20))
            Text(MeetcoFormatting.timestamp(milliseconds: segment.startMilliseconds))
                .font(.caption2.monospacedDigit())
        }
    }

    private func commit() {
        guard speaker != (segment.speakerName ?? segment.speakerID ?? "Speaker") || text != segment.text else { return }
        onEdit(segment.id, text, speaker)
    }
}
