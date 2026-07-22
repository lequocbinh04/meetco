---
date: 2026-07-15
session: Meetco functional hardening
status: done-with-concerns
---

# Journal: 2026-07-15 — Meetco Functional Hardening

## Context

Phase 6 focused on making Meetco's local-first promise true across stop, failure, retry, chat, and MCP lifecycles. The goal was durable, honest state under interruption—not a broader feature pass.

## What happened

- Local capture now closes and preserves its archive/final mix before network finalization. Fatal capture faults attempt the same close path and leave the meeting recoverable.
- Online mixing, realtime WebSocket buffering/sends, and stop-time event draining are bounded. Stop drains queued events, sends trailing mixer frames, then commits and closes realtime transcription.
- Batch failure retains usable local audio for library retry. Transcript-only cleanup runs only after a transcript is saved; usable-audio inspection drives metadata and warnings.
- Chat persists each user/assistant turn atomically with `sending`, then a terminal `complete` or `failed` state. Partial failed output remains visible; evidence is limited to committed transcript segments and remapped after batch reconciliation.
- MCP exports the active meeting's canonical snapshot atomically, refreshes after relevant edits, restores only valid active state, and revokes disabled, deleted, stale, or recoverable snapshots.

## Reflection

The important improvement is failure truthfulness. A provider outage no longer implies recording loss, file presence no longer implies usable audio, and streamed UI text no longer outruns durable chat state. Automated build, deterministic checks, bundle, plist, and signature gates passed. App-level drain, fatal preservation, retry/retention, and MCP revocation were code-inspected and compiled, not manually exercised.

## Decisions

| Decision | Rationale | Impact |
|---|---|---|
| Close local recording first | Local media is the primary durable artifact | Network work can fail without discarding capture |
| Bound mixer skew, WebSocket queue/send, and drain waits | Stop and reconnect must terminate predictably | Silence fills bounded skew; backlog and shutdown cannot grow forever |
| Keep failed batch work recoverable | Transcription is retryable; capture is not | Retained mix supports library retry and relaunch recovery |
| Report usable audio, not directory existence | Storage state must match what users can replay/export | Empty or unusable output does not produce a false success |
| Persist atomic chat terminal states with committed evidence | UI streaming is provisional; repository state is canonical | Failed partial answers survive and citations remain defensible |
| Treat MCP as a revocable canonical projection | MCP must never become a second source of truth | Edits resync; invalid or opted-out state removes the snapshot |

## Next

- Run all 37 Swift Testing declarations with full Xcode and collect actual suite results and coverage.
- With explicit consent and BYOK credentials, validate TCC allow/deny/revoke, on-site/system capture, live and batch providers, forced-offline behavior, relaunch recovery, and MCP revocation on hardware.
- Complete manual light/dark, resizing, export, keyboard, VoiceOver, and Reduce Motion checks.
- Keep full-Xcode, live-provider, hardware/TCC, and manual UX gates marked unverified until that evidence exists.
