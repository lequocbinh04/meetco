# System architecture

Meetco is a Swift 6 package with no third-party runtime dependencies. The local meeting repository is authoritative; capture, cloud providers, agents, exports, and MCP are replaceable consumers around it.

```text
MeetcoApp (SwiftUI app, settings scene, menu bar extra)
  └─ AppModel / MeetingSessionCoordinator
      ├─ MeetcoCapture
      │   ├─ AVAudioEngine microphone source
      │   ├─ ScreenCaptureKit system-audio source
      │   ├─ source CAF archive + manifest
      │   └─ aligned 16 kHz mono frames + final-mix.wav
      ├─ ElevenLabs Scribe realtime and batch clients
      ├─ AgentService
      │   ├─ Claude Messages API
      │   ├─ Claude CLI
      │   └─ Codex CLI
      ├─ MeetingRepository / Keychain / UserDefaults
      └─ SnapshotExporter

MeetcoMCP (bundled read-only stdio helper)
  └─ reloads the opt-in current-meeting snapshot per JSON-RPC request
```

SwiftPM products are `MeetcoCore`, `MeetcoCapture`, `MeetcoApp`, `MeetcoMCP`, and `MeetcoChecks`. Packaging renames `MeetcoApp` to `Meetco.app/Contents/MacOS/Meetco`, copies `MeetcoMCP` to `Contents/Helpers`, installs usage descriptions, and ad-hoc signs the personal bundle.

## Session lifecycle

1. Preflight selects capture mode, transcription, retention, artifact recipe, agent, and MCP.
2. The repository creates the meeting directory before capture starts.
3. Capture writes local source archives and the mixed WAV independently of network work. Online mixing permits at most one second of source skew, then pads the stalled source with silence so the healthy source keeps advancing.
4. Live mode starts Scribe v2 Realtime after local capture is active. Committed segments are saved as a provisional transcript; network failure leaves capture running.
5. Chat rebuilds provider-neutral context from the local snapshot. The user record and initial `sending` assistant record are appended atomically; the assistant then reaches complete or failed and attaches evidence only from committed segments.
6. Normal Stop closes capture, waits at most six seconds for queued capture events, then sends explicit trailing mixer frames before the final realtime commit/stop. Each realtime transport send is bounded to five seconds. The WAV already contains those same frames.
7. After-meeting mode—or Live with final polish—submits the file-backed WAV and configured key terms to Scribe batch. Each batch key term is sanitized and capped at five words. A successful result becomes the final transcript.
8. Transcript reconciliation durably remaps persisted chat and artifact evidence from provisional segment IDs to final IDs. Enabled artifacts remain schema-decoded and evidence-checked before saving.
9. Transcript-only retention removes audio only after a transcript is saved. A batch failure retains the mix, marks the meeting recoverable, and exposes a library retry that repeats batch, reconciliation, retention, artifacts, and active MCP publication.
10. An MCP-enabled session publishes its current snapshot during recording and finalization, restores a valid completed snapshot after relaunch, and re-exports after library edits.

Capture setup failures, including local archive or final-mix writer construction, enter a failed state so a later start can reset capture resources. A fatal fault during active capture stops both sources, sends any explicit trailing mixer frames before closing realtime, and attempts to close the partial files as a recoverable meeting. A stop failure also marks the meeting recoverable. On the next launch, meetings still marked recording, paused, or finalizing become recoverable; local files are preserved rather than resumed automatically.

## Local data model

```text
~/Library/Application Support/Meetco/
├── Meetings/<uuid>/
│   ├── meeting.json
│   ├── transcript.json
│   ├── transcript-provisional.json
│   ├── artifacts.json
│   ├── chat.json
│   ├── notes.txt
│   └── audio/
│       ├── manifest.json
│       ├── microphone-*.caf
│       ├── system-*.caf
│       └── final-mix.wav
└── Live/current-meeting.json
```

JSON/text persistence uses atomic replacement. Each meeting directory is independently listable, deletable, and recoverable. App defaults are encoded in UserDefaults. ElevenLabs and Anthropic keys are generic-password Keychain items under service `com.meetco.personal`; keys never enter meeting or MCP snapshots.

