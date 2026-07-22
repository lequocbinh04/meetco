# Build and deployment

Meetco targets macOS 14+ and ships as a personal, ad-hoc signed app. It is not notarized or prepared for the App Store.

## Prerequisites

- Swift 6 toolchain
- Full Xcode for complete Swift Testing/XCTest execution and reliable UI/TCC debugging
- Optional ElevenLabs and Anthropic API keys
- Optional `claude` or `codex` CLI already logged in by the user

## Development verification

From the repository root:

```bash
swift build -debug-info-format none
swift test -debug-info-format none
swift run -debug-info-format none MeetcoChecks
swift build -c release -debug-info-format none
```

`MeetcoChecks` exercises deterministic persistence, bounded online mixing/silence, trailing realtime frames, transcription and batch-keyterm requests, canonical chat/evidence, local-audio inspection, process contracts, and MCP exporter restore/isolation without live credentials. App-level timeout handling, batch retry/retention, immediate failed-chat reload, and terminal MCP revocation are compiled and code-inspected, not manually exercised. The current 2026-07-15 run passes `swift build`, `MeetcoChecks`, release bundle assembly, independent plist lint, and strict ad-hoc signature verification.

On this Command Line Tools-only host, `swift test` compiles all three test targets but discovers and executes zero suites. Open `Package.swift` in full Xcode and run `MeetcoCoreTests`, `MeetcoCaptureTests`, and `MeetcoAppTests` to close that gap; compiled declarations are not a test pass.

## Build and launch the app bundle

```bash
./Scripts/build-app-bundle.sh
./Scripts/run-meetco.sh
```

The build script:

1. Builds release `MeetcoApp` and `MeetcoMCP` products with SwiftPM.
2. Recreates `dist/Meetco.app`.
3. Installs `Meetco` under `Contents/MacOS` and `MeetcoMCP` under `Contents/Helpers`.
4. Copies `Meetco.icns`, the in-app brand PNG, and the microphone/screen-capture usage descriptions into the bundle.
5. Ad-hoc signs with `Config/Meetco.entitlements`, then runs strict signature verification.

Inspect the result when needed:

```bash
plutil -lint dist/Meetco.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 dist/Meetco.app
open dist/Meetco.app
```

`MEETCO_CONFIGURATION=debug` selects a debug bundle. `MEETCO_DIST_DIR=/absolute/path` changes the output directory; `Scripts/run-meetco.sh` always opens the default `dist/Meetco.app`.

## First-run permissions

Meetco's preflight requires the necessary permission before enabling Start.

- **On-site:** Microphone only.
- **Online:** Microphone plus Screen Recording for system audio.

Open **Meetco → Settings → Permissions**, click Request, and accept the macOS prompt. If permission was denied before, enable Meetco under **System Settings → Privacy & Security → Microphone** or **Screen & System Audio Recording**, quit the app, and reopen it. Meetco may require a restart after the first screen-capture grant. Rebuilding an ad-hoc signed bundle can also cause macOS to request permission again.

Microphone, system-audio capture, allow/deny/revoke behavior, and TCC restart handling have not been exercised on hardware in this environment.

## BYOK and CLI health

In **Settings → Connections**:

- Save an ElevenLabs API key for Live or After meeting transcription.
- Save an Anthropic API key for Claude API.
- Choose Claude API, Claude CLI, Codex CLI, or no copilot as the default provider.
- Refresh provider status after changing a key or CLI login.

Keys are generic-password items in macOS Keychain under service `com.meetco.personal`; settings and meeting files contain no keys.

CLI login remains owned by the CLI:

```bash
claude auth status
codex login status
```

Meetco locates each executable through its process `PATH`, launches one temporary process per turn, and supplies meeting context over stdin. Claude CLI uses print/safe/no-tools/no-persistence options. Codex CLI uses ephemeral exec with a read-only sandbox and temporary working directory. Neither adapter uses permission-bypass flags. Health checks do not prove a real completion; provider credentials and live requests were not exercised here.

## First on-site and online smoke

For each mode:

