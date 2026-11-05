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
- **Sakura Broadcast HUD.** Title, SUB/DUB, Episodes, a scrubber with gold
  OP/ED segments, play, -10s, +10s, volume, time, the Everglow badge, CC,
  quality, fullscreen. The HUD fades out after 2.8 s of playback and
  returns on mouse or touch.
- **One button per moment.** The Skip pill belongs to the opening only.
  The Next episode button belongs to the ending, or to the last 90 seconds
  when nobody marked one. They never show together, and Next stays hidden
  when nothing follows (a film, or the last episode of the last season).
- **Skip controls moved inside the player.** The watch page no longer
  draws a Skip Opening / Skip Ending row or a "What happened" link under
  the video. The episode list already carries each synopsis, so the link
  was duplicate text.

## Proof

Both watch-page shots are the release web build at 430 px in Agent Mode,
same title, same episode.

- `watch-page-before.png` — `main`: `What happened`, `Skip Opening → 1:30`
  and `Skip Ending → 23:41` sit under the episode header.
- `watch-page-after.png` — this branch: the header goes straight to the
  server row.

The player shots come from the real `hlsPlayerHtml` output, opened in
Chrome over http so the app's own `postMessage` path runs, with a stubbed
23:43 episode and AniSkip windows of 0:45–2:15 and 22:10–23:43.

- `player-loading-wave-phone.png` — the `EVERGLOW` wave while the stream
  boots.
- `player-opening-skip-phone.png` — 430 px at 1:00, inside the opening:
  `Skip OP (02:15)` is offered and no Next button exists.
- `player-ending-next-phone.png` — 430 px at 22:30, inside the ending:
  `Next: EP 20` is offered and the Skip pill is gone.
- `player-hud-tablet.png` — 1024 px at 1:00: the same opening state with
  the volume button back.

Not proven here: a live MegaPlay or Megavid stream inside the new HUD.
The sandbox has no Firebase login, so the resolver answers its failover
page. The HUD, wave, cue styling and button gating are proven; the stream
itself is proven separately in `docs/pr-proof/pr-557/`.
