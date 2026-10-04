# Watch Together live playback sync — proof

## Problem

When Khent and Clair watched together via the in-app "Watch Together" feature, pausing from one POV (or resuming/seeking) did not reliably pause or sync on the partner's screen.
The previous mechanism relied on rebuilding the cross-origin iframe with updated URL parameters and an autoplay flag. This had three fatal flaws:
1. Rebuilding the iframe caused the player to restart or reload its DOM completely, often losing position or failing autoplay policy.
2. Cross-origin embeds silently ignore URL play/pause query parameters once loaded.
3. The 5-second room heartbeat wrote `state` ("playing") to Firestore along with its position ticks, which could race against a partner's pause and immediately flip the room back to "playing".

## Solution

1. **Direct Player Control Bridge (`cinesrc_bridge.dart` & `web/embed.js`)**:
   - CineSrc natively supports postMessage commands (`play`, `pause`, `seek`, `setMuted`, `getPaused`) and emits real playback events (`cinesrc:play`, `cinesrc:pause`, `cinesrc:timeupdate`, `cinesrc:seeking`, `cinesrc:seeked`, `cinesrc:ended`, `cinesrc:ready`).
   - `web/embed.js` now relays safe commands from the host Watch Party screen to upstream CineSrc (`https://cinesrc.st`) and forwards CineSrc playback events back up to the parent application.
2. **Instant In-Place Pause & Resume**:
   - Tapping Pause/Resume immediately sends `pause` or `play` to the active player via postMessage without reloading the iframe.
   - When the partner receives the Firestore state update, their screen sends `pause` or `play` directly to their player — stopping or starting the video in place without losing playback position.
3. **Heartbeat State Isolation**:
   - The room heartbeat only updates `currentTime`, `updatedAt`, and `beatBy` (not `state`). Heartbeat ticks can never undo a pause that Clair or Khent just tapped.
4. **Local Gesture & Autoplay Protection**:
   - User tap actions unmute audio. If an unprompted partner remote-play is blocked by browser sound policy, the screen detects it via `getPaused` and plays muted as fallback so video still advances in sync.
5. **Bidirectional Control**:
   - Both Khent and Clair have active control over playback; when either partner pauses or resumes in their own UI, the partner's POV mirrors the change in real-time.

## Verification

- `test/features/watch_party/cinesrc_bridge_test.dart` — 13 unit tests verifying command generation, event parsing, non-map rejection, and user seek detection.
- `test/features/watch_party/watch_party_room_test.dart` — 3 new unit tests covering `beatBy` field isolation and copyWith behavior.
- `functions/test/cinema_embed_bridge.test.js` — unit tests verifying command forwarding from parent to upstream CineSrc, unknown command filtering, origin validation, and playback event forwarding to parent.
- All Flutter tests in `test/features/watch_party` pass (35/35).
- All 15 CI regression guards in `tool/ci/check_*.dart` pass.
- Full `flutter analyze` clean (0 issues).
