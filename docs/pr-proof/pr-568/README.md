# In-house HLS Player for Cinema Everglow Server

Previously, Cinema's primary `Everglow` server (`everglow-embed`) wrapped `cinesrc.st` inside `web/embed.html`, while Anime's `Everglow` server used our in-house HLS.js player (`hlsPlayerHtml`) via `/proxyAnime` and `/proxyMegavidHls`.

## Solution

We upgraded Cinema's `Everglow` server (`CinemaVideoSources.everglowEmbed`) to run on the same in-house HLS player and Cloud Function proxy architecture (`proxyAnime?source=cinema`) as Anime:

- **Server-side Cinema HLS resolution (`functions/anime.js`)**: `resolveCinema` resolves `.m3u8` HLS streams and WebVTT subtitle tracks for TMDB movies and TV episodes across Fmov (`valence`, `vector`, `core`, `titan`) with automatic fallback to VidBolt (`orion`, `vega`, `callisto`), verifies stream playability (`verifyCinemaStream`), prioritizes English WebVTT subtitles (`selectCinemaSubtitleTracks`), rewrites playlists/segments through `/proxyMegavidHls`, and serves `hlsPlayerHtml`.
- **Client integration (`lib/features/cinema/`)**: `CinemaVideoSources.everglowEmbed` builds `/proxyAnime?source=cinema` URLs with `?start=` resume support, parses `animex-progress` events for Continue Watching and Up Next, and auto-advances to `CineSrc` (`flux-cinesrc`) on `animex-content-error` if a title has no HLS stream.

## Proof

- `cinema-everglow-hls-phone.png` — Release web build at 430px phone viewport in Agent Mode with HUD collapsed, showing `Fight Club` loaded in the in-house Everglow HLS player (`0:00 / 2:19:00`) with `Server: Everglow` active.
