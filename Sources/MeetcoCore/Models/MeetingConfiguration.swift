import Foundation

public enum CaptureMode: String, Codable, CaseIterable, Hashable, Sendable {
    case online
    case onSite
}

public enum TranscriptionMode: String, Codable, CaseIterable, Hashable, Sendable {
    case realtime
    case afterMeeting
    case recordOnly
}

public enum AudioRetention: String, Codable, CaseIterable, Hashable, Sendable {
    case transcriptOnly
    case keepAudio
    case audioOnly
}

public enum AgentProviderKind: String, Codable, CaseIterable, Hashable, Sendable {
    case claudeAPI
    case claudeCLI
    case codexCLI
    case none
}

public struct ArtifactRecipe: Codable, Equatable, Sendable {
    public var summary: Bool
    public var keyPoints: Bool
    public var decisions: Bool
    public var actionItems: Bool
    public var openQuestions: Bool
    public var risks: Bool
    public var followUpDraft: Bool

    public init(
        summary: Bool = true,
        keyPoints: Bool = true,
        decisions: Bool = true,
        actionItems: Bool = true,
        openQuestions: Bool = true,
        risks: Bool = false,
        followUpDraft: Bool = false
    ) {
        self.summary = summary
        self.keyPoints = keyPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.risks = risks
        self.followUpDraft = followUpDraft
    }
}

public struct MeetingConfiguration: Codable, Equatable, Sendable {
    public var captureMode: CaptureMode
    public var transcriptionMode: TranscriptionMode
    public var audioRetention: AudioRetention
    public var agentProvider: AgentProviderKind
    public var artifactRecipe: ArtifactRecipe
    public var mcpEnabled: Bool
    public var languageCode: String?
    public var keyterms: [String]
    public var polishWithBatchAfterRealtime: Bool

    public init(
        captureMode: CaptureMode = .online,
        transcriptionMode: TranscriptionMode = .realtime,
        audioRetention: AudioRetention = .keepAudio,
        agentProvider: AgentProviderKind = .claudeAPI,
        artifactRecipe: ArtifactRecipe = .init(),
        mcpEnabled: Bool = false,
        languageCode: String? = nil,
        keyterms: [String] = [],
        polishWithBatchAfterRealtime: Bool = true
    ) {
        self.captureMode = captureMode
        self.transcriptionMode = transcriptionMode
        self.audioRetention = audioRetention
        self.agentProvider = agentProvider
        self.artifactRecipe = artifactRecipe
        self.mcpEnabled = mcpEnabled
        self.languageCode = languageCode
        self.keyterms = Array(keyterms.prefix(50))
        self.polishWithBatchAfterRealtime = polishWithBatchAfterRealtime
    }

    public func normalizedForSession() -> MeetingConfiguration {
        var result = self
        if result.transcriptionMode == .recordOnly || result.audioRetention == .audioOnly {
            result.transcriptionMode = .recordOnly
            result.audioRetention = .audioOnly
            result.polishWithBatchAfterRealtime = false
        }
        result.keyterms = ScribeKeyterms.realtime(result.keyterms)
        result.languageCode = result.languageCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        return result
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
