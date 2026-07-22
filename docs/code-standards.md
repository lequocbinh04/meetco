# Code standards

- Swift 6, macOS 14+, native frameworks and no third-party runtime dependencies.
- Prefer small Sendable value types, actors for mutable storage/network sessions, and `@MainActor` only for UI state.
- Keep audio callbacks free of disk, network, JSON and UI work; copy then enqueue.
- Use typed errors with actionable recovery. Never use `fatalError` for user/runtime conditions.
- Keep feature files near 200 lines when a real responsibility boundary exists.
- No secrets, full transcripts or raw audio payloads in logs, fixtures or workflow artifacts.
- Tests use deterministic fixtures/test doubles only at audio, network, process and filesystem boundaries; no fake production behavior.
