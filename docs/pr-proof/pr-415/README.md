# Megaplay episode-boundary proof

## Reproduction

- AniList's live GraphQL response for `108465` reports `episodes: 11`, but `streamingEpisodes` includes Season 2 titles through episode 24, including `Episode 12 - I Want to Tell You`.
- With `Referer: https://everglow-1c6db.web.app/`, MegaPlay `/stream/ani/108465/11/sub` returns `File 31638 - MegaPlay`; `/12/sub` returns HTTP 200 with `Error - MegaPlay` and error code 404.
- ani.zip confirms the first entry has 11 episodes. Its sequel `127720` has 12 local episodes mapped to TMDB season 1, episodes 12–23.
- Regression test against the old count calculation fails: expected 11 episodes, got 24. The same test passes with the correction.

## Browser checks

Ran `flutter run -d chrome` headless, then inspected the production episode widgets in a temporary logged-out preview with synthetic polluted feed data and public season metadata. The preview route was removed before committing.

- Phone (430px): Season 1 ends at episode 11, Children and Warriors; no nonexistent episode 12 appears under this entry.
- Tablet (900px): opened the season picker, selected Season 1 Part 2, searched for 12, and selected Wake Up and Take a Step. The generated MegaPlay URL uses `/ani/127720/12/sub`, not the first cour's ID.
- Independently opened that corrected MegaPlay URL with Everglow's referrer. The video was playing: `paused: false`, `readyState: 4`, `currentTime: 13.09895`, `duration: 1427.063`. This was a provider-page playback check, not a signed-in end-to-end Everglow test.

Screenshots show the real shared episode widgets, not a live signed-in couple account. No private data is included.

## Checks

- `flutter analyze`: no issues.
- `flutter test --exclude-tags='golden,network'`: 1,095 passing tests.
- Focused watch-page suite: 35 passing tests.
- All 12 `tool/ci/check_*.dart` guards passed.
- Release web build passed.
- Functions lint, syntax checks, evaluation gate, and 248 tests passed.
