import MeetcoCore
import SwiftUI

struct PreflightOutputPanel: View {
    let configuration: MeetingConfiguration
    let onChange: (MeetingConfiguration) -> Void

    var body: some View {
        MeetcoCard {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                PreflightSectionHeader(
                    title: "Keep & generate",
                    detail: "Pick the useful outputs for this meeting."
                )
                retentionControl
                Divider()
                Text("Meeting artifacts").font(.meetcoSection)
                ArtifactRecipeView(recipe: configuration.artifactRecipe) { option in
                    update { recipe in toggle(option, in: &recipe) }
                }
            }
        }
    }

    private var retentionControl: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Local retention").font(.meetcoSection)
                Text("Choose what remains after processing")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }
            Spacer(minLength: MeetcoTheme.Spacing.medium)
            Picker("Retention", selection: retentionBinding) {
                Text("Transcript only").tag(AudioRetention.transcriptOnly)
                Text("Transcript + audio").tag(AudioRetention.keepAudio)
                Text("Audio only").tag(AudioRetention.audioOnly)
            }
            .labelsHidden()
            .accessibilityLabel("Local retention")
            .frame(maxWidth: 180)
        }
    }

    private var retentionBinding: Binding<AudioRetention> {
        Binding(
            get: { configuration.audioRetention },
            set: { value in
                update {
                    $0.audioRetention = value
                    if value == .audioOnly {
                        $0.transcriptionMode = .recordOnly
                        $0.polishWithBatchAfterRealtime = false
                    } else if $0.transcriptionMode == .recordOnly {
                        $0.transcriptionMode = .afterMeeting
                    }
                }
            }
        )
    }

    private func update(_ transform: (inout MeetingConfiguration) -> Void) {
        var updated = configuration
        transform(&updated)
        onChange(updated)
    }

    private func toggle(_ option: ArtifactRecipeOption, in configuration: inout MeetingConfiguration) {
        switch option {
        case .summary: configuration.artifactRecipe.summary.toggle()
        case .keyPoints: configuration.artifactRecipe.keyPoints.toggle()
        case .decisions: configuration.artifactRecipe.decisions.toggle()
        case .actionItems: configuration.artifactRecipe.actionItems.toggle()
        case .openQuestions: configuration.artifactRecipe.openQuestions.toggle()
        case .risks: configuration.artifactRecipe.risks.toggle()
        case .followUpDraft: configuration.artifactRecipe.followUpDraft.toggle()
        }
    }
}

struct PreflightProviderPanel: View {
    let state: RecordingPreflightState
    let onOpenConnections: () -> Void

    var body: some View {
        MeetcoCard {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                PreflightSectionHeader(
                    title: "Provider check",
                    detail: "Repair anything needed before starting."
                )
                if showsTranscriptionProvider {
                    ProviderStatusView(
                        name: "ElevenLabs Scribe",
                        health: state.transcriptionHealth,
                        repairTitle: "Configure",
                        onRepair: onOpenConnections
                    )
                }
                if let agentHealth = state.agentHealth, state.configuration.agentProvider != .none {
                    if showsTranscriptionProvider { Divider() }
                    ProviderStatusView(
                        name: MeetcoFormatting.provider(state.configuration.agentProvider),
                        health: agentHealth,
                        repairTitle: "Configure",
                        onRepair: onOpenConnections
                    )
                }
                if showsAnyProvider { Divider() }
                Label(state.localStorageDetail, systemImage: "internaldrive")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var showsTranscriptionProvider: Bool {
        state.configuration.transcriptionMode != .recordOnly
    }

    private var showsAnyProvider: Bool {
        showsTranscriptionProvider
            || (state.agentHealth != nil && state.configuration.agentProvider != .none)
    }
}
