# Everglow streaming Worker (Cloudflare)

The streaming proxy now runs on Cloudflare, where bandwidth is not billed. A
1080p film is ~6.4 GB of egress — about **$0.76 per movie** on Firebase, **$0**
here.

**Deployed:** `https://everglow-stream.khentplaysmoba.workers.dev`

## What it serves

| Path | Does |
| --- | --- |
| `/proxyAnime?source=cinema\|megaplay\|everglow\|megavid&…` | Resolves the title and serves our HLS player page |
| `/proxyMegavidHls?u=<url>[&p=fmov\|vidbolt][&s=<stamp>]` | Streams playlists (rewritten), segments, keys, subtitles |
| `/health` | `ok` |

## Proof

`app-on-worker.png` — the real release web build at 430×932 in Agent Mode,
HUD collapsed, playing Fight Club **through the deployed Worker**, resumed at
600 s, `Server: Everglow`.

The app's iframe points at `https://everglow-stream.khentplaysmoba.workers.dev/proxyAnime?source=cinema&…`
with no hand-swapping. The player reported 26 `animex-progress` events, all
from the Worker origin, position 0 → 27 s — so the app accepted the stream as
its own.

`preview-hosted.png` — the same check on the **hosted PR preview**
(`everglow-1c6db--pr-570-n55k5bd3.web.app`), not localhost: 16 progress events,
all from the Worker origin, position 600 → 615 s, `Server: Everglow`. This is
the deployed build talking to the deployed Worker over the real internet.

| Check | Result |
| --- | --- |
| `wrangler deploy` | uploaded, 37.25 KiB / 10.98 KiB gzip, 2 ms startup |
| `/health` | `ok` |
| Cinema movie (550) | 200 in 5126 ms (cold) |
| Cinema TV (1396 S1E1) | 200 in 3973 ms |
| App playback | progress 0 → 27 s, duration 8340 s, origin = Worker |
| Resume | `start=600` → progress starts at 600 |
| Open-relay attempt | 400, nothing fetched |
| Throughput vs direct | 1.8 Mbps through the Worker vs 1.9 Mbps direct — no overhead |
| Unit tests | 28 passed, 0 failed |

The thin buffer seen in the screenshot is the upstream, not the proxy: Fmov's
source delivers ~1.9 Mbps from here while the stream needs 2.4 Mbps. Direct
fetches show the same 1.9 Mbps.

## What changed vs the Firebase version

- `node:crypto` → WebCrypto. The MegaPlay AES-256-CBC decrypt is pinned against
  the same ciphertext the Firebase test uses, so the port is proven identical.
- Express `res` → `Response` + `ReadableStream` (Workers apply backpressure, so
  the manual reader loop is gone).
- Firestore stamp key → `CDN_STAMP_KEY` Worker secret. Fails closed when unset.
- The player's native bridge no longer hardcodes the Firebase host, so the
  Android WebView keeps reporting progress on any host.

Dropped on purpose: AnimePahe + `proxyAnimeSegment` (need a self-hosted API base
the app no longer offers), Firebase ID-token verification (optional before, and
the app never sends a token to these routes), DNS-based SSRF checks (no resolver
in Workers; the signed stamps already pin every URL), and per-IP rate limiting
(two viewers).

## App origin

The app now points at the Worker in five places: `animex_watch_page_config.dart`,
`animex_videasy_progress.dart`, `animex_player_native.dart` (`_allowedHosts`),
`cinema_video_sources.dart`, and `embed_webview.dart` (`isOwnedPlayerUrl`).

## Redeploy

```bash
cd cloudflare
npm ci
CLOUDFLARE_API_TOKEN=… npx wrangler deploy
```

`CDN_STAMP_KEY` is already set on the deployed Worker; `wrangler secret list`
shows it. Rotating it invalidates every in-flight stamped URL, which is safe —
the next resolve mints new ones.
