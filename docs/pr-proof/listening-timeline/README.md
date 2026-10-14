# Listening timeline request reduction

Nonvisual change: the timeline layout, filters and loading states are unchanged.
Screenshot: N/A - this changes request scheduling and page size only.

## Reproduction and results

Environment: Windows, Flutter 3.44.4 / Dart 3.12.2, local Flutter test runner,
mocked HTTP responses; no live couple data, credentials or external Last.fm
requests.

Before the service change, both new regression tests failed:

- A synthetic song with 364 dated plays required 8 requests at the default
  50-row page size. The test expected 2.
- The recent-plays request did not start while the song-history request was
  held pending by a completer.

After the change, the same tests pass:

- The same 364 plays are returned newest first in 2 requests at 200 rows per page.
- Recent plays start before the pending song-history response is released.
- Existing aggregation tests still verify artist filtering, duplicate removal
  and newest-first ordering; existing pagination tests verify older pages remain.

Command: `flutter test --no-pub test/features/jukebox/music_sync_service_test.dart
 test/features/jukebox/artist_showdown_provider_test.dart
 test/features/jukebox/artist_showdown_history_test.dart` - 64 passed.

These results establish request reduction and overlap, not elapsed load time
on a real phone or authenticated Last.fm service. Artists with short histories
may only benefit from overlapping recent plays; many distinct songs still need
multiple five-song batches. The existing 50-song and 2,000-play-per-song limits
remain. Phone/Safari timing and live rate-limit behavior remain unverified.

Full validation: `flutter analyze --no-pub` - no issues;
`flutter test --no-pub --exclude-tags="golden,network"` - 1,614 passed.
All 15 discovered `dart tool/ci/check_*.dart` guards passed.
Browser: N/A - no rendered UI changes; real-device timing remains open.
