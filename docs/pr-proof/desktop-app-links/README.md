# Desktop installation and update controls

All screenshots use synthetic Agent Mode content in disposable Chrome profiles.
No credentials, couple records, private photos or signing keys were accessed.

- `entrance-before.png` / `dashboard-before.png`: baseline commit
  `55466506`, built separately, 430 x 932 CSS pixels.
- `entrance-phone.png` / `dashboard-phone.png`: real changed entrance and
  Dashboard download controls, 430 x 932 CSS pixels.
- `dashboard-phone-native-demo.png` / `dashboard-tablet-native-demo.png`:
  real changed Dashboard with a simulated 0.3.0 native bridge callback, at
  430 x 932 and 810 x 1080 CSS pixels. These prove layout and callback dispatch,
  not native installer execution. The tablet test click incremented the fake
  native update request counter exactly once.

PNG captures were downsampled to their CSS widths. The collapsed Agent HUD pill
is a development overlay. The doorway captures use `everglow.localhost` so the
localhost-only fast-jump bar does not cover the production footer position.
The 320 x 568 production doorway layout was also inspected without overflow or
overlap between the download action and passcode keys.

## Verification

Environment: Windows, Flutter 3.44.4 / Dart 3.12.2, Chrome 155, Node 22+.

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub --exclude-tags="golden,network"`: 1,599 passed.
- Every `dart tool/ci/check_*.dart`: 16 passed (listed before execution).
- `flutter build web --release --dart-define=AGENT_MODE=true --no-pub`: passed.
- `flutter run -d chrome --release --web-port=8753
  --dart-define=AGENT_MODE=true --no-pub`: built and launched.
- `PERF_REQUIRE_CHROME=1 node --test tool/perf/harness.test.mjs`: 24 passed,
  zero skipped; the environment variable was removed afterwards.
- `node tool/service_worker_test.mjs --browser`: 14 passed, zero skipped.
- Impeccable detector over the changed widget and both surfaces: no findings.

Browser interactions: clicked the download action with `window.open` captured
instead of downloading an unpublished installer; the target was the exact stable
GitHub asset URL. Clicked the native action with the fake bridge installed before
app boot; one callback fired. Inspected browser and simulated-native layouts at
phone and tablet widths. These are desktop Chrome viewport checks, not real
phone/Safari or installed upgrade tests.

The local `flutter test --platform chrome test/desktop_app_browser_test.dart`
runner was blocked before tests ran: Flutter's Windows CanvasKit handler returned
404 for its own JS/WASM files. The initial nested test path also exposed Windows
test-selector escaping; the new browser test now lives at the test root. The
CanvasKit issue persisted with the CDN dart-define. Quality's Linux browser suite
includes the new test and remains the independent CI verification.

The local build omits `assets/env.txt`, as required for agent work. Its missing
asset warning and synthetic artwork 404s are expected. An initial preview-tab
focus notification logged a transient RenderBox-not-laid-out error; subsequent
navigation rendered both changed surfaces and interactions successfully.

## Release dependency

The companion desktop PR adds the bridge and stable installer asset:
https://github.com/khentmoba/Everglow-Desktop/pull/1

Keep the website PR in draft until desktop 0.3.0 is released and its installer
and update feed work anonymously. No site deployment or release tag was made as
part of preparing these changes. A real installed signed upgrade remains release
verification, separate from the browser callback and fake-page native checks.
