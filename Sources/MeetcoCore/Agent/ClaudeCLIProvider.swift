import Foundation

private final class ClaudeStreamParser: @unchecked Sendable {
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
        if type == "stream_event",
           let event = object["event"] as? [String: Any],
           event["type"] as? String == "content_block_delta",
           let delta = event["delta"] as? [String: Any],
           delta["type"] as? String == "text_delta",
           let text = delta["text"] as? String {
            emit(text)
        } else if type == "assistant", output.isEmpty,
                  let message = object["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] {
            let text = content.compactMap { $0["text"] as? String }.joined()
            if !text.isEmpty { emit(text) }
        } else if type == "result", output.isEmpty,
                  let text = object["result"] as? String, !text.isEmpty {
            emit(text)
        }
    }

    private func emit(_ text: String) {
        output.append(text)
        continuation.yield(.textDelta(text))
    }
}

public final class ClaudeCLIProvider: AgentProvider, @unchecked Sendable {
    public let kind: AgentProviderKind = .claudeCLI
    public let capabilities = AgentCapabilities(
        streaming: true,
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
        guard let executable = ProcessRunner.findExecutable(named: "claude", explicitPath: explicitPath) else {
            return ProviderHealth(state: .notInstalled, detail: "Claude CLI was not found in PATH.")
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
                arguments: ["auth", "status"],
                workingDirectory: cwd,
                timeoutSeconds: 8
            ))
            let versionText = String(decoding: version.standardOutput, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return auth.exitCode == 0
                ? ProviderHealth(state: .ready, detail: "Claude CLI is installed and signed in.", version: versionText)
                : ProviderHealth(state: .needsLogin, detail: "Run `claude auth login` in Terminal.", version: versionText)
        } catch {
            return ProviderHealth(state: .unavailable, detail: error.localizedDescription)
        }
    }

    public func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard let executable = ProcessRunner.findExecutable(named: "claude", explicitPath: explicitPath) else {
                    continuation.finish(throwing: AgentProviderError.unavailable("Claude CLI is not installed."))
                    return
                }
                do {
                    let cwd = try ProcessRunner.makeCleanWorkingDirectory()
                    defer { try? FileManager.default.removeItem(at: cwd) }
                    var arguments = [
                        "-p", "--safe-mode",
                        "--output-format", "stream-json",
                        "--include-partial-messages",
                        "--no-session-persistence",
                        "--permission-mode", "dontAsk",
                        "--tools", "",
                    ]
                    if let model, !model.isEmpty { arguments += ["--model", model] }
                    if request.expectsJSON {
                        let schema = try JSONSerialization.data(
                            withJSONObject: MeetingArtifactSchema.jsonSchema,
                            options: [.sortedKeys]
                        )
                        arguments += ["--json-schema", String(decoding: schema, as: UTF8.self)]
                    }
                    let parser = ClaudeStreamParser(continuation: continuation)
                    continuation.yield(.status("Running Claude CLI…"))
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
                            message: message.isEmpty ? "Claude CLI failed." : message
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
