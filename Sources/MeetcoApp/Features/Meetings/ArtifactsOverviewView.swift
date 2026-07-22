import MeetcoCore
import SwiftUI

public struct ArtifactsOverviewView: View {
    public let artifacts: MeetingArtifacts
    public let onOpenEvidence: (EvidenceReference) -> Void
    public let onToggleAction: (UUID) -> Void
    public let onRegenerate: () -> Void

    public init(
        artifacts: MeetingArtifacts,
        onOpenEvidence: @escaping (EvidenceReference) -> Void,
        onToggleAction: @escaping (UUID) -> Void,
        onRegenerate: @escaping () -> Void
    ) {
        self.artifacts = artifacts
        self.onOpenEvidence = onOpenEvidence
        self.onToggleAction = onToggleAction
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        if isEmpty {
            EmptyStateView(
                title: "No generated notes",
                message: "Generate meeting-grounded notes when a transcript is available.",
                systemImage: "sparkles",
                actionTitle: "Generate notes",
                action: onRegenerate
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), alignment: .top)], spacing: 16) {
                    if !artifacts.summary.isEmpty {
                        artifactCard(title: "Summary", icon: "text.alignleft") {
                            Text(artifacts.summary).textSelection(.enabled)
                        }
                    }
                    linkedTextCard("Key points", icon: "list.bullet", items: artifacts.keyPoints)
                    linkedTextCard("Decisions", icon: "checkmark.seal", items: artifacts.decisions)
                    actionCard
                    linkedTextCard("Open questions", icon: "questionmark.bubble", items: artifacts.openQuestions)
                    linkedTextCard("Risks", icon: "exclamationmark.triangle", items: artifacts.risks)
                    if let draft = artifacts.followUpDraft, !draft.isEmpty {
                        artifactCard(title: "Follow-up draft", icon: "paperplane") {
                            Text(draft).textSelection(.enabled)
                        }
                    }
                }
                .padding(MeetcoTheme.Spacing.xLarge)
            }
        }
    }

    @ViewBuilder private func linkedTextCard(
        _ title: String,
        icon: String,
        items: [EvidenceLinkedText]
    ) -> some View {
        if !items.isEmpty {
            artifactCard(title: title, icon: icon) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                        Text(item.text).font(.meetcoBody).textSelection(.enabled)
                        EvidenceLink(
                            milliseconds: item.evidence.startMilliseconds,
                            count: item.evidence.segmentIDs.count
                        ) { onOpenEvidence(item.evidence) }
                    }
                    if item.id != items.last?.id { Divider() }
                }
            }
        }
    }

    @ViewBuilder private var actionCard: some View {
        if !artifacts.actionItems.isEmpty {
            artifactCard(title: "Actions", icon: "checklist") {
                ForEach(artifacts.actionItems) { item in
                    HStack(alignment: .top, spacing: MeetcoTheme.Spacing.small) {
                        Button { onToggleAction(item.id) } label: {
                            Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.status == .completed ? "Mark incomplete" : "Mark complete")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.meetcoBody)
                            HStack(spacing: MeetcoTheme.Spacing.small) {
                                if let owner = item.owner { Text(owner) }
                                if let due = item.dueDate { Text(due, style: .date) }
                                EvidenceLink(
                                    milliseconds: item.evidence.startMilliseconds,
                                    count: item.evidence.segmentIDs.count
                                ) { onOpenEvidence(item.evidence) }
                            }
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func artifactCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        MeetcoCard {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.medium) {
                Label(title, systemImage: icon).font(.meetcoSection)
                content()
            }
        }
    }

    private var isEmpty: Bool {
        artifacts.summary.isEmpty && artifacts.keyPoints.isEmpty && artifacts.decisions.isEmpty
            && artifacts.actionItems.isEmpty && artifacts.openQuestions.isEmpty && artifacts.risks.isEmpty
            && (artifacts.followUpDraft?.isEmpty ?? true)
    }
}
