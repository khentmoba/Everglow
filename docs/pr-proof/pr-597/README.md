# Cinema server picker — after dropping Vidrock

Proof for the change that removes Vidrock and keeps the picker.

## Why Vidrock went

The same endpoint answers in two shapes depending on who asks:

| Caller | Shape | URLs |
| --- | --- | --- |
| A home connection | `Nova`, `Atlas`, … | AES-sealed, real, different per title |
| Cloudflare's edge | `source1..source5` | plain, **the same Bunny CDN link for every title**, and it 403s |

Measured from the edge with `wrangler dev --remote`, three different titles
(603, 27205, 155) all returned
`https://vz-61b02ce5-177.b-cdn.net/73baff63-b049-4e7c-8034-e5e9aa76123f/playlist.m3u8`,
and that URL answers `403 Forbidden` (BunnyCDN, no cache header) to every
header combination tried, including Vidrock's own `Origin`/`Referer`.

So the rows it produced were buttons that could only fail. The five rows that
actually play — Fmov's four sources and VidBolt — are what the picker keeps.

## What the picker does now

`servers` is a list of lazy `format=json` URLs, one per row. The player fetches
one only when it is picked, so a resolve still costs one fetch and one
verification.

## Evidence

Both shots are from the **deployed Worker** at
`everglow-stream.khentplaysmoba.workers.dev`, headless Chrome, muted, at
**390×219** — the size of the in-app phone player.

- `live-phone-picker.png` — The Matrix playing at `00:09 / 136:17`, `Servers`
  open, five rows, `Marquee` marked current.
- `live-phone-switched-to-reel.png` — tapped `Reel`: the picture changed, the
  playhead kept running (24 s → 36 s), `Reel` is now current.

Measured in the page, not inferred: the switch changed `currentSrc` and
reached `readyState 4` with no media error. `scrollHeight 147` against
`clientHeight 141` on the phone frame, with the current row fully visible.

## Live resolve, deployed Worker

```
health                     ok
movie 603     cur=cine-1  rows=5  [Reel,Matinee,Marquee,Encore,Premiere]  2.7 s
movie 155     cur=cine-1  rows=5  [...]                                    3.8 s
tv 1399/1/1   cur=cine-3  rows=5  [...]                                    4.8 s
pick cine-1               200, current=cine-1                              2.1 s
pick cine-3               200, current=cine-3                              3.0 s
```

`cine-2`, `cine-4` and `cine-5` answered `502` in about 0.4 s for this title —
those sources have nothing for The Matrix right now, which is the documented
behaviour: a row that has nothing fails in about a second, and the player keeps
the stream it was already playing.

## Checks

- `node --test src/anime.test.js src/yumezone.test.js` — 106 pass, 0 fail
- `flutter analyze` — clean
- all `dart tool/ci/check_*.dart` — pass
- `flutter test --exclude-tags="golden,network"` — 1964 pass
- `cd functions && npm test` — 380 pass, 5 skipped
- `wrangler deploy` — uploaded, 100.71 KiB / 27.88 KiB gzip, 2 ms startup
