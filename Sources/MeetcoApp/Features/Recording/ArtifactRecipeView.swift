import MeetcoCore
import SwiftUI

public enum ArtifactRecipeOption: String, CaseIterable, Identifiable, Sendable {
    case summary
    case keyPoints
    case decisions
    case actionItems
    case openQuestions
    case risks
    case followUpDraft

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .summary: "Summary"
        case .keyPoints: "Key points"
        case .decisions: "Decisions"
        case .actionItems: "Actions"
        case .openQuestions: "Questions"
        case .risks: "Risks"
        case .followUpDraft: "Follow-up"
        }
    }

    public var systemImage: String {
        switch self {
        case .summary: "text.alignleft"
        case .keyPoints: "list.bullet"
        case .decisions: "checkmark.seal"
        case .actionItems: "checklist"
        case .openQuestions: "questionmark.bubble"
        case .risks: "exclamationmark.triangle"
        case .followUpDraft: "paperplane"
        }
    }
}

public struct ArtifactRecipeView: View {
    public let recipe: ArtifactRecipe
    public let onToggle: (ArtifactRecipeOption) -> Void

    public init(recipe: ArtifactRecipe, onToggle: @escaping (ArtifactRecipeOption) -> Void) {
        self.recipe = recipe
        self.onToggle = onToggle
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
            ForEach(ArtifactRecipeOption.allCases) { option in
                Button { onToggle(option) } label: {
                    HStack(spacing: MeetcoTheme.Spacing.small) {
                        Image(systemName: option.systemImage)
                        Text(option.label)
                        Spacer(minLength: 0)
                        if isEnabled(option) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .font(.meetcoMetadata)
                    .foregroundStyle(isEnabled(option) ? MeetcoTheme.accent : MeetcoTheme.textSecondary)
                    .padding(.horizontal, MeetcoTheme.Spacing.medium)
                    .frame(minHeight: 36)
                    .background(isEnabled(option) ? MeetcoTheme.accentSoft : MeetcoTheme.surfaceMuted.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                            .stroke(isEnabled(option) ? MeetcoTheme.accent.opacity(0.42) : Color.clear)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isEnabled(option) ? .isSelected : [])
            }
        }
        .accessibilityLabel("Generated artifacts")
    }

    private func isEnabled(_ option: ArtifactRecipeOption) -> Bool {
        switch option {
        case .summary: recipe.summary
        case .keyPoints: recipe.keyPoints
        case .decisions: recipe.decisions
        case .actionItems: recipe.actionItems
        case .openQuestions: recipe.openQuestions
        case .risks: recipe.risks
        case .followUpDraft: recipe.followUpDraft
        }
    }
}
