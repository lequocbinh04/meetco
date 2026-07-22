import Foundation

public final class ClaudeAPIProvider: AgentProvider, @unchecked Sendable {
    public let kind: AgentProviderKind = .claudeAPI
    public let capabilities = AgentCapabilities(
        streaming: true,
        structuredOutput: true,
        usesLocalCLIAuth: false
    )
    private let apiKeyProvider: @Sendable () throws -> String
    private let modelProvider: @Sendable () -> String
    private let session: URLSession

    public init(
        model: String,
        apiKeyProvider: @escaping @Sendable () throws -> String,
        session: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.modelProvider = { model }
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    public init(
        modelProvider: @escaping @Sendable () -> String,
        apiKeyProvider: @escaping @Sendable () throws -> String,
        session: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.modelProvider = modelProvider
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    public func healthCheck() async -> ProviderHealth {
        do {
            let key = try apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty
                ? ProviderHealth(state: .notConfigured, detail: "Add an Anthropic API key.")
                : ProviderHealth(state: .ready, detail: "Anthropic API key is configured.")
        } catch {
            return ProviderHealth(state: .notConfigured, detail: "Add an Anthropic API key.")
        }
    }

    public func stream(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let key = try apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else {
                        throw AgentProviderError.authentication("Add an Anthropic API key first.")
                    }
                    let urlRequest = try Self.urlRequest(
                        request,
                        apiKey: key,
                        model: modelProvider()
                    )
                    continuation.yield(.status("Connecting to Claude…"))
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw AgentProviderError.invalidResponse("Claude returned no HTTP response.")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        throw Self.failure(statusCode: http.statusCode)
                    }
                    var output = ""
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let value = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard value != "[DONE]", let data = value.data(using: .utf8) else { continue }
                        if let event = try Self.parseSSE(data) {
                            if case .textDelta(let delta) = event { output += delta }
                            continuation.yield(event)
                        }
                    }
                    continuation.yield(.completed(output))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AgentProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public static func urlRequest(
        _ request: AgentRequest,
        apiKey: String,
        model: String
    ) throws -> URLRequest {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": request.maximumOutputTokens,
            "stream": true,
            "system": request.systemPrompt,
            "messages": [["role": "user", "content": request.userPrompt]],
        ]
        if request.expectsJSON {
            body["output_config"] = [
                "format": [
                    "type": "json_schema",
                    "schema": MeetingArtifactSchema.jsonSchema,
                ],
            ]
        }
        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    public static func parseSSE(_ data: Data) throws -> AgentEvent? {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return nil }
        switch type {
        case "content_block_delta":
            let delta = object["delta"] as? [String: Any]
            guard delta?["type"] as? String == "text_delta",
                  let text = delta?["text"] as? String else { return nil }
            return .textDelta(text)
        case "message_start":
            let message = object["message"] as? [String: Any]
            let usage = message?["usage"] as? [String: Any]
            return .usage(AgentUsage(inputTokens: usage?["input_tokens"] as? Int))
        case "message_delta":
            let usage = object["usage"] as? [String: Any]
            return .usage(AgentUsage(outputTokens: usage?["output_tokens"] as? Int))
        case "error":
            let error = object["error"] as? [String: Any]
            throw AgentProviderError.invalidResponse(
                error?["message"] as? String ?? "Claude streaming failed."
            )
        default:
            return nil
        }
    }

    private static func failure(statusCode: Int) -> AgentProviderError {
        switch statusCode {
        case 401, 403: .authentication("Anthropic rejected the API key.")
        case 429: .unavailable("Claude is rate limited. Try again shortly.")
        case 500...599: .unavailable("Claude is temporarily unavailable.")
        default: .invalidResponse("Claude request failed (HTTP \(statusCode)).")
        }
    }
}
