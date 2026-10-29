# Everglow server: no more endless buffering

The Everglow anime server (MegaPlay) loaded its player page and then spun
forever. MegaPlay now serves video segments from throwaway domains that change
per title (`wintergrove.space`, `phantomharbor.space`, `goldenanchor.space`,
`shadowharbor.space`). They were not on our proxy allowlist, so the browser
fetched them directly and got `403` (the CDN needs MegaPlay's Referer).

## Proof shots

Both come from the real `proxyAnime` + `proxyMegavidHls` handlers running
locally (Firestore stubbed in memory), against live MegaPlay, in Chrome.
Episode: Shangri-La Frontier Season 2, episode 1 (AniList 176508).

- `everglow-server-before.png` — `main`: `readyState 0`, 0 s buffered after
  30 s, spinner only.
- `everglow-server-after.png` — this branch: `readyState 4`, 227 s buffered,
  `currentTime` advancing (6.5 s), real decoded frame.

Unstamped, forged-stamp, and foreign-host proxy requests still answer
`400 Host not allowed`.

Not proven: the production deploy, which only happens after merge.
