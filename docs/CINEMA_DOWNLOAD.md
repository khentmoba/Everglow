# Cinema download button — what can actually be built

**Status:** decision needed before code. Nothing here is shipped yet.

Khent's ask: a Download button in the cinema, so when Clair is watching
something she can just keep it. Torrents were suggested. This note records
what the code can and cannot hand to her, and the one small thing worth
building.

## The fact everything follows from

The cinema does not play a file. It plays another site's page inside an
iframe:

- Sources are embed pages, not media: `everglow-embed` is our own wrapper
  (`https://everglow-1c6db.web.app/embed.html`), and the wrapper loads
  `https://cinesrc.st/embed/movie/<tmdbId>` in an inner iframe
  (`web/embed.js:9`, `web/embed.js:12`, `web/embed.js:206`).
- That inner document is a different origin, so Everglow can never read its
  `<video>` element, its `.m3u8`, or its segments. The browser forbids it,
  and the wrapper page has no server behind it to ask.
- The only place Everglow does hold video bytes is the Watch Party HLS path
  through `proxyWatchStream` (`functions/media_proxy_video.js:22`,
  `functions/watch_stream_access.js:5`). Cinema never uses that path.

So a Download button in the cinema has no file in hand. Everything below is
about where a file could come from, and what a phone can do with it.

## Why torrents are not the integration

- A magnet link is a handoff to an app on the device. iPhone has no torrent
  app registered for `magnet:` at all, and Android only if one is installed.
  On Clair's phone and tablet, the button would do nothing. That is the
  whole feature failing for the person it is for.
- It cannot hand over "the thing I am watching". A torrent gets you a file
  found by name, not the stream currently playing, so the season, episode,
  cut, and subtitles can all differ.
- Finding that file per title needs a torrent index. That is piracy search
  plumbing inside a public repo, inside an app family guests use. One-way
  door, and not needed to give Clair offline movies.

## The three real doors

| Door | How it works | Works on Clair's phone | Cost | Risk |
|---|---|---|---|---|
| **1. Direct-file handoff** | A source resolves to a single `.mp4`. The player asks the helper for a signed link and lets the browser save it. | Yes. iOS Safari saves a single video file to Downloads, with progress. | Small: one config field, one button, one signed-link call. | Needs a host that serves a single file, not a playlist. |
| **2. Save the HLS stream** | Fetch the playlist and every segment through `proxyWatchStream`, stitch into one file in the browser. | No. A multi-GB blob cannot be saved reliably on iOS, and there is no save-file picker on mobile. | Large: stitcher, progress, retries, storage. | Multi-GB bodies through request-based functions will not finish inside their limits. |
| **3. Torrent handoff** | Magnet link plus an index to find one. | No (see above). | Small UI, large legal and plumbing risk. | Piracy index in a public, family-shared app. |

## Recommendation

**Door 1, or nothing.** It is the only version where tapping Download ends
with a file on Clair's phone, and it keeps piracy search out of the app.

Smallest shape that makes it real:

- Add optional `movieDownloadUrl` / `tvDownloadUrl` templates to
  `VideoSourceConfig` (`lib/features/cinema/data/models/video_source_config.dart`),
  read from the same `config/video_sources` document that already drives the
  source list. No new collection, no new key.
- The player top bar gets a Download pill beside Theater mode. It is shown
  only when the active source carries a template, so Clair never sees a dead
  button.
- Tap → ask the helper for a short-lived signed link (same signing already
  used by `proxyWatchStream`), then save it with the existing browser-save
  helper pattern (`lib/features/books/data/services/book_download_helper_web.dart`).
- Episodes expand `{season}` / `{episode}`; movies ignore them.

That is a real button the day Khent has one direct-file host. Without such a
host it stays hidden, which is the correct behaviour.

## The legal fallback, if we want something today

Modern movies do not download from a browser. They download from Netflix,
Prime, or Apple, on the account that owns them. TMDB already tells us which
service carries a title, so a Download sheet could open that title in the
right app — the one place a phone download genuinely works offline. Honest,
legal, small; not the pirate copy Khent pictured.

## Decision

Which door: 1 (recommended), 2, 3, or the legal fallback? Once that is
settled the code is a small change, and the proof is a real file saved on a
phone-width browser.
