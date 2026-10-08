# Shared installed-app status bar

Khent confirmed #498 removed the bottom strip. Its opaque status bar now leaves
a solid band above the dashboard. The supplied physical-device screenshot uses
real couple data and is deliberately not published here.

Installed apps now use `black-translucent` and `viewport-fit=cover` so every
route can paint behind the status bar. Ordinary browser tabs keep `contain`.
The fixed document/host bounds from #498 remain; no vh/dvh minimum heights,
device height guesses, or per-screen padding were added. Existing
WebStandaloneInsets at AppRoot protect controls while backgrounds fill the view.

Apple documents the translucent status-bar behavior in
[Supported Meta Tags](https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariHTMLRef/Articles/MetaTags.html).
WebKit describes cover and safe-area padding in
[Designing Websites for iPhone X](https://webkit.org/blog/7929/designing-websites-for-iphone-x/).
Restoring cover can expose the Safari fullscreen regression discussed in
[WebKit #301994](https://bugs.webkit.org/show_bug.cgi?id=301994).
Keeping #498's fixed bounds is not proof the bottom strip cannot return.

Screenshots show the actual release app with synthetic Agent Mode fixtures in
T3 Chromium. Temporary untracked build entries set navigator.standalone=true
before startup and restore the normal agent URL. No safe-area or keyboard
measurements were overridden. HUDs were collapsed using the rendered control.
Dashboard: 430 x 932 and 820 x 1180 CSS pixels. Cinema: 430 x 932, also resized
to 932 x 430. At each size the host, Flutter view, and document height match
the viewport. No playback, watchlist change, or private-data action was tested.
Chromium does not draw the iOS status bar; these images prove route rendering,
not physical status-bar transparency or real keyboard behavior.

Verification on Windows, Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0:

- `flutter analyze --no-pub`: zero issues after `flutter pub get`.
- `flutter test --exclude-tags="golden,network" --no-pub`: 1,530 passed,
  with TEMP/TMP set to ignored build/verification-temp.
- All 15 listed `dart tool/ci/check_*.dart` guards passed.
- `node --test tool/web_bootstrap_test.mjs`: 7 passed. Against #498 HTML:
  3 passed, 4 failed (status-bar metadata and three installed display modes).
- `node tool/service_worker_test.mjs --browser`: 14 passed, zero skipped.
- `flutter build web --release --dart-define=AGENT_MODE=true --no-pub`: passed.
- Extra `flutter test --platform chrome test/core/system/web_standalone_browser_test.dart --no-pub`:
  stalled at loading with no executed tests. Retried with isolated TEMP/TMP;
  Chrome launched but loading again stalled. Both runs were stopped and are
  not counted as passing. The underlying runner stall remains unresolved.

The initial no-pub analysis/test attempts had no package configuration in this
fresh checkout; dependencies were restored before the passing runs above.
The release preview logged the already-reported didChangeViewFocus RenderBox
error, missing local environment-file 404, and denied fake Agent Mode XP/presence
requests. No clean-console claim; no real environment file was read or copied.

Keep this PR draft pending CI and a physical iPhone Home Screen check: top
artwork, bottom edge, rotation, keyboard opening/dismissal, and adoption by an
existing installed icon. Do not mark the iPhone issue fixed from Chromium alone.
