# Everglow's in-player server picker

Synthetic fixture: the real `hlsPlayerHtml` output with a public test stream
(`test-streams.mux.dev`) and the real eleven-entry picker list built by
`everglowServerLinks`. No couple data, no credentials, no Worker.

The eleven names, in the order Clair sees them:

| Label | Upstream | Picker id |
| --- | --- | --- |
| Nova | MegaPlay | `megaplay` |
| Iris | Megavid | `megavid` |
| Dawn | YumeZone · Karl - 3 | `yume-1` |
| Celestia | YumeZone · Goku | `yume-2` |
| Aurora | YumeZone · Nexus | `yume-3` |
| Lumen | YumeZone · Karl - 1 | `yume-4` |
| Halo | YumeZone · Karl - 2 | `yume-5` |
| Comet | YumeZone · Rin | `yume-6` |
| Prism | YumeZone · Koto | `yume-7` |
| Zenith | YumeZone · Riko | `yume-8` |
| Solstice | YumeZone · Rudra (Multi) | `yume-9` |

- `shot-phone-before.png`: what `source=everglow` served until now. One
  upstream, so `servers` was empty and the page hid the Servers chip entirely —
  the bug. Same fixture, same stream, `servers: []`.
- `shot-phone.png`: the same page at 390×844 with the real eleven-entry list.
  Nova is highlighted as the current server. The menu is 311px tall, sits at
  y=475 and clears the control bar.
- `shot-inapp.png`: 342×192, the real size of the in-app phone player (a 16:9
  box inside a 390-wide page). `max-height:calc(100vh - 76px)` caps the menu at
  116px, so it sits at y=18 and scrolls (`scrollHeight` 309) instead of running
  off the top. "Nova" hit-tests to its own row.

The page is dark and the video is black, so the HUD reads faint; the chip's
computed style is unchanged from the existing "Episodes" chip.

What these prove: the picker renders on Everglow, lists all eleven streams
under the new aliases, marks the current one, and fits the in-app player. They
do not prove a live resolve from MegaPlay, Megavid, or YumeZone — the Worker
tests cover the walk, and the Worker is not deployed yet.

## App-side row

The watch page's server row is not in these shots. A local web run needs
`assets/env.txt`, which agents must not copy, so the row is pinned by the
widget test `renders the new server list and sub/dub toggle` instead: it renders
the real screen and asserts `Everglow` findsOneWidget with `Megavid` and `Yume`
findsNothing.
