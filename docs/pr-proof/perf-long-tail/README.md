# Long-tail coverage — proof

## Every feature is accounted for

`app_router.dart` treats `/` as the only public path and bounces every other
route to the gateway when logged out. **No feature screen is reachable by the
headless bench** — not an incomplete harness, just no unauthenticated path to
any of them. So per-screen FPS numbers are a phone check, and coverage here is
stated as mechanical + examined rather than invented.

## Mechanical coverage: five guards, all of `lib/` (620 files, 528 in features)

| guard | blocks |
| --- | --- |
| `check_image_fallback.dart` | bare `Image.network` without `errorBuilder`; without `cacheWidth` per call site |
| `check_stream_limits.dart` | unbounded `snapshots()` |
| `check_perf_rules.dart` | `setState` driven by a frame-rate callback |
| `check_perf_notes.dart` | **new** — PERF_NOTES citing a path that no longer exists |
| `check_assets.dart` | asset references that do not resolve |

Full per-feature inventory (files, bare `Image.network`, `snapshots()`,
unbounded waivers) is in `docs/PERF_NOTES.md`. Two facts worth stating plainly:

- **Zero unbounded-stream waivers exist anywhere in the app.** Every
  `snapshots()` is bounded, so the `#36`/`#55` class cannot return without a
  deliberate, visible waiver.
- The **five** remaining bare `Image.network` calls are all deliberate keeps
  (`creator_memories_tab` x2 with cacheWidth 200/600, `photo_viewer_screen` x2
  full-screen zoom, `reader_page_image` x1 manga pages).

## New guard: `check_perf_notes.dart`

This one closes the failure class that cost the most time in this pass and had
**no** guard: `docs/PERF_NOTES.md` is the source of truth for perf work, and a
claim in it that no longer matches the code sends the next reader hunting for a
deleted tool. It happened four separate times — a documented frame meter deleted
in `cfa3c9c1`, a `DeferredSection` "web branch" that had been removed, a cursor
glow that no longer starts at init, and a sparkles widget that no longer exists.

It checks every path the document cites (rooted paths *and* bare Dart
filenames) still resolves.

**Verified it fails**, twice:

| injected stale citation | result |
| --- | --- |
| `lib/shared/widgets/everglow/everglow_sparkles.dart` + `tool/perf/measure_scroll.mjs` | both caught (both genuinely deleted) |
| bare `deleted_widget_thing.dart` | caught |

**And it immediately found a real one in the document** — two citations of the
deleted sparkles widget, including the original stale entry in the "Shipped"
list. Both are now marked stale in place rather than silently deleted.

One narrowing was needed: the first version also flagged bare `.js`/`.mjs`
citations and produced 5 false hits on `hls.js`, `sw.js`, `cat_3d_engine.js`
and friends — those load from a CDN or npm and are not repo files. Restricted to
Dart, where the stale-widget class actually lives.

## Examined rather than assumed

Beyond mechanical coverage: dashboard (causes re-verified, laziness pinned by 8
passing tests), cinema/anime/manga/books (`cacheWidth` swept against display
size, no violations), chat/ai (`AnimatedBuilder` streaming confirmed, privacy
rules re-verified), gallery/journal (grid decode sizing confirmed), tonight
(real defect found and fixed), shared widgets (skeleton/cursor-glow/blur rules
confirmed in place), boot path (3 runs x 3 profiles, link shaping rebuilt).

## Explicitly out of scope, with reasons

| not done | why |
| --- | --- |
| per-feature FPS/jank | unreachable headlessly; desktop GPU can't give a DPR-3 verdict |
| full-screen painter frame rates | real phone win, invisible here (0.03ms), cadence change risks looking choppy with no way to check |
| SW cache-first for the shell | fixes the 134s repeat boot, but changes deploy semantics — Khent's call |
| `kIsWeb ? null : N` avatar workaround | verified obsolete on Chromium, unverified on Safari where failure is a visible grey avatar |

Checks: `flutter analyze` clean · `flutter test` 1410 passed · all 14 guards pass.
