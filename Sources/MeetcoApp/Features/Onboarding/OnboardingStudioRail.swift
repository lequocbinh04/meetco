import SwiftUI

struct OnboardingStudioRail: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand

            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.small) {
                Text("Set up your studio")
                    .font(.meetcoTitle)
                    .foregroundStyle(MeetcoTheme.inkText)
                Text("Three short choices. Change any of them later.")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.inkTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 48)

            VStack(spacing: MeetcoTheme.Spacing.small) {
                stepRow(.localFirst, title: "Local capture", systemImage: "internaldrive")
                stepRow(.transcription, title: "Transcription", systemImage: "waveform.badge.mic")
                stepRow(.intelligence, title: "Meeting copilot", systemImage: "sparkles")
            }
            .padding(.top, MeetcoTheme.Spacing.xxLarge)

            Spacer()

            HStack(spacing: MeetcoTheme.Spacing.small) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(MeetcoTheme.success)
                Text("Credentials stay in Keychain")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.inkTextSecondary)
            }
        }
        .padding(MeetcoTheme.Spacing.xLarge)
        .frame(width: 250)
        .frame(maxHeight: .infinity, alignment: .leading)
        .background(MeetcoTheme.ink)
    }

    private var brand: some View {
        HStack(spacing: MeetcoTheme.Spacing.medium) {
            MeetcoBrandMark(size: 46)

            Text("Meetco")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MeetcoTheme.inkText)
        }
    }

    private func stepRow(_ item: OnboardingStep, title: String, systemImage: String) -> some View {
        let isSelected = step == item
        let isComplete = item.rawValue < step.rawValue
        return HStack(spacing: MeetcoTheme.Spacing.medium) {
            Image(systemName: isComplete ? "checkmark" : systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? MeetcoTheme.inkText : MeetcoTheme.inkTextSecondary)
                .frame(width: 30, height: 30)
                .background(isSelected ? MeetcoTheme.accent : MeetcoTheme.inkElevated)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? MeetcoTheme.inkText : MeetcoTheme.inkTextSecondary)
            Spacer()
        }
        .padding(.horizontal, MeetcoTheme.Spacing.small)
        .frame(minHeight: 46)
        .background(isSelected ? MeetcoTheme.inkElevated : .clear)
        .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
