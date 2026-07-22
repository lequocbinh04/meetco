import Foundation
import MeetcoCapture
import MeetcoCore

struct AppDependencies: Sendable {
    let paths: ApplicationPaths
    let repository: MeetingRepository
    let settingsStore: SettingsStore
    let keychain: KeychainStore
    let capture: AudioCaptureCoordinator
    let realtime: ScribeRealtimeClient
    let batch: ScribeBatchClient
    let agents: AgentService
    let snapshotExporter: SnapshotExporter
    let permissions: CapturePermissionService
    let mcpHTTPServer: MCPHTTPServer

    static func live() throws -> AppDependencies {
        let paths = try ApplicationPaths.live()
        let repository = try MeetingRepository(paths: paths)
        let settingsStore = SettingsStore()
        let keychain = KeychainStore()
        let capture = AudioCaptureCoordinator()
        let realtime = ScribeRealtimeClient()
        let batch = ScribeBatchClient()
        let permissions = CapturePermissionService()
        let claudeAPI = ClaudeAPIProvider(modelProvider: {
            SettingsStore.loadSynchronously().anthropicModel
        }) {
            try keychain.secret(for: .anthropicAPIKey) ?? ""
        }
        let agents = AgentService(
            providers: [
                claudeAPI,
                ClaudeCLIProvider(),
                CodexCLIProvider(),
            ],
            repository: repository
        )
        // Localhost-only MCP endpoint. It reads the snapshot file per request,
        // so it exposes data only while an MCP-enabled snapshot is exported.
        let mcpHTTPServer = MCPHTTPServer(snapshotURL: paths.liveSnapshotURL)
        try? mcpHTTPServer.start()
        return AppDependencies(
            paths: paths,
            repository: repository,
            settingsStore: settingsStore,
            keychain: keychain,
            capture: capture,
            realtime: realtime,
            batch: batch,
            agents: agents,
            snapshotExporter: SnapshotExporter(url: paths.liveSnapshotURL),
            permissions: permissions,
            mcpHTTPServer: mcpHTTPServer
        )
    }
}
