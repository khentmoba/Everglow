# Everglow streaming Worker (Cloudflare)

Port of the Firebase `proxyAnime` + `proxyMegavidHls` functions to a Cloudflare
Worker, where bandwidth is not billed. A 1080p film is ~6.4 GB of egress —
about **$0.76 per movie** on Firebase, **$0** here.

Same paths, same query params, same player page, so the app only changes its
origin. The app is deliberately **not** flipped in this PR: a Worker that is not
deployed cannot serve, so the flip has to come after deploy or Cinema and Anime
break for Clair.

## Proof

`worker-player.png` — the Worker's own player page
(`/proxyAnime?source=cinema&type=movie&tmdbId=550&start=600`) running under
`wrangler dev` in the real workerd runtime, playing Fight Club with subtitles,
resumed at 600 s.

Measured in that session:

| Check | Result |
| --- | --- |
| `wrangler dev` boot | ready in ~2 s, `/health` → `ok` |
| Cinema movie (550) | 200 in 2287 ms |
| Cinema TV (1396 S1E1) | 200 in 1180 ms |
| Playback | 1920×1080, 8353 s, `t` 600 → 612, not paused |
| Open-relay attempt (`fmov.my/api/proxy?url=example.com`) | 400, nothing fetched |
| Unit tests | 23 passed, 0 failed |

## What changed vs the Firebase version

- `node:crypto` → WebCrypto. The MegaPlay AES-256-CBC decrypt is pinned against
  the same ciphertext the Firebase test uses, so the port is proven identical
  rather than merely non-throwing.
- Express `res` → `Response` + `ReadableStream`. Workers apply backpressure, so
  the manual `streamMediaBody` reader loop is gone.
- Firestore stamp key → `CDN_STAMP_KEY` Worker secret. Fails closed when unset.
- The player's native bridge no longer hardcodes the Firebase host, so the
  Android WebView keeps reporting progress on any host.

Dropped on purpose: AnimePahe + `proxyAnimeSegment` (need a self-hosted API base
the app no longer offers), Firebase ID-token verification (optional before, and
the app never sends a token to these routes), DNS-based SSRF checks (no resolver
in Workers; the signed stamps already pin every URL), and per-IP rate limiting
(two viewers).
