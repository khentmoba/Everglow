# Everglow is back in the cinema picker

Proof for the change that brings the Everglow HLS row back and adds a working
Everglow player shell.

## What the shots show

- `shot-picker.png`: the Switch Source sheet at 430px phone width. It lists
  `Everglow Player` (selected), `Everglow` (the HLS row, back), `CineSrc`,
  `VidCore` and `VidLink`.
- `shot-wrapper.png`: our own `web/embed.html` shell opened top level at the
  same width, loading the CineSrc upstream ("Fetching Media"). This is the
  player the `Everglow Player` row opens.

Both shots come from a local release build of this branch
(`dart tool/build_web.dart -- --release --no-source-maps`), served over
loopback and opened in headless Chrome with `--mute-audio`. The picker shot
used `/cinema/video/603?type=movie&title=Inception&agent=1`. Agent Mode uses
fake in-memory demo data; no couple data is in these shots.

## Why the shell is a separate shot

`everglow-1c6db.web.app/embed.html` answers
`X-Frame-Options: SAMEORIGIN`. The real app is served from that same origin,
so the iframe works there. A local build runs on `127.0.0.1`, which is a
different origin, so Chrome refuses to frame the live wrapper and the local
player area shows a broken poster. Opening the copy in `build/web` top level
shows the shell itself loading the upstream. Playback on the live site is not
proven by these shots.

## What the HLS row does today

The live Worker still answers `resolve 502, rows=0` for all three cinema smoke
titles. fmov.my times out and vidbolt.xyz blocks Cloudflare's edge. Tapping the
`Everglow` row therefore fails and the app falls through to `Everglow Player`.
The HLS row starts working on its own when a cinema upstream answers from the
edge again; no app change is needed.
