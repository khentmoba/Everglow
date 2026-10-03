# Cinema episode-boundary proof

## What was checked

Cinema cannot hit the anime mixed-season bug: it fetches episodes per
season from TMDB (`/tv/{id}/season/{n}`), so one season's list can never
contain another season's episodes, and player URLs use series + season +
episode numbers rather than per-season catalog IDs.

## Three issues found and fixed

1. **Resume offset leaked into the next episode (web player).**
   Resuming S1E1 at 10:00, then tapping S1E2 (or Next auto-advance),
   opened S1E2 at 10:00 instead of the start. Root cause:
   `_resolvedStartSeconds` was never cleared on episode change, and
   `_restorePlayerMemory` applied a saved position even when it belonged
   to a different episode than the one being opened.
   Verified with a temporary Chrome probe driving the real player
   callbacks: before the fix the rebuilt URLs kept `start=600`; after
   the fix the parameter is gone (probe removed after verification —
   the web player library is browser-only so the probe can't run in CI;
   the one-line assignments are covered by review).
2. **A failed season fetch jumped a whole season ahead.**
   `fetchSeasonEpisodes` reports errors as `[]`, and `NextEpisodeService`
   treated that as the finale, offering next season's premiere.
   Simulated HTTP 503 on Season 1 while on S1E2: before the fix Next
   offered S2E1; after the fix there is no Next pill until retry.
3. **Next offered episodes that haven't aired yet.**
   `nextInSeason`/`firstInSeason` ignored TMDB `air_date`. Controlled
   test with a 2099-dated episode: offered before, suppressed after.
   Missing/unparsable dates still count as aired so playable episodes
   are never hidden by a metadata gap.

## Browser check

`flutter run -d chrome` headless with a temporary logged-out preview
rendering the real `nextInSeason` outputs through the real
`NextEpisodeButton` (fake demo season). Screenshot shows: normal E9→E10
offers the pill; unaired next and failed fetch correctly show none. No
page errors. Preview route removed before commit.

## Checks

- `flutter analyze`: no issues.
- `flutter test --exclude-tags='golden,network'`: 1,100 passing.
- All 12 `tool/ci/check_*.dart` guards passed.
- Release web build passed.
