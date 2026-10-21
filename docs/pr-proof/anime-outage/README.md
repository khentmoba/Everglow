# Anime during catalog outages

The schedule used to fail as soon as AniList returned an error. Its existing
browse fallback could eventually reach TMDB, but queued Jikan requests kept
waiting on the same outage. TMDB results also entered paths that interpreted
their numeric IDs as MyAnimeList IDs.

The schedule now tries the existing authenticated TMDB helper when AniList
fails. Discovery uses Japanese animation and episode air-date filters for the
selected date, with Japan as the broadcast timezone. This response identifies
shows rather than individual episodes, so the backup view explicitly omits
episode numbers and times. It never labels a date-only row as already aired.
The catalog can be incomplete. My List does not guess cross-provider matches;
when those matches are unavailable, it directs the user to All anime.

Jikan's queued reads skip a known server/network outage for 30 seconds, then
try again. Successful home rows continue to use the existing last-known-good
home cache. TMDB fallback titles use TMDB details and season counts, retain
their source in playlists, and use separate resume/history identities. They
are not passed to MAL lookups by numeric coincidence.

## Browser proof

- `schedule-430.png`: release app at 430 × 932, synthetic TMDB fixtures.
- `schedule-810.png`: same schedule at 810 × 1080.
- Clicked Schedule, selected All anime, observed date-only rows after the
  AniList request failed, collapsed the agent HUD, then opened The Midnight
  Library and observed its episode controls.
- The fictional titles and counts come from Agent Mode. This proves the app's
  outage behavior and layout, not signed-in production catalog coverage or
  playback from an external video provider.
- T3 preview snapshots repeatedly timed out. The final checks used the
  repository's `tool/perf/_harness.mjs` in disposable Chrome against the local
  release build. No browser-tooling code changed.

## Validation

Windows PowerShell, Flutter 3.47.7, Dart 3.13.5, Node 24.21.0.

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --exclude-tags="golden,network"`: 1,765 passed on the final code.
- Focused schedule, TMDB details and Jikan cooldown tests: 18 passed.
- The complete Anime suite passes all 218 tests after fixing the footer's wordmark/tagline
  overflow at 320px with 1.3× text. The footer now wraps that group.
- All 15 discovered `tool/ci/check_*.dart` guards passed.
- `flutter build web --release --no-pub --no-wasm-dry-run --dart-define=AGENT_MODE=true`: passed.
- Impeccable detector for the schedule widget returned no findings.
- The outage integration regression failed before fallback wiring and passed
  afterward. Other coverage checks bounded paging, source identity, correct
  season slots, retry after cooldown, and no fabricated broadcast precision.

No backend, security rules, client secrets, or desktop-shell code changed.

Exact broadcast times, cross-provider My List matches, and full catalog coverage
remain limited in the TMDB backup. Native Desktop and signed-in production
catalog/playback still need checking after deployment.

## Reference investigation

A GPT-6 Luna agent inspected the public
[Anikura watch page](https://www.anikura.club/watch/6404/shangri-la-frontier-doudw?ep=2&lang=sub).
The page rendered episode metadata and its video reached ready state 4. Browser
requests used first-party `/api/watch/streams`, `/api/episode-still/`, and
`/api/media/image` routes; observed artwork sources included TMDB and TheTVDB.
No direct browser AniList or Jikan calls appeared in the isolated session.
The underlying server-side catalog supplier and caching policy were not
established. Absence of browser calls does not prove those APIs are absent
from its backend. Everglow adds no dependency on Anikura's undocumented APIs.

TMDB's [official discovery documentation](https://developer.themoviedb.org/reference/discover-tv)
supports the air-date, language, animation-genre, and timezone filters used
here. Exact episode numbers and timestamps are not part of that response.
