# Cinema: a third HLS source, and a server picker inside the player

Cinema's Everglow player had two upstreams — Fmov and VidBolt — and no way to
switch between them once it was playing. If both missed a title, the app fell
back to CineSrc, which is an ad-bearing embed.

This adds **Vidrock** as a third source and turns the player's own `Servers`
chip on for Cinema, so a dead stream costs a two-second swap instead of the
whole film.

## What changed

**`cloudflare/src/anime.js`**

- **`resolveVidrock`** — one fetch to `vidrock.net/api/movie/{tmdb}` (or
  `/api/tv/{tmdb}/{s}/{e}`) answers every server for the title. Each URL is
  AES-256-GCM under a key baked into Vidrock's player bundle, so
  `decryptVidrockUrl` opens it with WebCrypto. The leading `_` on the wire is
  part of the base64url alphabet, not a marker — dropping it corrupts the IV
  and the tag check fails.
- **It races with Fmov and VidBolt**, as one racer rather than three, because
  a single fetch answers all of its servers.
- **`CINEMA_SERVERS`** — the picker's fixed rows (Fmov ×4, VidBolt), with
  opaque ids and warm labels. The provider name is ours to know, not something
  the browser needs; same rule as the YumeZone table.
- **Vidrock's rows are dynamic.** Its API fills only the servers that carry
  the title and leaves the rest empty, and which ones are filled changes
  between requests — Atlas and Orion were live for one title and gone minutes
  later. A row is only listed when its server answered, because a button that
  can only fail is worse than no button.
- **`opts.server`** — a pick resolves that row and nothing else. An unknown id
  is refused rather than falling back to "whichever answers first", which is
  the opposite of what a pick means.
- **A pick gets a longer budget** (15 s, 12 s playlist) than the race (10 s).
  The player is already up and nothing else is racing, and Vidrock's CDN pulls
  from origin on a cold title — 6-10 s the first time we asked.

**`cloudflare/src/worker.js`**

- Passes `params.server` into `resolveCinema`.
- Playback headers now come from one `CINEMA_PROVIDERS` → `cinemaHeaders`
  table. The old explicit `fmov`/`vidbolt` branches meant a new provider
  verified with its own headers and then played back with Megavid's, which is
  exactly how Vidrock's CDN answered `Upstream 403`.

**`functions/hls_player.js`**

- The picker scrolls the row that is playing into view. The menu is capped to
  the player's height and the in-app phone frame is a 16:9 box, so with eight
  rows the current server opened below the fold. This also fixes the same
  latent problem on YumeZone's nine-row menu.

**`validateAnimeParams`** accepts a `server` for Cinema, checked against the
row table, so the picker can never build a row the Worker then refuses.

## Proof

All commands run locally on Node 24.22.2, `wrangler dev` on 127.0.0.1:8787.

**Unit tests** — `node --test src/anime.test.js src/yumezone.test.js`: 97 pass,
0 fail. The new ones decrypt three real Vidrock ciphertexts captured from its
API, prove an empty server never becomes a row, prove a pick touches no other
provider, prove an unknown row is refused, prove a slow Vidrock API never
delays a stream another provider found, prove a Vidrock-sealed URL plays back
with Vidrock headers, and prove the picker scrolls the current row into view.

**Live resolve** — real network, real Vidrock API:

```
movie 603   cur=cine-v1 rows=6 [Reel,Matinee,Marquee,Encore,Premiere,Cameo]
movie 27205 cur=cine-5 rows=7 [Reel,...,Premiere,Cameo,Lumiere]
tv 1399/1/1 cur=cine-v2 rows=6 [Reel,...,Premiere,Lumiere]
movie 155   cur=cine-v1 rows=6 [Reel,...,Premiere,Cameo]
```

Note the row count moves with what Vidrock actually has that minute, which is
the point.

**Playback through the proxy** — a picked Vidrock row, followed end to end:

```
pick cine-v2        code=200 t=2.05
playlist            code=200 size=130509  application/vnd.apple.mpegurl
segment             code=200 size=10654524
```

**In the player** (headless Chrome, muted):

- `picker-open.png` — The Matrix playing at 1264×625, `Servers` open, `Cameo`
  (Vidrock) marked current.
- `switched-to-reel.png` — tapped `Reel` (Fmov): new source, picture changed,
  playhead kept, `Reel` now current.
- `tv-episode-picker.png` — Game of Thrones S1 E1, six rows, `Lumiere`
  (Vidrock) current.
- `phone-picker-current-row.png` — 390×219, the size of the in-app phone
  player. Eight rows, current row six: the menu scrolled 27 px so `Cameo` is
  fully visible instead of clipped off the bottom.

Round trip measured in the page: `Cameo → Reel` reloaded at the same
playhead and reached `readyState 4` with no media error; `Reel → Cameo`
did the same back. The TV episode played to `t=12s` with no error. On the
phone viewport, picking `Cameo` played to `t=12s` with no error.

## Known limit

Vidrock's key and domains are theirs. If they rotate the key, every URL stops
opening and the resolver misses — the same failure a dead provider gives, and
`firstPlayable` already handles it by moving on. The captured ciphertexts in
the test file are static, so a rotation fails the suite loudly instead of
going quiet in production.
