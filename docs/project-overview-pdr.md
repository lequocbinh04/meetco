# Meetco product requirements

## Goal

Build a polished personal macOS recorder that remains useful without a Meetco account or cloud backend. Local audio is authoritative; transcription, agents and MCP are optional layers.

## Required journeys

1. Connect ElevenLabs and an optional Claude API/Claude CLI/Codex CLI provider.
2. Start an Online or On-site recording from a compact preflight.
3. Choose Live Scribe v2 Realtime or After meeting batch transcription.
4. Keep recording through network/provider failures.
5. During Live mode, read provisional transcript and chat with a meeting-grounded agent.
6. Stop locally first; then reconcile a final transcript and generate selected artifacts.
7. Review, edit, search and export the local meeting; optionally expose a read-only MCP snapshot.

## Acceptance boundary

Calendar automation, visible meeting bots, video, cloud sync/team workspaces, mobile apps, CRM execution and notarized distribution are outside the first release.
