import SwiftUI

/// Renders copilot text that cites transcript segments as raw `[UUID]`
/// brackets: the UUIDs are replaced with compact numbered markers and
/// surfaced as tappable evidence chips underneath.
public struct EvidenceCitedText: View {
    public let text: String
    public let onOpenEvidence: (UUID) -> Void

    private let parsed: ParsedCitations

    public init(_ text: String, onOpenEvidence: @escaping (UUID) -> Void) {
        self.text = text
        self.onOpenEvidence = onOpenEvidence
        self.parsed = ParsedCitations(text)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
            Text(parsed.displayText)
                .font(.meetcoBody)
                .textSelection(.enabled)

            if !parsed.citations.isEmpty {
                HStack(spacing: MeetcoTheme.Spacing.xSmall) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MeetcoTheme.textSecondary)
                    ForEach(Array(parsed.citations.enumerated()), id: \.element) { index, id in
                        Button {
                            onOpenEvidence(id)
                        } label: {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(MeetcoTheme.accent)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(MeetcoTheme.accentSoft)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Open transcript source \(index + 1)")
                        .accessibilityLabel("Open transcript source \(index + 1)")
                    }
                }
            }
        }
    }
}

/// Splits `[8-4-4-4-12 hex]` citations out of the text, replacing each with a
/// stable numbered marker so the prose stays readable.
struct ParsedCitations {
    let displayText: String
    let citations: [UUID]

    init(_ text: String) {
        var citations: [UUID] = []
        var markerByID: [UUID: Int] = [:]
        var display = ""
        var cursor = text.startIndex

        let pattern = /\[([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\]/
        for match in text.matches(of: pattern) {
            display += text[cursor..<match.range.lowerBound]
            if let id = UUID(uuidString: String(match.output.1)) {
                let marker: Int
                if let existing = markerByID[id] {
                    marker = existing
                } else {
                    citations.append(id)
                    marker = citations.count
                    markerByID[id] = marker
                }
                // Collapse "…text [1][1]" noise from adjacent duplicate citations.
                if !display.hasSuffix("[\(marker)]") {
                    display += "[\(marker)]"
                }
            }
            cursor = match.range.upperBound
        }
        display += text[cursor...]

        self.displayText = display.trimmingCharacters(in: .whitespacesAndNewlines)
        self.citations = citations
    }
}
