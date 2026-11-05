# Anime player: Sakura Broadcast HUD, dark rose, wave loading

The Everglow and Megavid servers play through our own HLS page
(`hlsPlayerHtml` in `functions/anime.js`). That page used to be a bare
`<video controls>` with a white spinner. It now carries the Sakura
Broadcast HUD, and the watch page stopped repeating skip controls
outside the player.

## What changed

- **Dark rose, not pastel.** Every accent moved from `#FF6F91` to the anime
  section's own `#C2185B` (`AnimeXTokens.accent`), so the player matches
  the rest of Everglow Anime.
- **Wave loading.** The boot overlay is the `EVERGLOW` wordmark only, with
  each letter riding a wave. No spinner, no card.
- **Netflix subtitles.** `video::cue` and the caption overlay both draw
  bold white text with a dark stroke and no background box.
- **Sakura Broadcast HUD.** Title, SUB/DUB, Episodes, Skip OP, Next
  episode, a scrubber with gold OP/ED segments, play, -10s, +10s, volume,
  time, the Everglow badge, CC, quality, fullscreen. The HUD fades out
  after 2.8 s of playback and returns on mouse or touch.
- **Skip controls moved inside the player.** The watch page no longer
  draws a Skip Opening / Skip Ending row or a "What happened" link under
  the video. The player gets the AniSkip windows over `postMessage` and
  draws its own Skip OP pill plus the gold timeline segments. The episode
  list already carries each synopsis, so the link was duplicate text.

## Proof

Both watch-page shots are the release web build at 430 px in Agent Mode,
same title, same episode.

- `watch-page-before.png` — `main`: `What happened`, `Skip Opening → 1:30`
  and `Skip Ending → 23:41` sit under the episode header.
- `watch-page-after.png` — this branch: the header goes straight to the
  server row.

The player shots come from the real `hlsPlayerHtml` output, opened in
Chrome at phone and tablet widths, with a stubbed 23:43 episode so the
scrubber, chapters and skip pill show real values.

- `player-loading-wave-phone.png` — the `EVERGLOW` wave while the stream
  boots.
- `player-hud-phone.png` — 430 px: gold OP segment at the left, gold ED
  segment at the right, Skip OP pill, Next: EP 20, the Everglow badge,
  and the subtitle with no box.
- `player-hud-tablet.png` — 1024 px: the same HUD with the volume button
  back.

Not proven here: a live MegaPlay or Megavid stream inside the new HUD.
The sandbox has no Firebase login, so the resolver answers its failover
page. The HUD, wave, cue styling and skip wiring are proven; the stream
itself is proven separately in `docs/pr-proof/pr-557/`.
