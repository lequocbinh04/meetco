# Design guidelines

Meetco uses a meeting-studio aesthetic: a deep ink shell around warm, content-first work surfaces, rounded SF typography, restrained cobalt intelligence accents, and explicit local/provider state. The app should feel calm during long recordings and decisive around start, pause, stop, failure, and recovery.

## Visual system

- Use semantic `MeetcoTheme` tokens, never feature-local RGB values. Canvas, surface, elevated, text, border, accent, recording, success, warning, and error colors have light/dark variants.
- The generated Meetco mark combines conversation, a waveform, and recording state. Use `MeetcoAppIcon.png` inside the app and `Meetco.icns` for the bundle; do not redraw or recolor it per screen.
- Cobalt denotes selection, intelligence, and navigation. Coral is reserved for record/start/stop. Green remains semantic readiness only.
- Use the 4/8/12/16/24/32 pt spacing scale and 10/16/22/24 pt control/card/hero/sheet radii.
- Use rounded SF display styles for brand/hero hierarchy, standard SF for controls, and monospaced tabular numerals for elapsed time.
- Prefer ink hero surfaces, warm elevated panels, thin inner borders, and tinted shadows with at least 24 pt scroll gutters. Avoid purple gradients, outer glow, glass on scrolling cards, and color-only state.

## Product structure

- The main window uses a native split with a custom ink studio rail for Home, Meetings, and Settings. Minimum supported content size is 880×620 pt.
- Home is intentionally asymmetric: one high-contrast recording hero, a readiness panel, then recent local meetings.
- Preflight is the single decision surface before recording: a studio header/title, Online/On-site, Live/After meeting/Audio only, retention, artifacts, provider status, then advanced final polish and MCP.
- The live surface keeps local recording state and controls permanently visible. Transcript is primary; notes and copilot use a split panel above 1,040 pt and an inspector below it.
- Meeting detail separates Overview, Transcript, Notes, and Chat. Exports and destructive actions live in toolbar menus.
- Settings uses one ink header and custom studio tabs for Connections, Recording, MCP, and Permissions. It must never introduce a nested navigation split. Provider and permission failures include an actionable repair path.
- The menu bar extra mirrors the active meeting and exposes start-last-preset, pause/resume, stop, main window, and settings without creating a second source of state.

## Interaction and motion

- One primary action per view. Default action starts recording; Escape cancels; Command-N opens preflight; Space pauses/resumes; Command-Shift-R stops.
- Motion explains replacement or state change. Micro interactions use about 200 ms; panels use about 260 ms; transitions must remain interruptible.
- Reduce Motion replaces offset/replacement motion with a 100–120 ms opacity change and disables the repeating recording pulse.
- Reduce Transparency replaces live control material with an opaque elevated surface.
- Audio meters update at a bounded rate without animating layout. Transcript rows use stable segment IDs and lazy layout.
- Never hide provider delay or finalization behind an indefinite spinner. Keep the local-safe status visible while optional cloud work continues.

## Accessibility

- Critical state always has text plus symbol: recording/paused, local/cloud, provisional/final, ready/failure, and MCP enabled/disabled.
- Icon-only controls require a VoiceOver label and visible keyboard focus. Primary targets should remain at least 44×44 pt where layout permits.
- Combined recording status announces state and elapsed time. Notes/copilot inspector buttons announce the resulting action.
- Preserve native focus order and keyboard equivalents. Do not steal focus when transcript segments arrive.
- Preserve readable system typography and recovery guidance at every supported window width. Verify light/dark appearance, Increase Contrast, Reduce Transparency, Reduce Motion, and VoiceOver explicitly.
- Use `ViewThatFits` or an equivalent native fallback for dense live controls, meeting-detail headers, warning rails, and other rows that can exceed the 880×620 minimum. Do not solve overflow with clipping or tiny type.

## Content and trust

- Say where data is going: “ElevenLabs Scribe,” “Claude API,” “Claude CLI,” or “Codex CLI,” rather than generic “AI.”
- “Recording locally” must remain distinguishable from “Live transcript connected.” Provider failure copy confirms whether local audio is safe.
- Mark realtime transcript as provisional until batch finalization succeeds. Generated decisions/actions should retain an evidence jump when valid.
- Private notes are labeled local. MCP is labeled opt-in and read-only. Audio export is disabled or errors clearly when retention removed the mix.
- Use direct recovery copy. Never imply interrupted capture resumed when the app only preserved and marked the meeting recoverable.

## Manual design QA

Before calling the experience polished, inspect onboarding, empty/populated library, preflight validation, live transcript growth, provider delay/failure, finalization, recoverable meetings, settings, save panels, and menu bar at minimum and expanded widths. Repeat in light/dark, Increase Contrast, Reduce Transparency, Reduce Motion, keyboard-only, and VoiceOver.

Home, all first-run onboarding steps, preflight, and every Settings tab were visually inspected in the signed bundle at the default 900×700 window. Reduce Motion/Transparency handling and key VoiceOver labels are implemented. Dark appearance, full VoiceOver traversal, Increase Contrast, TCC, and hardware interaction smoke remain unproven in the current Command Line Tools-only environment.

Research rationale and wireframes remain in the [UI/UX direction report](../plans/20260715-1120-meetco-native-macos/reports/research/ui-ux-direction.md).
