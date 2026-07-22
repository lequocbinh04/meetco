import SwiftUI

public struct MeetingListView: View {
    @State private var query = ""
    public let state: MeetingListState
    public let onSelect: (UUID) -> Void
    public let onNewRecording: () -> Void

    public init(
        state: MeetingListState,
        onSelect: @escaping (UUID) -> Void,
        onNewRecording: @escaping () -> Void
    ) {
        self.state = state
        self.onSelect = onSelect
        self.onNewRecording = onNewRecording
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !state.meetings.isEmpty {
                searchField
                    .padding(.horizontal, MeetcoTheme.Spacing.large)
                    .padding(.top, MeetcoTheme.Spacing.medium)
                    .padding(.bottom, MeetcoTheme.Spacing.small)
            }
            listContent
        }
        .navigationTitle("Meetings")
    }

    // Inline field keeps search visually inside the list column; the toolbar
    // variant floats over the detail pane when the title bar is hidden.
    private var searchField: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MeetcoTheme.textSecondary)
            TextField("Search meetings", text: $query)
                .textFieldStyle(.plain)
                .font(.meetcoBody)
        }
        .padding(.horizontal, MeetcoTheme.Spacing.medium)
        .frame(minHeight: 34)
        .background(MeetcoTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                .strokeBorder(MeetcoTheme.border.opacity(0.6))
        }
        .accessibilityLabel("Search meetings")
    }

    @ViewBuilder private var listContent: some View {
        Group {
            if state.meetings.isEmpty {
                EmptyStateView(
                    title: "No meetings",
                    message: "Your local meeting library will appear here.",
                    systemImage: "waveform",
                    actionTitle: "New recording",
                    action: onNewRecording
                )
            } else if filteredMeetings.isEmpty {
                EmptyStateView(
                    title: "No matches",
                    message: "Try a different title or clear the search.",
                    systemImage: "magnifyingglass"
                )
            } else {
                List(filteredMeetings, selection: selection) { item in
                    RecentMeetingRow(state: RecentMeetingState(
                        meeting: item.meeting,
                        actionCount: item.actionCount,
                        transcriptVersion: item.transcriptVersion
                    )) { onSelect(item.id) }
                    .tag(item.id)
                    .padding(.vertical, MeetcoTheme.Spacing.small)
                }
                .listStyle(.inset)
                .contentMargins(.top, MeetcoTheme.Spacing.xSmall, for: .scrollContent)
            }
        }
    }

    private var filteredMeetings: [MeetingListItemState] {
        guard !query.isEmpty else { return state.meetings }
        return state.meetings.filter { $0.meeting.title.localizedStandardContains(query) }
    }

    private var selection: Binding<UUID?> {
        Binding(
            get: { state.selectedMeetingID },
            set: { id in if let id { onSelect(id) } }
        )
    }
}
