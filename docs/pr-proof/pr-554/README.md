# In-house HLS Player for MegaPlay (Everglow)

Previously, Everglow's primary anime server ("Everglow") embedded `https://megaplay.buzz/stream/ani/...` inside a third-party iframe. This had significant downsides:
1. MegaPlay actively blocks iframe sandboxing ("Sandboxed our player is not allowed. Remove sandbox to use it"), requiring unsandboxed execution that exposed users to popups, top-frame navigation, and ad trackers.
2. Because it was an external iframe embed, Everglow had no programmatic control over playback, in-place seeking (`supportsSeek: false`), or resume progress (`supportsResume: false`).

## Solution: In-House HLS Streaming

We upgraded the `Everglow` server option to use our ad-free resolver (`proxyAnime?source=megaplay`) backed by an in-house HLS.js player, matching the architecture used by platforms like Anikura:

- **Upstream extraction**: Server-side resolution in `functions/anime.js` extracts MegaPlay stream identifiers (`data-id`), queries `stream/getSources`, decrypts the AES-256-CBC payload (`enc`), and generates the HMAC-SHA256 authenticated token for the master `.m3u8` playlist.
- **HLS reverse proxy**: MegaPlay CDN media streams and WebVTT subtitle tracks are reverse-proxied with `proxyMegavidHls` / `isAnimeCdnHost` allowlisting (`nexabloom.top`, `eclipseharbor.world/space`, `emeralddrift.world/space`, `qeltrix.top`), injecting the required origin/referer headers and stripping CORS locks.
- **In-house HLS player**: Served cleanly via `hlsPlayerHtml` inside an isolated sandbox with zero ads, native custom player controls, in-place seeking (`supportsSeek: true`), and live progress reporting (`supportsResume: true`).

## Proof

- `anime-megaplay-hls-phone.png` — Release web build rendered at 430px mobile viewport in Agent Mode with `Everglow` server enabled as an in-house HLS player with full seek and resume support.
- All 370 Node function tests pass (`npm run verify` including lint, syntax, eval gate, and audit).
- All 1800 Flutter unit and widget tests pass (`flutter test --exclude-tags="golden,network"`).
- All 15 Dart CI guards pass (`dart tool/ci/check_*.dart`).
