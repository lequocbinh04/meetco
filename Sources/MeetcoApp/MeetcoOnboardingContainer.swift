import MeetcoCore
import SwiftUI

struct MeetcoOnboardingContainer: View {
    @ObservedObject var model: AppModel
    @State private var showsPrivacyDetails = false

    var body: some View {
        OnboardingView(
            state: MeetcoViewStateFactory.onboarding(model),
            onBack: model.retreatOnboarding,
            onContinue: model.advanceOnboarding,
            onSkip: model.completeOnboarding,
            onSaveTranscriptionKey: { model.saveSecret($0, for: .elevenLabsAPIKey) },
            onSelectAgent: model.selectOnboardingAgent,
            onOpenPrivacy: { showsPrivacyDetails = true }
        )
        .sheet(isPresented: $showsPrivacyDetails) {
            MeetcoPrivacyDetailsView()
        }
    }
}
