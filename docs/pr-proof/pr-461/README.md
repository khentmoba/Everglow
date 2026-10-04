# Proof shots — PR #461

Chrome at 430px width, synthetic demo episodes only (no real couple data).

| Shot | What it shows |
| --- | --- |
| `cinema-1-spoilers-hidden-430.png` | Cinema drawer, spoilers hidden. Stills visible, titles and stories not. |
| `cinema-2-revealed-inline-430.png` | One cinema episode revealed in place. No drawer over the list. |
| `cinema-3-collapsed-430.png` | Same row after "Hide details". |
| `cinema-4-spoilers-off-430.png` | Spoilers off: full title + story, no overflow stripe. |
| `animex-1-spoilers-hidden-430.png` | AnimeX mobile rail + desktop sidebar, spoilers hidden. Stills visible on both. |
| `animex-2-revealed-inline-430.png` | AnimeX mobile card revealed in place; the neighbouring episode stays hidden. |

The AnimeX **desktop** row's reveal is not screenshotted — see the PR body.
Its behaviour is covered by `test/features/anime/animex_spoilers_test.dart`.