# Everglow streaming Worker

Cloudflare replacement for the Firebase `proxyAnime` and `proxyMegavidHls`
functions. Same paths, same query params, same player page — the app only
changes its origin.

**Why:** Workers are not billed for bandwidth. A 1080p film is ~6.4 GB of
egress; on Firebase that is ~$0.76 per movie, here it is $0.

## What it serves

| Path | Does |
| --- | --- |
| `/proxyAnime?source=cinema\|megaplay\|everglow\|megavid&…` | Resolves the title and serves our HLS player page |
| `/proxyMegavidHls?u=<url>[&p=fmov\|vidbolt][&s=<stamp>]` | Streams playlists (rewritten), segments, keys, subtitles |
| `/health` | `ok` |

## Deliberately not ported

- **AnimePahe** and `proxyAnimeSegment` — they need a self-hosted API base the
  app no longer offers.
- **Firebase ID-token verification** — optional before, and the app never sends
  a token to these routes.
- **DNS-based SSRF checks** — Workers have no resolver. The signed stamps and
  host allowlists already pin every URL to one we handed out.
- **Per-IP rate limiting** — two viewers. Add Durable Objects if that changes.

## Deploy

```bash
cd cloudflare
npm ci

# One-time: the HMAC key for MegaPlay + Cinema URL stamps.
openssl rand -hex 32 | npx wrangler secret put CDN_STAMP_KEY

npx wrangler deploy
```

Wrangler prints the Worker URL (`https://everglow-stream.<account>.workers.dev`).
Keep it — the app needs it.

## Local development

```bash
cd cloudflare
npm ci
npx wrangler dev --var CDN_STAMP_KEY:local-proof-key
```

Then open a player page directly:

```text
http://127.0.0.1:8787/proxyAnime?source=cinema&type=movie&tmdbId=550&start=600
```

## Tests

```bash
cd cloudflare
node --test "src/**/*.test.js"
```

23 tests: parameter validation, host allowlists, stamp binding, playlist
rewriting, stream verification, the Cinema race and its budget, the MegaPlay
AES/HMAC port (pinned against the Firebase ciphertext), and the two Worker
handlers — including that an unstamped `fmov.my/api/proxy?url=…` is refused.

## After deploying

The app still points at Firebase. Flipping it is a separate change, and it must
happen **after** this is deployed, or Cinema and Anime break for Clair. That
flip touches:

- `animex_watch_page_config.dart` — `proxyAnimeBase`
- `cinema_video_sources.dart` — `proxyCinemaOrigin` / `proxyCinemaBase`
- `animex_videasy_progress.dart` — `animeXProxyOrigin`
- `embed_webview.dart` — `isOwnedPlayerUrl`
- `animex_player_native.dart` — `_allowedHosts`

Once the Worker is verified live, delete `proxyAnime` / `proxyMegavidHls` from
`functions/` so there is one implementation, not two.
