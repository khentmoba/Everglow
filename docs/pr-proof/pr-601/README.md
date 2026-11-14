# Cinema source picker after retiring the dead Everglow HLS row

Proof for the change that stops offering the Everglow HLS row in cinema.

## Where the shots came from

A local release build of this branch (`dart tool/build_web.dart --
--release --no-source-maps`), served over loopback and opened in headless
Chrome with `--mute-audio` at 430px phone width. The URL was
`/cinema/video/603?type=movie&title=Inception&agent=1`. Agent Mode uses fake
in-memory demo data; no couple data is in these shots.

- `shot-server.png` — the player page. The server row reads `Server: CineSrc`.
- `shot-picker.png` — the Switch Source sheet open. It lists CineSrc
  (selected), VidCore and VidLink. There is no Everglow row.

## Before the change

The live Worker answers for every cinema smoke title:

```text
movie 603        FAIL (resolve 502)  rows=0
movie 155        FAIL (resolve 502)  rows=0
tv 1399 s1e1     FAIL (resolve 502)  rows=0
```

fmov.my times out and vidbolt.xyz refuses the Cloudflare edge, so the
Everglow HLS player had no stream to resolve. The app fell back to CineSrc
after showing a failure card. The anime cases in the same smoke still play,
so this is a cinema upstream outage, not a Worker failure.
