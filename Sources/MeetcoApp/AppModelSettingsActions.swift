import AppKit
import Foundation
import MeetcoCapture
import MeetcoCore

extension AppModel {
    func saveSettings() {
        guard let dependencies else { return }
        Task { try? await dependencies.settingsStore.save(settings) }
    }

    func updateDefaultConfiguration(_ configuration: MeetingConfiguration) {
        settings.defaultConfiguration = configuration
        draftConfiguration = configuration
        saveSettings()
    }

    func updateDefaultAgent(_ provider: AgentProviderKind) {
        settings.defaultConfiguration.agentProvider = provider
        draftConfiguration.agentProvider = provider
        saveSettings()
    }

    func updateAnthropicModel(_ model: String) {
        settings.anthropicModel = model
        saveSettings()
    }

    func setDefaultMCPEnabled(_ enabled: Bool) {
        settings.defaultConfiguration.mcpEnabled = enabled
        draftConfiguration.mcpEnabled = enabled
        saveSettings()
        if !enabled, session?.viewState.isActive != true {
            Task { try? await dependencies?.snapshotExporter.disable() }
        }
    }

    func revealStorage() {
        guard let url = dependencies?.paths.root else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyMCPConfiguration() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mcpConfigurationText, forType: .string)
    }

    func runMCPDiagnostics() {
        guard let executable = mcpExecutableURL,
              let dependencies else { return }
        Task {
            do {
                let request = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}"# + "\n"
                let result = try await ProcessRunner().run(.init(
                    executableURL: executable,
                    arguments: ["--snapshot", dependencies.paths.liveSnapshotURL.path],
                    standardInput: Data(request.utf8),
                    workingDirectory: dependencies.paths.root,
                    timeoutSeconds: 5
                ))
                guard result.exitCode == 0,
                      let line = result.standardOutput.split(separator: 0x0A).first,
                      let response = try? JSONDecoder().decode(MCPResponse.self, from: Data(line)),
                      response.error == nil else {
                    throw AgentProviderError.invalidResponse(
                        "MeetcoMCP did not complete its handshake."
                    )
                }
                mcpDiagnosticHealth = ProviderHealth(
                    state: .ready,
                    detail: "Bundled server handshake passed"
                )
            } catch {
                mcpDiagnosticHealth = ProviderHealth(
                    state: .unavailable,
                    detail: error.localizedDescription
                )
            }
        }
    }

    var mcpConfigurationText: String {
        let executable = mcpExecutableURL?.path ?? "MeetcoMCP"
        let snapshot = dependencies?.paths.liveSnapshotURL.path
            ?? "$HOME/Library/Application Support/Meetco/Live/current-meeting.json"
        let configuration: [String: Any] = [
            "mcpServers": [
                "meetco": [
                    "command": executable,
                    "args": ["--snapshot", snapshot],
                ],
            ],
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: configuration,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    var mcpExecutableURL: URL? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("MeetcoMCP", isDirectory: false)
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        return Bundle.main.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("MeetcoMCP", isDirectory: false)
    }

    func requestPermission(_ id: String) {
        guard let permissions = dependencies?.permissions else { return }
        Task {
            if id == "microphone" {
                _ = await permissions.requestMicrophoneAccess()
            } else if id == "screen" {
                _ = permissions.requestScreenRecordingAccess()
            }
            await refreshDiagnostics()
        }
    }

    func openPermissionSettings(_ id: String) {
        if id == "microphone" { openMicrophoneSettings() }
        else { openScreenRecordingSettings() }
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        isOnboardingPresented = false
        saveSettings()
    }

    func advanceOnboarding() {
        if onboardingStep == .intelligence {
            completeOnboarding()
        } else if let next = OnboardingStep(rawValue: onboardingStep.rawValue + 1) {
            onboardingStep = next
        }
    }

    func retreatOnboarding() {
        if let previous = OnboardingStep(rawValue: onboardingStep.rawValue - 1) {
            onboardingStep = previous
        }
    }

    func selectOnboardingAgent(_ provider: AgentProviderKind) {
        settings.defaultConfiguration.agentProvider = provider
        draftConfiguration.agentProvider = provider
        saveSettings()
    }

    func saveSecret(_ value: String, for identifier: SecretIdentifier) {
        guard let dependencies else { return }
        do {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try dependencies.keychain.deleteSecret(for: identifier)
            } else {
                try dependencies.keychain.setSecret(trimmed, for: identifier)
            }
            Task { await refreshDiagnostics() }
        } catch {
            startupError = error.localizedDescription
        }
    }

    func refreshDiagnostics() async {
        guard let dependencies else { return }
        captureStatus = CaptureStatus(
            microphone: dependencies.permissions.microphoneAvailability(),
            systemAudio: dependencies.permissions.systemAudioAvailability()
        )
        hasElevenLabsKey = ((try? dependencies.keychain.secret(for: .elevenLabsAPIKey)) ?? nil) != nil
        hasAnthropicKey = ((try? dependencies.keychain.secret(for: .anthropicAPIKey)) ?? nil) != nil
        async let claudeAPI = dependencies.agents.health(for: .claudeAPI)
        async let claudeCLI = dependencies.agents.health(for: .claudeCLI)
        async let codexCLI = dependencies.agents.health(for: .codexCLI)
        providerHealth = await [
            .claudeAPI: claudeAPI,
            .claudeCLI: claudeCLI,
            .codexCLI: codexCLI,
        ]
    }

    func openMicrophoneSettings() {
        dependencies?.permissions.openMicrophoneSettings()
    }

    func openScreenRecordingSettings() {
        dependencies?.permissions.openScreenRecordingSettings()
    }
}
