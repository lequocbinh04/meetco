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
        guard let dependencies else { return }
        Task {
            do {
                // Exercise the same HTTP endpoint clients use.
                var request = URLRequest(
                    url: URL(string: dependencies.mcpHTTPServer.endpointURL)!
                )
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = Data(
                    #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}"#.utf8
                )
                request.timeoutInterval = 5
                let (data, urlResponse) = try await URLSession.shared.data(for: request)
                guard (urlResponse as? HTTPURLResponse)?.statusCode == 200,
                      let response = try? JSONDecoder().decode(MCPResponse.self, from: data),
                      response.error == nil else {
                    throw AgentProviderError.invalidResponse(
                        "MeetcoMCP did not complete its handshake."
                    )
                }
                mcpDiagnosticHealth = ProviderHealth(
                    state: .ready,
                    detail: "HTTP endpoint handshake passed"
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
        let endpoint = dependencies?.mcpHTTPServer.endpointURL
            ?? "http://127.0.0.1:\(MCPHTTPServer.defaultPort)/mcp"
        let configuration: [String: Any] = [
            "mcpServers": [
                "meetco": [
                    "type": "http",
                    "url": endpoint,
                ],
            ],
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: configuration,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
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
