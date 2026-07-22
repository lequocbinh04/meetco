import MeetcoCore

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case localFirst
    case transcription
    case intelligence
}

public struct OnboardingViewState: Equatable, Sendable {
    public let step: OnboardingStep
    public let transcriptionHealth: ProviderHealth
    public let selectedAgent: AgentProviderKind
    public let agentHealth: ProviderHealth?
    public let canContinue: Bool

    public init(
        step: OnboardingStep,
        transcriptionHealth: ProviderHealth,
        selectedAgent: AgentProviderKind,
        agentHealth: ProviderHealth?,
        canContinue: Bool
    ) {
        self.step = step
        self.transcriptionHealth = transcriptionHealth
        self.selectedAgent = selectedAgent
        self.agentHealth = agentHealth
        self.canContinue = canContinue
    }
}
