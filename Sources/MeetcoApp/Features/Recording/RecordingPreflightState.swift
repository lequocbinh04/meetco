import MeetcoCore

public struct RecordingPreflightState: Equatable, Sendable {
    public let configuration: MeetingConfiguration
    public let transcriptionHealth: ProviderHealth
    public let agentHealth: ProviderHealth?
    public let localStorageDetail: String
    public let canStart: Bool
    public let blockingReason: String?

    public init(
        configuration: MeetingConfiguration,
        transcriptionHealth: ProviderHealth,
        agentHealth: ProviderHealth?,
        localStorageDetail: String,
        canStart: Bool,
        blockingReason: String? = nil
    ) {
        self.configuration = configuration
        self.transcriptionHealth = transcriptionHealth
        self.agentHealth = agentHealth
        self.localStorageDetail = localStorageDetail
        self.canStart = canStart
        self.blockingReason = blockingReason
    }
}
