import SwiftUI

public struct EvidenceLink: View {
    public let milliseconds: Int64?
    public let count: Int
    public let onOpen: () -> Void

    public init(milliseconds: Int64?, count: Int, onOpen: @escaping () -> Void) {
        self.milliseconds = milliseconds
        self.count = count
        self.onOpen = onOpen
    }

    public var body: some View {
        Button(action: onOpen) {
            Label(label, systemImage: "arrow.up.right")
                .font(.meetcoMetadata)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MeetcoTheme.accent)
        .accessibilityLabel(accessibilityLabel)
    }

    private var label: String {
        if let milliseconds {
            return MeetcoFormatting.timestamp(milliseconds: milliseconds)
        }
        return "\(count) source\(count == 1 ? "" : "s")"
    }

    private var accessibilityLabel: String {
        if let milliseconds {
            return "Jump to transcript at \(MeetcoFormatting.timestamp(milliseconds: milliseconds))"
        }
        return "Open \(count) transcript source\(count == 1 ? "" : "s")"
    }
}
