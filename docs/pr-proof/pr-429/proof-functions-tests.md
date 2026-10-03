# PR-429 proof — fix(anime): allow active Megavid CDN host

Functions-only change (no Flutter UI surface): `functions/anime.js` adds
`cdnx.aniwatchtv.site` to the Megavid HLS proxy allowlist so rewritten
playlists keep working now that Megavid serves segments from that CDN.
Visual screenshot: N/A (nothing renders differently; playback either
stalls on CORS or it doesn't).

Verification (all green):
- `node --test anime.test.js` — 22/22 pass, including:
  - `isMegavidHost only allows trusted Megavid hosts`
  - `rewriteMegavidPlaylist proxies the active ani.watch CDN`
- `node --test anime.test.js rules_static.test.js` — 36/36 pass
- `npm run lint -- --max-warnings=25` — 0 errors; `anime.js` +
  `anime.test.js` individually lint-clean
- Web boot check on this branch — clean, zero errors in flutter log
- `flutter analyze` unaffected (no Dart files touched)
