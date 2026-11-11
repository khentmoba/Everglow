# YumeZone server + in-player server picker

Synthetic fixture: the real `hlsPlayerHtml` output with a public test stream
(`test-streams.mux.dev`) and the real nine-entry YumeZone server list. No
couple data, no credentials, no Worker.

The nine names, in the order Clair sees them:

| Label | Upstream | Subs |
| --- | --- | --- |
| Dawn | Karl - 3 | hardsub |
| Ember | Goku | hardsub |
| Aurora | Nexus | hardsub |
| Lumen | Karl - 1 | softsub |
| Halo | Karl - 2 | softsub |
| Comet | Rin | softsub |
| Prism | Koto | softsub |
| Zenith | Riko | softsub |
| Solstice | Rudra (Multi) | softsub |

The labels are short, warm and light-themed to match Everglow, and say nothing
about the upstream — the provider name is ours to know, not something the
browser needs.

- `shot-phone.png` / `shot-tablet.png`: the picker open on a 390×844 phone and
  an 834×1112 tablet. Nine servers, "Dawn" highlighted as the active one.
  The chip sits in the same row as SUB/DUB/Episodes and uses the same `chip`
  style (21px tall, 10.5px label) — it is not a new visual language.
- `shot-phone-inapp.png`: the picker at 342×192, the real size of the in-app
  phone player (a 16:9 box inside a 390-wide page). Nine rows is 255px tall,
  so without a cap the menu's top landed at −123px and the first four rows —
  including the current server — were clipped and untappable. With
  `max-height:calc(100vh - 76px)` the menu sits at top 18px, bottom 134px,
  "Dawn" is tappable, and the rest scrolls (`scrollHeight` 255).
- `shot-phone-hud.png`: the same page with the menu closed, showing the
  "Servers" chip in place.
- `shot-phone-recover.png`: a picked server died and the stalled card is up.
  The chip is unreachable here — `#dead` is `.ov` at `z-index:8` with
  `inset:0`, the chip lives in `#hud` at `z-index:5`, and `elementFromPoint`
  at the chip's centre returns `dead`. So the player reopens the picker
  instead: the menu is `z-index:12`, sits above the card, and every row
  hit-tests to its own button. Without that, the only live control was
  Retry → `location.reload()`, which throws her pick away. The card also gets
  `padding-right:190px` in this state: measured at 342×192, the menu covered
  54% of Retry and now covers 0%, so "or retry here" is true.

The page is dark and the video is black, so the HUD reads faint in a
screenshot; the chip's computed style is identical to the existing "Episodes"
chip (`background: rgba(240,230,255,0.09)`, `color: rgb(255,245,245)`).

What these prove: the picker renders, lists every server, marks the current
one, stays hidden when a source has a single upstream, and fits the in-app
player. They do not prove a live YumeZone stream — that was checked separately
against the real API (see below).

## Progress and native wiring

`isAnimeXProxyPlayerUrl` is the single predicate behind eight call sites: the
web progress bridge, the native owned-player channel, and the skip/Next
buttons. `source=yumezone` was missing from its list, so a Yume frame would
have played while recording no resume point, reporting no watched episode, and
getting no skip or Next button — and on native it would have fallen back to
`EmbedWebView`, dropping every `post()` the page makes. It is in the list now,
and `animex_progress_bridge_test.dart` pins every resolver-backed source.

## Live check (read-only, real fetch)

`resolveYumeZone(21, 1, 'sub', …)` against the real site resolved through
Dawn (Karl - 3), and the Worker then served the whole chain:

- master → 2 sealed variant links, no `yumezone.live` / `flixcloud` /
  `rundowncdn` anywhere in the body
- variant → 370 sealed segment links, still no upstream host
- segment → `206`, `video/mp2t`, 1024 bytes (AES-128 ciphertext, as expected)
- `#EXT-X-KEY` rewritten to a sealed proxy URL

Every link's token opened to `{p: "yumezone", s: "https://yumezone.live/p/"}` —
a folder, not a URL, so the upstream path never appears.

## Checks

`flutter analyze`, 1,955 Flutter tests (`--exclude-tags="golden,network"`), all
16 `tool/ci/check_*.dart` guards, and 85 Worker tests passed.

Local note: the edit-time analyzer reports 30 "undefined class StatefulWidget /
State / visibleForTesting" errors in `animex_watch_page_config.dart`. They are
false positives — that file is `part of 'animex_watch_page.dart';`, which
imports `package:flutter/material.dart` and declares the part. `dart analyze`
on that file, on `lib/features/anime/`, and `flutter analyze` on the whole
project all report no issues. The reports came from analysis before
`flutter pub get` created `.dart_tool/package_config.json`.
