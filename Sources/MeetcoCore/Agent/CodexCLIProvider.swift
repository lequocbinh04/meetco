import Foundation

private final class CodexStreamParser: @unchecked Sendable {
    private let lines = IncrementalLineBuffer()
    private let output = AgentTextAccumulator()
    private let continuation: AsyncThrowingStream<AgentEvent, any Error>.Continuation

    init(continuation: AsyncThrowingStream<AgentEvent, any Error>.Continuation) {
        self.continuation = continuation
    }

    var text: String { output.text }

    func consume(_ data: Data) {
        for line in lines.append(data) { parse(line) }
    }

    func finish() {
        if let line = lines.finish() { parse(line) }
    }

    private func parse(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return }
        if type == "item.completed",
           let item = object["item"] as? [String: Any],
           item["type"] as? String == "agent_message",
           let text = item["text"] as? String, !text.isEmpty {
            output.append(text)
            continuation.yield(.textDelta(text))
        } else if type == "turn.failed" || type == "error" {
            let message = object["message"] as? String ?? "Codex reported an error."
            continuation.yield(.warning(message))
        }
    }
}

public final class CodexCLIProvider: AgentProvider, @unchecked Sendable {
    public let kind: AgentProviderKind = .codexCLI
    public let capabilities = AgentCapabilities(
        streaming: false,
        structuredOutput: true,
        usesLocalCLIAuth: true
    )
    private let explicitPath: String?
    private let model: String?
    private let runner: ProcessRunner

    public init(explicitPath: String? = nil, model: String? = nil, runner: ProcessRunner = .init()) {
        self.explicitPath = explicitPath
        self.model = model
        self.runner = runner
    }

    public func healthCheck() async -> ProviderHealth {
        guard let executable = ProcessRunner.findExecutable(named: "codex", explicitPath: explicitPath) else {
            return ProviderHealth(state: .notInstalled, detail: "Codex CLI was not found in PATH.")
        }
        do {
            let cwd = try ProcessRunner.makeCleanWorkingDirectory()
            defer { try? FileManager.default.removeItem(at: cwd) }
            let version = try await runner.run(.init(
                executableURL: executable,
                arguments: ["--version"],
                workingDirectory: cwd,
                timeoutSeconds: 5
            ))
            let auth = try await runner.run(.init(
                executableURL: executable,
                arguments: ["login", "status"],
                workingDirectory: cwd,
                timeoutSeconds: 8
            ))
            let versionText = String(decoding: version.standardOutput, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return auth.exitCode == 0
                ? ProviderHealth(state: .ready, detail: "Codex CLI is installed and signed in.", version: versionText)
                : ProviderHealth(state: .needsLogin, detail: "Run `codex login` in Terminal.", version: versionText)
        } catch {
            return ProviderHealth(state: .unavailable, detail: error.localizedDescription)
        }
    }

    public func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard let executable = ProcessRunner.findExecutable(named: "codex", explicitPath: explicitPath) else {
                    continuation.finish(throwing: AgentProviderError.unavailable("Codex CLI is not installed."))
                    return
                }
                do {
                    let cwd = try ProcessRunner.makeCleanWorkingDirectory()
                    defer { try? FileManager.default.removeItem(at: cwd) }
                    var arguments = [
                        "exec", "--ephemeral",
                        "--sandbox", "read-only",
                        "--skip-git-repo-check",
                        "--ignore-user-config",
                        "--ignore-rules",
                        "--json",
                        "--color", "never",
                    ]
                    if let model, !model.isEmpty { arguments += ["--model", model] }
                    if request.expectsJSON {
                        let schemaURL = cwd.appendingPathComponent("meeting-artifacts.schema.json")
                        let schema = try JSONSerialization.data(
                            withJSONObject: MeetingArtifactSchema.jsonSchema,
                            options: [.prettyPrinted, .sortedKeys]
                        )
                        try schema.write(to: schemaURL, options: .atomic)
                        arguments += ["--output-schema", schemaURL.path]
                    }
                    arguments.append("-")
                    let parser = CodexStreamParser(continuation: continuation)
                    continuation.yield(.status("Running Codex CLI…"))
                    let result = try await runner.run(.init(
                        executableURL: executable,
                        arguments: arguments,
                        standardInput: request.stdinPrompt,
                        workingDirectory: cwd
                    ), onStandardOutput: parser.consume)
                    parser.finish()
                    guard result.exitCode == 0 else {
                        let message = String(decoding: result.standardError.suffix(2_000), as: UTF8.self)
                        throw AgentProviderError.processFailed(
                            code: result.exitCode,
                            message: message.isEmpty ? "Codex CLI failed." : message
                        )
                    }
                    continuation.yield(.completed(parser.text))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
