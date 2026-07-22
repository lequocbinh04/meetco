import MeetcoCore
import SwiftUI

public struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transcriptionKey = ""

    public let state: OnboardingViewState
    public let onBack: () -> Void
    public let onContinue: () -> Void
    public let onSkip: () -> Void
    public let onSaveTranscriptionKey: (String) -> Void
    public let onSelectAgent: (AgentProviderKind) -> Void
    public let onOpenPrivacy: () -> Void

    public init(
        state: OnboardingViewState,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onSaveTranscriptionKey: @escaping (String) -> Void,
        onSelectAgent: @escaping (AgentProviderKind) -> Void,
        onOpenPrivacy: @escaping () -> Void
    ) {
        self.state = state
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onSaveTranscriptionKey = onSaveTranscriptionKey
        self.onSelectAgent = onSelectAgent
        self.onOpenPrivacy = onOpenPrivacy
    }

    public var body: some View {
        HStack(spacing: 0) {
            OnboardingStudioRail(step: state.step)

            VStack(spacing: 0) {
                Group {
                    switch state.step {
                    case .localFirst: localFirstPanel
                    case .transcription: transcriptionPanel
                    case .intelligence: intelligencePanel
                    }
                }
                .id(state.step)
                .transition(MeetcoMotion.replacement(reduceMotion: reduceMotion))
                .animation(MeetcoMotion.panel(reduceMotion: reduceMotion), value: state.step)

                footer
            }
            .background(MeetcoTheme.canvas)
        }
        .frame(minWidth: 820, minHeight: 600)
    }

    private var localFirstPanel: some View {
        panel(
            icon: "lock.shield.fill",
            title: "Your meetings, on your Mac",
            message: "Meetco records to local storage first. Transcription and intelligence are optional layers you control."
        ) {
            VStack(spacing: MeetcoTheme.Spacing.medium) {
                principle("Audio starts local", "Capture is closed safely before final processing.", "internaldrive.fill")
                principle("No Meetco account", "Provider credentials stay in macOS Keychain.", "key.fill")
                principle("Evidence stays attached", "Generated claims can jump back to the transcript.", "quote.bubble.fill")
            }
            Button("Read privacy details", action: onOpenPrivacy)
                .buttonStyle(.link)
        }
    }

    private var transcriptionPanel: some View {
        panel(
            icon: "waveform.badge.mic",
            title: "Connect live transcription",
            message: "ElevenLabs Scribe is used only when you choose Live or After meeting transcription. Recording still works without it."
        ) {
            MeetcoCard {
                VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                    ProviderStatusView(name: "ElevenLabs Scribe", health: state.transcriptionHealth)
                    SecureField("ElevenLabs API key", text: $transcriptionKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("ElevenLabs API key")
                    HStack {
                        Label("Saved securely in Keychain", systemImage: "lock.fill")
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                        Spacer()
                        Button("Save key") {
                            onSaveTranscriptionKey(transcriptionKey)
                            transcriptionKey = ""
                        }
                        .disabled(transcriptionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var intelligencePanel: some View {
        panel(
            icon: "sparkles",
            title: "Choose your meeting copilot",
            message: "A provider receives meeting context only when you ask or generate artifacts. You can change this for each recording."
        ) {
            VStack(spacing: MeetcoTheme.Spacing.small) {
                ForEach(AgentProviderKind.allCases, id: \.self) { provider in
                    Button { onSelectAgent(provider) } label: {
                        HStack {
                            Image(systemName: provider == .none ? "sparkles.slash" : "sparkles")
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MeetcoFormatting.provider(provider)).font(.meetcoSection)
                                Text(providerDescription(provider))
                                    .font(.meetcoMetadata)
                                    .foregroundStyle(MeetcoTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: state.selectedAgent == provider ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(state.selectedAgent == provider ? MeetcoTheme.accent : MeetcoTheme.textSecondary)
                        }
                        .padding(MeetcoTheme.Spacing.medium)
                        .background(state.selectedAgent == provider ? MeetcoTheme.accentSoft : MeetcoTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control)
                                .stroke(state.selectedAgent == provider ? MeetcoTheme.accent : MeetcoTheme.border)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(state.selectedAgent == provider ? .isSelected : [])
                }
                if let health = state.agentHealth, state.selectedAgent != .none {
                    ProviderStatusView(name: MeetcoFormatting.provider(state.selectedAgent), health: health)
                        .padding(.top, MeetcoTheme.Spacing.small)
                }
            }
        }
    }

    private func panel<Content: View>(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: MeetcoTheme.Spacing.xLarge) {
            Spacer(minLength: MeetcoTheme.Spacing.large)
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(MeetcoTheme.accent)
            VStack(spacing: MeetcoTheme.Spacing.small) {
                Text(title).font(.meetcoDisplay)
                Text(message)
                    .font(.meetcoBody)
                    .foregroundStyle(MeetcoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            content().frame(maxWidth: 540)
            Spacer(minLength: MeetcoTheme.Spacing.large)
        }
        .padding(.horizontal, MeetcoTheme.Spacing.xLarge)
    }

    private func principle(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(spacing: MeetcoTheme.Spacing.medium) {
            Image(systemName: icon).foregroundStyle(MeetcoTheme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.meetcoSection)
                Text(detail).font(.meetcoMetadata).foregroundStyle(MeetcoTheme.textSecondary)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            if state.step != .localFirst {
                Button(action: onBack) {
                    Text("Back").frame(minWidth: 52)
                }
                .buttonStyle(MeetcoSecondaryButtonStyle())
            }
            Spacer()
            Button(action: onSkip) {
                Text("Skip for now").frame(minWidth: 104)
            }
            .buttonStyle(MeetcoSecondaryButtonStyle())
            Button(action: onContinue) {
                Text(state.step == .intelligence ? "Finish" : "Continue")
                    .frame(minWidth: 104)
            }
                .buttonStyle(MeetcoActionButtonStyle())
                .disabled(!state.canContinue)
                .keyboardShortcut(.defaultAction)
        }
        .padding(MeetcoTheme.Spacing.large)
        .background(MeetcoTheme.surface)
        .overlay(alignment: .top) { Divider() }
    }

    private func providerDescription(_ provider: AgentProviderKind) -> String {
        switch provider {
        case .claudeAPI: "Uses your Anthropic API key"
        case .claudeCLI: "Uses your existing Claude CLI login"
        case .codexCLI: "Uses your existing Codex CLI login"
        case .none: "Record and transcribe without an agent"
        }
    }
}
