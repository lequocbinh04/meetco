import MeetcoCore
import SwiftUI

public struct RecordingSettingsView: View {
    @State private var keytermsText: String
    @FocusState private var keytermsFocused: Bool
    public let state: RecordingSettingsState
    public let onConfigurationChange: (MeetingConfiguration) -> Void
    public let onRevealStorage: () -> Void

    public init(
        state: RecordingSettingsState,
        onConfigurationChange: @escaping (MeetingConfiguration) -> Void,
        onRevealStorage: @escaping () -> Void
    ) {
        self.state = state
        self.onConfigurationChange = onConfigurationChange
        self.onRevealStorage = onRevealStorage
        self._keytermsText = State(initialValue: state.configuration.keyterms.joined(separator: ", "))
    }

    public var body: some View {
        SettingsPage {
            SettingsPanel(
                "Default capture",
                detail: "These choices prefill every new recording.",
                systemImage: "record.circle"
            ) {
                SettingsLabeledRow("Capture mode") {
                    Picker("Capture mode", selection: binding(\.captureMode)) {
                        Text("Online meeting").tag(CaptureMode.online)
                        Text("On-site").tag(CaptureMode.onSite)
                    }
                    .labelsHidden()
                }
                Divider()
                SettingsLabeledRow("Transcription") {
                    Picker("Transcription", selection: transcriptionModeBinding) {
                        Text("Live").tag(TranscriptionMode.realtime)
                        Text("After meeting").tag(TranscriptionMode.afterMeeting)
                        Text("Audio only").tag(TranscriptionMode.recordOnly)
                    }
                    .labelsHidden()
                }
                Divider()
                SettingsLabeledRow("Local retention") {
                    Picker("Local retention", selection: retentionBinding) {
                        Text("Transcript only").tag(AudioRetention.transcriptOnly)
                        Text("Keep audio locally").tag(AudioRetention.keepAudio)
                        Text("Audio only").tag(AudioRetention.audioOnly)
                    }
                    .labelsHidden()
                }
                Divider()
                Toggle("Polish live transcript after the meeting", isOn: binding(\.polishWithBatchAfterRealtime))
            }

            SettingsPanel(
                "Language & vocabulary",
                detail: "Optional hints improve names and domain terminology.",
                systemImage: "textformat.abc"
            ) {
                TextField("Language code (automatic when empty)", text: optionalStringBinding(\.languageCode))
                    .textFieldStyle(MeetcoSettingsTextFieldStyle())
                TextField("Key terms, separated by commas", text: $keytermsText)
                    .textFieldStyle(MeetcoSettingsTextFieldStyle())
                    .focused($keytermsFocused)
                    .onSubmit(commitKeyterms)
                    .onChange(of: keytermsFocused) { _, focused in
                        if !focused { commitKeyterms() }
                    }
                Text("Up to 50 key terms are sent only to the selected transcription provider.")
                    .font(.meetcoMetadata)
                    .foregroundStyle(MeetcoTheme.textSecondary)
            }

            SettingsPanel(
                "Local storage",
                detail: "Meeting files remain under your user Library.",
                systemImage: "internaldrive"
            ) {
                SettingsLabeledRow("Location") {
                    Text(state.storageLocation)
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Button("Reveal in Finder", systemImage: "folder", action: onRevealStorage)
            }
        }
        .onChange(of: state.configuration.keyterms) { _, keyterms in
            guard !keytermsFocused else { return }
            keytermsText = keyterms.joined(separator: ", ")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<MeetingConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { state.configuration[keyPath: keyPath] },
            set: { value in update { $0[keyPath: keyPath] = value } }
        )
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<MeetingConfiguration, String?>) -> Binding<String> {
        Binding(
            get: { state.configuration[keyPath: keyPath] ?? "" },
            set: { value in update { $0[keyPath: keyPath] = value.isEmpty ? nil : value } }
        )
    }

    private var transcriptionModeBinding: Binding<TranscriptionMode> {
        Binding(
            get: { state.configuration.transcriptionMode },
            set: { mode in
                update {
                    $0.transcriptionMode = mode
                    if mode == .recordOnly {
                        $0.audioRetention = .audioOnly
                        $0.polishWithBatchAfterRealtime = false
                    } else if $0.audioRetention == .audioOnly {
                        $0.audioRetention = .keepAudio
                    }
                }
            }
        )
    }

    private var retentionBinding: Binding<AudioRetention> {
        Binding(
            get: { state.configuration.audioRetention },
            set: { retention in
                update {
                    $0.audioRetention = retention
                    if retention == .audioOnly {
                        $0.transcriptionMode = .recordOnly
                        $0.polishWithBatchAfterRealtime = false
                    } else if $0.transcriptionMode == .recordOnly {
                        $0.transcriptionMode = .afterMeeting
                    }
                }
            }
        )
    }

    private func commitKeyterms() {
        let terms = keytermsText.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        let cappedTerms = ScribeKeyterms.realtime(terms)
        keytermsText = cappedTerms.joined(separator: ", ")
        update { $0.keyterms = cappedTerms }
    }

    private func update(_ transform: (inout MeetingConfiguration) -> Void) {
        var configuration = state.configuration
        transform(&configuration)
        onConfigurationChange(configuration)
    }
}
