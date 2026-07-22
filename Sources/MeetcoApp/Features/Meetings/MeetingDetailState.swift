import Foundation
import MeetcoCore

public struct FinalizationStageState: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case pending
        case running
        case completed
        case failed(String)
    }

    public let id: String
    public let title: String
    public let status: Status

    public init(id: String, title: String, status: Status) {
        self.id = id
        self.title = title
        self.status = status
    }
}

public struct MeetingDetailState: Equatable, Sendable {
    public let snapshot: MeetingContextSnapshot
    public let finalizationStages: [FinalizationStageState]
    public let providerHealth: ProviderHealth?
    public let isAgentResponding: Bool
    public let isTranscriptionRetrying: Bool

    public init(
        snapshot: MeetingContextSnapshot,
        finalizationStages: [FinalizationStageState],
        providerHealth: ProviderHealth?,
        isAgentResponding: Bool,
        isTranscriptionRetrying: Bool = false
    ) {
        self.snapshot = snapshot
        self.finalizationStages = finalizationStages
        self.providerHealth = providerHealth
        self.isAgentResponding = isAgentResponding
        self.isTranscriptionRetrying = isTranscriptionRetrying
    }
}

public enum MeetingDetailTab: String, CaseIterable, Identifiable, Sendable {
    case overview = "Overview"
    case transcript = "Transcript"
    case notes = "Notes"
    case chat = "Chat"

    public var id: String { rawValue }
}
