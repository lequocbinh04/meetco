import SwiftUI

struct MeetcoPrivacyDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.xLarge) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(MeetcoTheme.accent)
                Text("Local-first by design").font(.meetcoTitle)
                Spacer()
            }
            privacyRow(
                "Recording",
                "Microphone and system audio are written to your Mac before any optional processing.",
                "internaldrive.fill"
            )
            privacyRow(
                "Transcription",
                "Audio is sent to ElevenLabs only when Live or After meeting transcription is selected.",
                "waveform.badge.mic"
            )
            privacyRow(
                "Copilot",
                "Meeting context is sent only to the agent provider you choose when chat or artifact generation runs.",
                "sparkles"
            )
            privacyRow(
                "Credentials",
                "API keys are stored in macOS Keychain. CLI providers use their existing local login.",
                "key.fill"
            )
            Spacer()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(MeetcoTheme.Spacing.xLarge)
        .frame(width: 620, height: 460)
        .background(MeetcoTheme.canvas)
    }

    private func privacyRow(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: MeetcoTheme.Spacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(MeetcoTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.meetcoSection)
                Text(detail)
                    .font(.meetcoBody)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }
        }
    }
}
