# Anime playback on the Megavid CDN

Every anime episode was dead on the live site while the catalog still worked.
`proxyAnime` answered with the failover page ("no playable stream sources"), so
the app moved on to the next server and Clair got a grey box.

Two things changed on Megavid's side, both verified from this machine:

1. The video CDN moved to `s-90.megavid.se`. Our host allowlist only knew
   `megavid.buzz`, `cdn.api-webs.com` and `cdnx.aniwatchtv.site`, so
   `proxyMegavidHls` refused the new host with `Host not allowed`.
2. The CDN now answers only for Megavid's own origin. The identical request
   with `Referer` but without `Origin` comes back `403 forbidden`.

Live before the fix (`https://us-central1-everglow-1c6db.cloudfunctions.net`):

```text
proxyAnime?source=megavid&anilistId=21&ep=1  -> 502
  "Episode unavailable - No stream found - try another server.
   no playable stream sources - try another server."
proxyMegavidHls?u=<s-90.megavid.se/...>       -> 400 {"error":"Host not allowed"}
```

Last successful `proxyAnime` in Cloud Logging: 2026-10-19T16:14Z.

## Proof shots

Both shots come from the same local setup: the Firebase functions emulator
running this branch, a small local bridge that maps the emulator's function
path prefix, and a disposable Chrome from `tool/perf/_harness.mjs` at 430x932.
The player page is the real one the app embeds; the episode is One Piece
episode 1.

- `anime-player-before.png` - the branch without the fix. The page has no
  video element at all: "Episode unavailable / no playable stream sources".
- `anime-player-after.png` - the branch with the fix. The video element is
  present and playing: `readyState 4`, `currentTime 19.5s`, `paused false`,
  `1440x1080`, and the frame above is a real decoded video frame.
- `anime-player-live.png` - the same player on the deployed function
  (`https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAnime?
  source=megavid&anilistId=21&ep=1&audio=sub`), captured after this merged:
  `readyState 4`, `currentTime 22.9s`, `paused false`, `1440x1080`.

What this proves: the episode streams again through our own domain. It does
not prove signed-in catalog coverage - AniList and Jikan were both down while
this was written (AniList came back during the work, Jikan is still timing
out) - and it does not prove playback inside the Flutter app itself, which
needs a signed-in session.
