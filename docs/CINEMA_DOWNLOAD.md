# Cinema download button — torrent copies

**Decision (Khent, 28 Oct 2026):** torrents. This is what shipped, what it
does on each device, and the one step still missing for offline on a phone.

## What the button does

```text
player top bar → Download
  IMDB id for the title        movie: already on TMDB details
                               series: one /external_ids call, cached
  index lookup via proxyCatalog  stream/movie/tt0137523.json
                                 stream/series/tt0947…:1:1.json
  sheet lists copies, best seeded first
    quality · size · seeds · index
    tap → opens the magnet in a torrent app
    link icon → copies the magnet
```

Every action in the sheet is real. If the device has no torrent app the
magnet cannot open, so the row copies the link instead of failing quietly.

## Where it lives

- `lib/features/cinema/data/services/torrent_index_service.dart` — lookup,
  magnet building, sorting, dedupe.
- `lib/features/cinema/presentation/widgets/torrent_download_sheet.dart` —
  the list and its actions.
- `functions/media_proxy_catalog.js` — the `torrentio` base. The browser
  never talks to an index host directly, same rule as TMDB, Jikan, ani.zip.
- Agent Mode shows three demo copies, so preview builds and proof
  screenshots never call a real index.

## What it does not do

- **It does not put a file on the phone by itself.** A magnet needs a
  torrent client. Desktop and most Androids answer; iPhone has no handler,
  so the link is copied. That gap is a device limit, not a bug in the sheet.
- **It does not resume, measure progress, or keep a library.** The torrent
  client owns that once the link leaves the app.
- **It does not pick a copy for you.** Quality and size are shown; seeding
  decides the order. A 4K remux is 15–70 GB, so the top row is not always
  the right tap.

## The missing step for Clair's phone

To make a tap on her phone end with a saved episode, Everglow needs a small
box that owns the torrent: qBittorrent or Transmission on the same machine
that hosts the media, reachable from the app. Then the button becomes
"send to my box" and the file lands there, ready to stream or copy, with
progress the app can read.

That is a second, small change: one setting (box URL + token, stored like
the watch-party servers, never committed) and one POST. It is worth doing
only if the box exists — otherwise it is machinery with no water.
