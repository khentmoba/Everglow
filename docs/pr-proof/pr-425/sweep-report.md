# Bug Sweep Report — 2026-10-02

Goal: sweep the whole Everglow app (all features + functions + rules) and
fix bugs until no crash / high-severity issues remain.

- Scope chosen: whole app (all features + functions + rules).
- Stop rule chosen: no crash / high-severity bugs remain.
- Ship method chosen: single bugfix branch, grouped commits, one PR.
- Later direction (asked 2026-10-02, after zero-bug first pass): close with
  report, no PR for zero fixes; Khent verifies logged-in flows live.
  A real HIGH was found after that answer, so this PR ships the fix per the
  original ship method.
- Audited checkouts: `2fd6fe1a` (Sep 29, with unrelated tonight-planner WIP
  left untouched) for the broad sweep; `b75ed0fb` (origin/main, Oct 2) in a
  clean worktree for the fix + verification below.

## Verification runs (all green)

On the fix branch (`fix/canvas-stroke-crash-guards` @ `b75ed0fb`):

- `flutter analyze` — No issues found.
- `flutter test` — 1117 passed, 0 failed (includes 7 new canvas tests).
- `tool/ci/check_*.dart` — 12/12 green (model-guard pin added, see below).
- `functions` `npm test` — 254 passed, 0 failed, 1 skipped.
- `functions` `node eval_gate.js` — passed (136 eval cases, prompt v9).
- `functions` `npx eslint .` — 0 errors, 25 max-len warnings (pre-existing).
- Chrome (`flutter run -d web-server`): gateway boots clean, no console
  errors; `/preview-canvas-guard` renders hostile stroke data with
  `parsed point counts: 2, 0, 2, 0` and zero console errors
  (see `shot-canvas-guard.png`, fake data only; temp route reverted).

## Ranked findings

### HIGH (fixed in this PR): malformed canvas stroke bricks shared canvas

- Where: `lib/features/canvas/domain/models/doodle_stroke.dart`
  `DoodleStroke.fromFirestore` — `(data['points'] as List)` threw when
  points was missing/null/non-list; `(p['x'] as num)` threw on any
  malformed point; `color`/`userId` passed non-strings through;
  `createdAt as Timestamp?` threw on non-Timestamp values.
- Blast radius: `CanvasService.getStrokesStream()` maps EVERY doc through
  it (`canvas_service.dart:20,53`). One bad doc in `canvas_strokes` (no
  shape validation in `firestore.rules`) → whole canvas shows
  `EverglowErrorState('Could not load canvas: …')` for BOTH partners and
  retry cannot help (same bad doc). The eraser path
  (`canvas_screen.dart:470`, `.first.then` with no error handler) also
  dies with an unhandled async error.
- Repro (before fix): `flutter test
  test/features/canvas/doodle_stroke_test.dart` → 6 failures, all throwing
  from `doodle_stroke.dart:44`. After fix: 12/12 pass.
- Fix: tolerant `_parsePoints` (skips bad entries, bad shapes → empty),
  `is`-checked `_toStr`/`_toDouble` helpers, `is Timestamp` createdAt,
  `fromFirestore` delegates to a unit-testable `fromMap` (repo convention,
  cf. `BookItem`/`MiniGame`). No caller changes. Downstream is safe:
  painter returns early on <2 points / empty annotation; eraser `!` reads
  sanitizer-built maps.
- Regression pin: added `test/features/canvas/doodle_stroke_test.dart`
  (`frommap`, `malformed`) to `tool/ci/check_model_guards.dart` — the
  exact #107-#110 class that guard exists for.

### LOW (fixed in this PR): stale server version string

- Where: `functions/common.js` `APP_VERSION = '6.0.0+1'` vs pubspec +
  `AppVersion.current` at `6.1.0+1`. Served only by the `health` endpoint
  and shown only in the creator debug tab (`creator_system_tab.dart:258`);
  no version comparison anywhere, so cosmetic.
- Fix: one-line bump to `6.1.0+1`. Note for next release: the release-sync
  guard does not cover `functions/common.js`, which is how it drifted.

### Traced and cleared (no bug — guards verified by reading)

- `trailer_section.dart:175` `double.parse(rating)` — guarded by
  `double.tryParse` check on the line above.
- `calendar_event.dart` / `journal_entry.dart` / `chat_message.dart` /
  `money_entry.dart` / `milestone.dart` / `media_item.dart` /
  `memory_photo.dart` / `manga_item.dart` / `book_item.dart` /
  `our_books_item.dart` / `garden_stats.dart` / `mini_game.dart`
  `DateTime.parse` — all inside try/catch or `is`-checked helpers.
- `canvas_painter.dart` `_parseColor` — try/catch with roseQuartz fallback.
- `snapshot.data!` ×5 (`gallery_preview`, `partner_status_indicator`,
  `books_preview`, `temporary_chat_panel`, `game_board_screen`) — all
  behind `hasData`/`hasError` checks; `GameMatch.fromFirestore` tolerates
  null data (`?? const {}`).
- `animex_home_page.dart` `_rows[…]!` — map fully built synchronously in
  `_buildSections()` before first frame.
- `journal_ui.dart` `author[0]`, `incoming_watch_party_banner.dart`
  `callerName[0]` — both behind `isNotEmpty`.
- `watch_party_room.dart` `sorted[0]/[1]` — always exactly 2 elements.
- `motchi_web_bridge_web.dart` speech `results[0][0]` — inside try/catch
  completing null.
- Functions auth: `proxyAI`/`proxyAIv2` (`requireAuth`), video/watch
  streams, Spotify, gallery, books, music proxies all authed; anime +
  catalog + Megavid HLS anonymous-tolerant BY DESIGN with per-IP rate
  limits; Megavid target allowlisted (`isMegavidHost` + public-DNS check);
  catalog upstreams allowlisted (`resolveCatalogUpstream`).
- `study_set_service.dart` unguarded casts — safe in practice: server
  (`motchi_study.js`) strictly validates (exactly 4 options, valid index)
  before responding.
- `book_catalog_service.dart`, `watch_party_server_service.dart`,
  `animex_stores.dart` (`try` in `load()`), `episode_drawer_state_base`
  casts — all `is`-guarded or try/caught.
- Fresh commits reviewed: #405 (Motchi TTFT), #406 (anime resume),
  #407 (seasons), #408/#409 — tested, clean. Main also shipped #419
  (audit nine issues), #420-#424 since the Sep 29 checkout.
- `firestore.rules` + `storage.rules` read in full: couple-only intact,
  cinema profiles contained, server-only collections denied.

### Noted, not touched (unrelated WIP on `feat/tonight-decision-planner`)

- Temp preview routes (`temp_preview_tonight.dart`) wired as public paths
  in the tonight branch — must be reverted before that PR merges.
- `tonight_service.dart` `!` uses — WIP files, not audited here.

## Still unverified (handed to Khent per his direction)

Logged-in runtime flows in Chrome (cinema playback, chat, gallery,
journal, garden, dashboard Together zone on phone/tablet) could not be
exercised without a passcode. Static audit + 1117 widget/unit tests +
12 CI guards + clean logged-out boot cover them indirectly; Khent
verifies live on the site.
