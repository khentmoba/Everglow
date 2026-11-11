# Everglow streaming Worker

Cloudflare replacement for the Firebase `proxyAnime` and `proxyMegavidHls`
functions. Same paths and same player page — the app only changed its origin,
and it has already been flipped.

**Why:** Workers are not billed for bandwidth. A 1080p film is ~6.4 GB of
egress; on Firebase that is ~$0.76 per movie, here it is $0.

## What it serves

| Path | Does |
| --- | --- |
| `/proxyAnime?source=cinema\|megaplay\|everglow\|megavid\|yumezone&…` | Resolves the title and serves our HLS player page |
| `/proxyMegavidHls?t=<sealed token>[&r=\|&rr=&rq=]` | Streams playlists (rewritten), segments, keys, subtitles |
| `/health` | `ok` |

`format=json` on `/proxyAnime` answers `{src, tracks, title, ep, servers, current}`
instead of the page. `servers` is the player's own picker list; it is empty for
every source that has a single upstream, which is what hides the picker there.

## How the sealed transport works (read before touching it)

Every upstream URL the browser ever sees is a token: AES-GCM over
`{p: provider, s: folder, r: relay endpoint}`, base64url in `?t=`. The GCM tag
is the MAC, so a token cannot be forged or re-scoped, and **no host or path is
printed into a playlist at all**. A Worker with no `CDN_STAMP_KEY` mints
nothing and accepts nothing — it fails closed.

A token covers a folder, not a single URL, so a 1,043-segment film costs one
seal. Two upstreams run open "fetch anything" relays (`fmov.my/api/proxy?url=…`,
VidBolt's `*.workers.dev` bridges). A token over a relay's own folder would
vouch for every URL on the internet — that shipped once as an HMAC bug and was
caught in review. So:

- Relay URLs are sealed over the relay's exact endpoint plus the folder of the
  URL it fetches. Exactly one `url=`; only `referer`/`origin` may carry other URLs.
- Relay hosts never get a plain folder seal.
- The Worker re-derives and checks every target itself (`scopedTarget` +
  `stampParts`), then requires the rebuilt URL to still sit under the sealed
  folder and — in relay mode — to still name the sealed endpoint. Both are
  positive checks, so no encoding trick widens the scope.
- The remainder (`r` / `rr`) is decoded and rejected if it can climb out with
  `..`, a leading `/`, or a nested `://`.

The player page is `functions/hls_player.js`, shared with Firebase. Change it
there, never copy it.

## YumeZone (`source=yumezone`)

`cloudflare/src/yumezone.js` holds only the wire protocol (signature, response
cipher, server table, headers); `resolveYumeZone` in `anime.js` does the
orchestration. YumeZone keys on AniList ids, so there is no TMDB or MAL path.

It runs nine upstreams, and the player shows them as an in-page picker rather
than as nine rows in the app's server list. The picker is lazy: each entry is a
URL back to `/proxyAnime?source=yumezone&format=json&server=<id>`, fetched only
when it is tapped, and the playhead is kept across the swap.

Server order depends on audio. Our player renders `<track>` captions only as
WebVTT and YumeZone ships ASS/SRT, so **subbed** audio leads with the hardsub
servers (Dawn, Ember, Aurora) — a softsub server would play with no subtitles at all.
**Dubbed** audio leads with the softsub servers, because burned-in English over
English audio is noise. YumeZone subtitle tracks are therefore not served.

## Deliberately not ported

- **AnimePahe** and `proxyAnimeSegment` — they need a self-hosted API base the
  app no longer offers.
- **Firebase ID-token verification** — optional before, and the app never sends
  a token to these routes.
- **DNS-based SSRF checks** — Workers have no resolver. The sealed tokens and
  host allowlists already pin every URL to one we handed out.
- **Per-IP rate limiting** — two viewers. Add Durable Objects if that changes.

## Deploy

```bash
cd cloudflare
npm ci

# One-time: the AES-GCM key for every sealed URL.
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
node --test "src/*.test.js"
```

85 tests: parameter validation, host allowlists, seal binding and scope
enforcement, playlist rewriting, stream verification, the Cinema race and its
budget, the MegaPlay AES/HMAC port (pinned against the Firebase ciphertext),
the YumeZone wire protocol (signature, cipher, server order) and its resolver,
the in-page server picker, and the two Worker handlers — including that a real
token lifted from a public player page can not point fmov's relay anywhere else,
and that a keyless Worker is closed rather than open.

## After deploying

The app already points here: `animex_watch_page_config.dart` (`proxyAnimeBase`)
and `cinema_video_sources.dart` (`proxyCinemaOrigin` / `proxyCinemaBase`).
Changing those is a separate, deliberate change — they are what makes Cinema and
Anime work for Clair.

Once the Worker is verified live, delete `proxyAnime` / `proxyMegavidHls` from
`functions/` so there is one implementation, not two.
