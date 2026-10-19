# Audit fixes

This change addresses the eight findings from the repository audit. It does not deploy the app or change live records.

## Behavior

- Watch Together exchanges a Firebase-authenticated request for a signed media URL. The URL expires after six hours and grants access only to its signed target. Playlists sign their nested playlists, segments, keys and init files. Public-network checks still run on every upstream request and redirect. Byte-range responses remain intact.
- Each approved account has one server-only signing key in `watch_stream_keys`. Deleting that document revokes its outstanding media links. No new environment secret is required. The player authorizes before either native Safari playback or hls.js starts.
- Motchi trip creation and editing use `notes`, `budgetTotal` and embedded `places`, like Trip Kit. Place additions use a transaction. Trip Kit can read old `description` and `budgetEstimate` fields when their replacements are absent. Explicit empty notes or a zero budget still win.
- Calendar's late subscribers receive the cached event list without notifying existing subscribers again. While this branch was open, PR #534 fixed that issue on `main`. This branch retains that shared-listener fix and adds a regression test instead of replacing it.
- Motchi reads the Money screen's `createdAt`, `author`, `type` and `note` fields. Month boundaries and subscription countdowns use Philippine dates.
- Book writers use the same SHA-256 document ID and a transaction. Existing random-ID records are reused. Saving a book never resets either partner's reading flags. Archive and Gutenberg books without Open Library work keys keep their archive identity.
- Motchi's automatic journal context, lists and searches hide sealed bodies and tags. Reading a sealed body asks for confirmation first. The seal remains a reveal control, not a separate account permission.
- Anime and Currently Watching derive from the existing combined cinema stream rather than duplicate its subscriptions.

## Optional recovery of old trip places

Old Motchi places remain in `travel_pins`. The recovery tool copies them into the trip's `places` list. It preserves existing places, coordinates and categories, retains the source documents, and can be run repeatedly without duplicating recovered places.

Use approved local Application Default Credentials. Do not paste credentials into a command or PR. From the repository root:

```sh
# Read-only preview. Reports counts, not private titles or notes.
node tool/migrate_trip_pins.mjs --project=everglow-1c6db

# Only after reviewing the preview and approving the live write:
node tool/migrate_trip_pins.mjs --project=everglow-1c6db --apply
```

Neither command was run against live data during this task. Old trip notes and budgets need no recovery command because the reader handles their old fields directly.

## Verification

Local environment: Windows, Flutter 3.47.7, Dart 3.13.5, Node 24.21.0. Deployment and CI use Node 22.

- `flutter analyze`: passed with no issues.
- `flutter test --exclude-tags="golden,network"`: 1,720 passed after merging the latest `main`.
- All 15 `dart tool/ci/check_*.dart` guards: passed after listing `tool/ci/`.
- `cd functions && npm run lint -- --max-warnings=25`: passed, 0 errors and 11 warnings.
- `cd functions && node --test`: 362 passed, 5 emulator-dependent tests skipped, 0 failed.
- `cd functions && node eval_gate.js`: passed.
- `node --test tool/migrate_trip_pins.test.mjs`: passed. Covers dry run, preservation of existing places, missing trips and repeated application.
- `dart tool/build_web.dart -- --release --no-source-maps`: passed. Existing WebAssembly dry-run warnings remain; the JavaScript release build succeeded.

Regression tests execute the actual services and handlers with synthetic data. They cover late calendar subscriptions, concurrent book saves, shared book IDs, concurrent trip places, legacy trip fields, Philippine month and day boundaries, sealed journal disclosure, signed URL tampering and expiry, nested playlist URLs, and byte-range responses.

## Remaining verification

- The Chrome-only Flutter suite did not reach its first test locally. Chrome and the test host started, but the browser module loader did not finish. A separate standalone-browser retry also stayed at loading and was stopped after 120 seconds. Neither run is a pass.
- The security emulator command was attempted against `demo-everglow` only. Firebase Tools 15.29.0 refused the installed Java 8 runtime and requires Java 21. CI has Java 21 and must pass the emulator tests before merge.
- A local JavaScript release opened the fake-data Calendar route. Its accessibility tree contained Shared Calendar, Coming up and the three synthetic dates. This proves initial demo rendering only, not live synchronization. Browser screenshot capture was unreliable, so no screenshot proof is claimed.
- Native iPhone/Safari playback and real two-device watching remain unverified. Test those before treating the stream fix as proven playback.
- No live-account, passcode, private-photo or production migration checks were performed.
