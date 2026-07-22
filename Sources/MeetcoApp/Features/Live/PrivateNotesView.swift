import SwiftUI

public struct PrivateNotesView: View {
    @State private var draft: String
    public let onChange: (String) -> Void

    public init(notes: String, onChange: @escaping (String) -> Void) {
        _draft = State(initialValue: notes)
        self.onChange = onChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Private notes", systemImage: "lock.fill")
                    .font(.meetcoSection)
                Spacer()
                Text("Local")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }
            .padding(MeetcoTheme.Spacing.medium)
            Divider()
            TextEditor(text: $draft)
                .font(.meetcoBody)
                .scrollContentBackground(.hidden)
                .padding(MeetcoTheme.Spacing.small)
                .onChange(of: draft) { _, value in onChange(value) }
                .accessibilityLabel("Private meeting notes")
        }
        .background(MeetcoTheme.surface)
    }
}
