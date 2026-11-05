# In-house HLS Player for Cinema Everglow Server

Cinema's `Everglow` server used to wrap a third-party iframe (`cinesrc.st`)
inside `web/embed.html`, while Anime's `Everglow` already ran on our own
ad-free HLS.js player. Now both use the same player and proxy.

## How it works

- `resolveCinema` (`functions/anime.js`) resolves a TMDB movie or episode to a
  verified `.m3u8`. Fmov's four sources and VidBolt race in parallel; the first
  stream that passes `verifyCinemaStream` wins. The whole resolve is capped at
  10 s so the app's 15 s load timer never expires first.
- Every Cinema URL is proxied through `/proxyMegavidHls` with a signed stamp
  (`p=fmov|vidbolt`, `s=<hmac>`). Cinema hosts are deliberately **not** on the
  open allowlist: `fmov.my` runs its own open `/api/proxy?url=…` relay, so
  listing its host would turn our function into an open proxy.
- The player reports `animex-progress` (Continue Watching, Up Next) and, on a
  dead title, `animex-content-error` so the app moves to `CineSrc` immediately.

## Proof

`cinema-everglow-hls-playing-phone.png` — release web build at 430×932 in
Agent Mode, HUD collapsed. Fight Club playing a real frame with subtitles,
`Server: Everglow` selected, resumed at `start=600` (playback at 615 s).

Measured in the same session:

| Check | Result |
| --- | --- |
| `resolveCinema` movie (550) | 200, 1586 ms |
| `resolveCinema` TV (1396 S1E1) | 200, 1339 ms |
| Playback | 1920×1080, duration 8353 s, `t` advanced 0 → 12 s, not paused |
| Progress events to the app | 3 `animex-progress` messages, last position 28.9 s |
| Dead title failover | switched to `cinesrc.st` after 5523 ms |
| Open-relay attempt (`fmov.my/api/proxy?url=example.com`) | 400, no upstream fetch |

The old code, run against the same request, answered **200** and fetched the
URL. Captured before/after in the PR body.

## Known cost

Movies now stream through our Cloud Function like anime already did: roughly
1–3 GB per two-hour film. That is the price of ad-free playback and it is worth
watching on the Firebase bill.