1. Press Command-N and select On-site or Online.
2. Choose Live, After meeting, or Audio only; select retention and desired artifacts.
3. Choose the agent provider or None. Enable MCP only for data intended for the read-only snapshot.
4. Start; confirm elapsed time and microphone level. For Online, also confirm system level.
5. Pause, resume, add a local note, and—when Live/provider-ready—send a copilot message.
6. Stop; allow the bounded six-second capture drain and five-second-per-send realtime operations to finish, then wait for local close, optional final transcript, notes, and MCP publication.
7. Open the meeting in the library, play evidence/audio, relaunch Meetco, and confirm the meeting remains available. If batch fails, confirm the retained mix and recoverable warning remain, then use **Retry Transcript** after restoring connectivity or credentials.

Also repeat once offline: local capture must continue while provider failures remain visible. These hardware/network/UI scenarios are a manual handoff, not a pass recorded by this repository.

## Export

From a meeting detail toolbar, choose:

- **Markdown:** metadata, artifacts, notes, and timestamped transcript.
- **JSON:** the provider-neutral meeting context snapshot.
- **Audio:** `final-mix.wav`, only when local audio is retained.

Exports use a native save panel. The canonical meeting directory remains unchanged. Audio export rejects missing, empty, or header-only WAV/CAF containers. Transcript-only retention removes audio only after a transcript is saved; a batch or cleanup failure keeps `hasLocalAudio` and the UI/export state aligned with usable audio on disk.

## MCP client configuration

Enable MCP in Recording defaults or the recording preflight. Meetco atomically writes and refreshes:

```text
~/Library/Application Support/Meetco/Live/current-meeting.json
```

Use **Settings → MCP → Copy configuration** for the absolute paths of the running bundle. Manual equivalent:

```json
{
  "mcpServers": {
    "meetco": {
      "command": "/absolute/path/Meetco.app/Contents/Helpers/MeetcoMCP",
      "args": [
        "--snapshot",
        "/Users/you/Library/Application Support/Meetco/Live/current-meeting.json"
      ]
    }
  }
}
```

The stdio server provides `meeting.get_snapshot`, `meeting.search_transcript`, `meeting.get_segment`, and the meeting-summary resource. It reloads the snapshot per request, cannot write a meeting, and has no key or absolute audio path in its models. Meetco restores a valid completed active snapshot after relaunch and re-exports it after transcript, note, artifact, action, or chat edits. Turning MCP off, deleting the active meeting, or reaching stale, unreadable, recoverable, or other terminal failure state removes the authorization snapshot. MCP failure does not interrupt capture, transcription, or persistence.

## Storage, recovery, and rollback

Each meeting is independently stored at `~/Library/Application Support/Meetco/Meetings/<uuid>/`. Metadata, final and provisional transcript, artifacts, chat, and notes use atomic writes. A user message plus its initial sending assistant are appended atomically. Audio storage contains a manifest, source CAF tracks, and `final-mix.wav` when retained.

On launch, any meeting left in recording, paused, or finalizing state becomes `recoverable` with its files preserved. Recovery does not resume the prior audio device session and revokes an active MCP snapshot. Shared local-audio inspection rejects missing, empty, or header-only WAV/CAF files during recovery, finalization, retry, and export. A fatal active-capture fault stops the sources, flushes explicit trailing realtime frames when available, and attempts to close a partial recoverable recording. Local archive/final-mix setup failure enters a resettable failed capture state instead of leaving the coordinator stuck starting.

A failed batch transcript also remains recoverable with the local mix available for **Retry Transcript**. A successful retry saves the final transcript, remaps persisted chat/artifact evidence, applies transcript-only cleanup when selected, and refreshes the snapshot only if that completed meeting is still the active MCP meeting. Back up the meeting directory before manual repair. **Settings → Recording → Reveal in Finder** opens the storage root.

Removing `dist/Meetco.app` rolls back the installed build without deleting Application Support data or Keychain items. Deleting a meeting inside Meetco removes that meeting's entire local directory.

## Manual completion boundary

Before personal production use, run the full Xcode test targets and the matrix for real provider keys, CLI turns, microphone/system audio, permission deny/revoke/restart, forced offline, realtime/batch, export/MCP, relaunch recovery, light/dark, keyboard focus, VoiceOver, Increase Contrast, Reduce Transparency, and Reduce Motion. Full-Xcode suite execution and every credential, TCC/hardware, live-provider, VoiceOver, and Reduce Motion smoke remain unverified on the current Command Line Tools-only host.