Audio retention is applied only after finalization. `LocalAudioInspection` treats missing, empty, or header-only WAV/CAF containers as unavailable and is shared by recovery, finalization, retry, and export. `transcriptOnly` removes the audio directory only after a usable transcript is saved and retains valid audio when final transcription fails; cleanup failure leaves `hasLocalAudio` true with a warning. `keepAudio` retains transcript and audio; `audioOnly` retains the recording without requiring transcription.

## Audio and transcription boundary

`MeetcoCapture` requests microphone access for both capture modes and Screen Recording for Online mode. Audio callbacks only hand off copied buffers. `AudioArchiveWriter` keeps native source tracks, while the timeline mixer aligns sources and writes 250 ms, mono Int16 PCM frames at 16 kHz to the WAV/realtime path. In Online mode, a 16,000-sample watermark bounds source skew to one second and fills a lagging source with silence. Pause time is removed from the meeting timeline; detected source discontinuities become visible warnings. Mixer remainders are padded to a final frame and returned to the coordinator so realtime receives the same trailing timeline before shutdown.

The realtime client holds at most 120 uncommitted frames and uses bounded exponential reconnect for recoverable failures. Every transport send has a five-second timeout. It sends serialized manual commits every 20 seconds so Stop can await its exact queue position; the capture-event drain itself is capped at six seconds, and a reconnect during Stop replays the tail and issues a new final commit. Authentication, quota, terms, and invalid-input failures surface immediately. A committed-with-timestamps event enriches an existing provisional segment instead of duplicating it.

Batch Scribe uses a file-backed multipart request with word timestamps, diarization, and sanitized configured key terms. Batch output becomes the final transcript; provisional data remains separate. Batch failure is persisted as recoverable without discarding the retained mix. On success or retry, time-overlap reconciliation rewrites stored chat and artifact evidence references to final segments.

## Agent boundary

`MeetingContextBuilder` compacts relevant transcript segments, transcript tail, current artifacts, private notes, and recent chat within deterministic budgets. Transcript content is explicitly marked untrusted.

Claude API streams Messages SSE. CLI adapters locate their executable through the app process `PATH`, retain only a minimal environment, send context over stdin, use an app-owned temporary working directory, bound execution time, and drain stdout/stderr concurrently. CLI authentication stays owned by the installed CLI.

`AgentService` saves chat independently of provider state, so switching Claude API, Claude CLI, Codex CLI, or None does not change the canonical meeting. The user and initial `sending` assistant records share one atomic repository update; the assistant is then durably updated to `complete` or `failed`. Partial provider output is preserved on failure, and selected-meeting chat reloads the canonical pair immediately. Evidence IDs are filtered to committed transcript segments, never ephemeral partials. Structured artifact output is decoded against the selected recipe, checked for transcript evidence IDs, and repaired at most once; invalid output does not overwrite the last valid artifact set.

## MCP and export boundary

`SnapshotExporter` atomically writes only an MCP-enabled `MeetingContextSnapshot` for its authorized active meeting ID. Starting another meeting invalidates the prior file before publishing, so a cancelled chat or note task cannot overwrite the new context. Bootstrap restores only a valid completed, MCP-enabled meeting, then rebuilds the snapshot from the repository. Transcript, note, artifact, action, and chat edits re-export when that meeting remains active. Disable, active-meeting deletion, recoverable or other terminal failure state, unreadable/stale data, or a mismatched meeting ID revokes or cannot overwrite the active snapshot. `MeetcoMCP` implements JSON-RPC `initialize`, `tools/list`, `tools/call`, `resources/list`, and `resources/read` over newline-delimited stdio. Its tools expose the snapshot, transcript search, and segment lookup. Models contain neither credentials nor absolute audio paths, and there are no mutation tools.

Markdown and JSON export are derived from the selected meeting snapshot. Audio export first uses `LocalAudioInspection`, then copies a retained `final-mix.wav` only when the WAV/CAF has payload beyond its header. Exports never mutate the repository.

## Verification boundary

Current Command Line Tools gates pass `swift build`, `MeetcoChecks`, release bundle assembly, plist lint, and strict ad-hoc signature verification. `swift test` compiles but discovers and runs zero suites here. Full-Xcode suite execution, real provider credentials, TCC microphone/system capture, audio-device changes, UI interaction, VoiceOver, and Reduce Motion behavior require a configured Mac and remain unverified.
