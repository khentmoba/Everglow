# Everglow player: full controls, gestures, and a CC panel

The Everglow server plays through our own HLS page (`hlsPlayerHtml` in
`functions/hls_player.js`, shared by the Firebase functions and the
streaming Worker). The other servers — CineSrc, Videasy, VidLink, FluxTV —
are third-party cross-origin frames, so none of this can reach them. This
change is the Everglow server plus the app's player screen.

## The bug behind "I can't click the player to pause"

`#hud` is a `position:fixed; inset:0` gradient sheet at `z-index:5` with no
`pointer-events` rule. It covered the whole picture, so a tap in the middle
landed on the HUD, not the video. It now takes `pointer-events:none`, and the
two control bands take pointers back (`body.idle` disables them while hidden).

## What changed

**Player page (`functions/hls_player.js`)**

- **Click the picture to play or pause** — mouse only. Double-click also
  toggles fullscreen; the two clicks cancel out first, so the play state
  survives.
- **Touch gets gestures, not tap-to-pause.** On `(hover:none)` /
  `(pointer:coarse)` a single tap shows or hides the controls, double tap
  on the left or right third seeks ∓10 s, and double tap in the middle third
  toggles playback (matching YouTube). A single tap never pauses.
- **Drag the progress bar.** Nothing is committed until the pointer lifts, so
  a slow drag does not fire a seek on every pixel and stall the buffer. The
  bar also takes focus (`role="slider"` with dynamic `aria-valuenow`) and
  answers `←`/`→`/`Home`/`End`.
- **Volume slider** next to the mute button, on pointer devices only.
- **Playback speed** 0.25×–2×, with the chip showing the current rate.
- **Picture-in-Picture** button with runtime capability detection: hidden when
  unsupported, supports both W3C `requestPictureInPicture` and iPadOS Safari's
  `webkitSetPresentationMode`.
- **CC opens a panel**: captions on/off, language (when a title has more than
  one track), subtitle delay −10 s to +10 s in 0.1 s steps, and text size.
- **Captions are drawn by us**, so the delay slider can shift them. Cues are
  read once and matched against `currentTime − delay`.
- **The panel lifts the captions** by its own measured height.
- **Skip Opening / Next Episode live outside the HUD**, so they stay visible
  and clickable while the controls have faded out.
- **A mid-play stall shows a small ring**, not the EVERGLOW boot wordmark.
- **Fullscreen captions scale with the picture.** The old ceiling was 22 px,
  which left them tiny on a laptop or tablet.
- **Settings persist** in `localStorage` (`everglow.player.prefs`): delay,
  size, track, captions, volume, mute, speed.

**App (`video_player_state_base.dart`, `video_player_screen_web.dart`)**

- **Keyboard forwarding.** Keys reach the player page only while its frame
  has focus. The app relays the player's keys from its own document when the
  Everglow server is playing and the video is on screen, so the arrows work
  after clicking anywhere on the page without blocking page scrolling when
  scrolled down into metadata and episodes.

## Proof

Player-page shots are the real `hlsPlayerHtml` output in headless Chrome,
with the hls.js CDN tag removed so the native media branch runs against a
generated 20 s silent WAV and a one-cue WebVTT track. `before` is
`origin/main`'s `hls_player.js`, `after` is this branch, same viewport and
same stored settings.

| # | before | after |
| --- | --- | --- |
| Control bar | `01-before-bar.png` | `02-after-bar.png` |
| CC | `03-before-cc.png` (toggles only) | `04-after-cc.png` (delay + size) |
| Mid-play stall | wordmark (see code) | `06-after-stall.png` (ring) |
| Drag | click-to-seek only | `07-after-drag.png` (previews at 78 %) |
| Fullscreen caption | `15-before-fullscreen-subtitle.png` (22 px) | `16-after-fullscreen-subtitle.png` (59.9 px) |
| Skip while controls idle | `17b-before-skip-gone-while-idle.png` (blank) | `17-after-skip-while-idle.png` |

Measured in that same page, not just asserted in tests:

| check | result |
| --- | --- |
| `getComputedStyle(#hud).pointerEvents` | `none` |
| trusted click on the picture | paused → playing, and back |
| `ArrowRight` on a focused scrubber | exactly +10 s (was +20 s) |
| drag to 78 % | bar 78 %, label `00:15 / 00:20`, video still at 4 s |
| speed menu | 0.25× … 2×, `playbackRate` 1.5, persisted |
| volume slider → 0.35 | `v.volume` 0.35, persisted |
| touch, one tap | `v.paused` stays true |
| touch, double tap left / right | 15 s → 5 s / 5 s → 15 s |
| stall after first play | ring visible, wordmark `display:none` |
| caption at 1920×1080 | 22 px on `main`, 59.9 px here |
| skip with `body.idle` | `#binge` parent `BODY`, button clickable at (920, 488) |

## Tests

- `cloudflare/src/anime.test.js` — 52 pass. New: HUD no longer eats clicks,
  click vs touch, double-tap seek, drag commits on release, scrubber keys do
  not seek twice, volume, speed, PiP, stall ring, CC panel shape, delay
  shifting the cue, caption ceiling, binge scrim visibility, and `#binge`
  sitting outside `#hud`.
- `functions/anime.test.js` — 44 pass; full suite 380 pass / 5 skipped.
- `flutter analyze` clean, `flutter test --exclude-tags="golden,network"`
  1854 pass / 1 skipped, all 16 `dart tool/ci/check_*.dart` guards pass.
