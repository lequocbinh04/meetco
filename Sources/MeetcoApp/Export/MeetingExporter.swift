import Foundation
import MeetcoCore

public enum MeetingExportFormat: String, CaseIterable {
    case markdown
    case json
    case audio

    public var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .json: "json"
        case .audio: "wav"
        }
    }
}

enum MeetingExporterError: Error, LocalizedError {
    case audioUnavailable

    var errorDescription: String? { "This meeting has no retained audio to export." }
}

enum MeetingExporter {
    static func data(
        for snapshot: MeetingContextSnapshot,
        format: MeetingExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(snapshot)
        case .markdown:
            return Data(markdown(snapshot).utf8)
        case .audio:
            throw MeetingExporterError.audioUnavailable
        }
    }

    static func write(
        snapshot: MeetingContextSnapshot,
        format: MeetingExportFormat,
        audioURL: URL?,
        to destinationURL: URL
    ) throws {
        if format == .audio {
            guard let audioURL, LocalAudioInspection.hasUsableFinalMix(at: audioURL) else {
                throw MeetingExporterError.audioUnavailable
            }
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: audioURL, to: destinationURL)
        } else {
            try data(for: snapshot, format: format).write(to: destinationURL, options: .atomic)
        }
    }

    static func suggestedFileName(_ meeting: Meeting, format: MeetingExportFormat) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let title = meeting.title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(title.isEmpty ? "Meetco meeting" : title).\(format.fileExtension)"
    }

    private static func markdown(_ snapshot: MeetingContextSnapshot) -> String {
        var sections = [
            "# \(snapshot.meeting.title)",
            metadata(snapshot.meeting),
        ]
        if !snapshot.artifacts.summary.isEmpty {
            sections.append("## Summary\n\n\(snapshot.artifacts.summary)")
        }
        sections.append(listSection("Key points", snapshot.artifacts.keyPoints))
        sections.append(listSection("Decisions", snapshot.artifacts.decisions))
        sections.append(actionSection(snapshot.artifacts.actionItems))
        sections.append(listSection("Open questions", snapshot.artifacts.openQuestions))
        sections.append(listSection("Risks", snapshot.artifacts.risks))
        if let followUp = snapshot.artifacts.followUpDraft, !followUp.isEmpty {
            sections.append("## Follow-up draft\n\n\(followUp)")
        }
        if !snapshot.manualNotes.isEmpty {
            sections.append("## Private notes\n\n\(snapshot.manualNotes)")
        }
        if !snapshot.transcript.isEmpty {
            let lines = snapshot.transcript.map { segment in
                let speaker = segment.speakerName ?? segment.speakerID ?? "Speaker"
                return "**[\(time(segment.startMilliseconds))] \(speaker):** \(segment.text)"
            }
            sections.append("## Transcript\n\n" + lines.joined(separator: "\n\n"))
        }
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n") + "\n"
    }

    private static func metadata(_ meeting: Meeting) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "- Date: \(formatter.string(from: meeting.createdAt))\n- Duration: \(time(meeting.durationMilliseconds))\n- Status: \(meeting.status.rawValue)"
    }

    private static func listSection(_ title: String, _ values: [EvidenceLinkedText]) -> String {
        guard !values.isEmpty else { return "" }
        let items = values.map { "- \($0.text)\(evidenceSuffix($0.evidence))" }
        return "## \(title)\n\n" + items.joined(separator: "\n")
    }

    private static func actionSection(_ values: [ActionItem]) -> String {
        guard !values.isEmpty else { return "" }
        let items = values.map { action in
            var details = [action.owner.map { "Owner: \($0)" }]
            let formatter = ISO8601DateFormatter()
            details.append(action.dueDate.map { "Due: \(formatter.string(from: $0))" })
            let suffix = details.compactMap { $0 }.isEmpty
                ? ""
                : " — " + details.compactMap { $0 }.joined(separator: ", ")
            return "- [\(action.status == .completed ? "x" : " ")] \(action.title)\(suffix)\(evidenceSuffix(action.evidence))"
        }
        return "## Actions\n\n" + items.joined(separator: "\n")
    }

    private static func evidenceSuffix(_ evidence: EvidenceReference) -> String {
        if let start = evidence.startMilliseconds { return " (\(time(start)))" }
        return evidence.segmentIDs.isEmpty ? "" : " (\(evidence.segmentIDs.count) evidence link(s))"
    }

    private static func time(_ milliseconds: Int64) -> String {
        let seconds = max(0, milliseconds / 1_000)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
