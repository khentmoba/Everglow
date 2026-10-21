# Dashboard loading recovery

## Evidence

`chart-during-catalog.png` is a 430px Flutter widget render of the real
ArtistShowdownCard with synthetic music data. Catalog discovery is deliberately
held pending. The card already shows Demo Artist, Evening Light, and 12 / 8
plays. The existing loading indicator remains visible above the counts.
This proves the intermediate rendering, not live Last.fm availability.

Three regression tests failed before their respective fixes and passed after:

- Chart rows are visible while catalog discovery is pending.
- A temporary HTTP 503 followed by a successful response preserves playcounts.
- Returning to a cached artist ignores a different artist's late response.

The final counts still union chart and per-song results. HTTP retries stop after
one retry for 502/503/504; authentication and rate-limit responses are not retried.

## Incident diagnosis, 2026-10-21 UTC

- AniList returned HTTP 403 with `data: null` and the message that its API was
  temporarily disabled due to severe stability issues. A browser request also
  failed. The current schedule has no usable response during this outage.
- The deployed Jikan catalog proxy returned HTTP 502, `Upstream fetch failed:
  fetch failed`. Neither service's recovery is proven by the application tests.
- Last.fm function execution logs recorded both 200 and 503 responses during
  the earlier diagnostic requests. The client previously dropped these temporary
  failures immediately, and blocked the entire card on catalog/per-song reads.
- The interrupted investigation repaired the missing
  `roles/firebaserules.firestoreServiceAgent` binding for the project's Firebase
  Storage service agent. Its authorized photo probes changed from 403 to 200;
  the unauthorized probe remained 403. This continuation verified that the live
  Storage rules exactly match `storage.rules` and that the binding remains.
  It did not read or capture private photos. The diagnostic service-account key
  created during the earlier investigation was revoked and its local copies removed.

## Local validation

Windows PowerShell, Flutter 3.47.7, Dart 3.13.5. No real couple data appears
in the committed proof.

- `flutter analyze`: passed; no issues.
- `flutter test --exclude-tags="golden,network"`: passed, 1,759 tests.
- All 15 discovered `tool/ci/check_*.dart` guards: passed.
- Final focused run of `artist_showdown_provider_test.dart` and
  `music_sync_service_test.dart`: passed, 66 tests.
- Browser verification remains incomplete. T3 preview snapshots timed out.
  `flutter run -d chrome` failed its debug websocket connection. A disposable
  Chrome check of the web-server target displayed a blank background without
  the dashboard text. The widget render above is the only visual evidence;
  the draft PR needs a successful app preview check before review.

Anime catalog and schedule availability still require the external services to
recover. The desktop shell was not changed: these failures were reproduced in
the shared web/backend paths. A native Desktop end-to-end check remains unverified.
