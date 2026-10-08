# Contained PWA viewport

The reported iPhone bottom strip persisted after PR #497. Its physical-device
reproduction remains the user's screenshot; it is not published because it
contains their real watch history. No physical Safari check was available here.

This follow-up uses `viewport-fit=contain` and an opaque `black` status bar.
The page fills the browser's usable viewport instead of requesting artwork
behind the status bar. There is no iOS version detection or device height table.
The viewport observer keeps this policy after Flutter replaces its meta tag.
Competing vh/dvh/fill-available minimum heights have been removed.

Apple documents that `black` places web content below the status bar:
[Supported meta tags](https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariHTMLRef/Articles/MetaTags.html).
This is a fallback for the fullscreen configuration discussed in
[WebKit #301994](https://bugs.webkit.org/show_bug.cgi?id=301994), not proof that
Everglow can paint a system-owned area or that every iOS release is fixed.

The screenshots show the actual release build in T3's Chromium browser,
using privacy-safe Agent Mode fixtures. A temporary, untracked HTML entry sets
`navigator.standalone=true` and restores the normal root URL before startup.
No CSS safe-area or keyboard readings were overridden. Chromium does not draw
the iPhone status bar or emulate Safari's installed-app viewport behavior.

- Dashboard and Cinema: 430 x 873 CSS pixels, including a shortened phone viewport.
- Cinema drawer after clicking More Info: resize to 873 x 430; render host and
  Flutter view both fill those bounds. No playback or watchlist action was used.
- Dashboard tablet: 820 x 1180 CSS pixels.
- At all three sizes, the render host, Flutter view and document height match
  the viewport exactly. HUDs were collapsed for the saved screenshots.

Verification: `flutter analyze --no-pub` (zero issues),
`flutter test --exclude-tags="golden,network" --no-pub` (1,530 passed),
every listed `tool/ci/check_*.dart` (15 passed),
`node --test tool/web_bootstrap_test.mjs` (4 passed),
`node tool/service_worker_test.mjs --browser` (14 passed, zero skipped),
and `flutter build web --release --dart-define=AGENT_MODE=true --no-pub` (passed).
The two new Node checks fail on #497's HTML and pass on this HTML.

The first Flutter test run lost temporary compiler/listener files after 1,526
passes, then hung in cleanup. It is not counted as passing. The complete rerun
used TEMP/TMP inside ignored `build/verification-temp` and passed all 1,530 tests.
Environment: Windows, Flutter 3.44.4, Dart 3.12.2, Node 24.21.0, Chromium preview.

The browser logged the already-reported early didChangeViewFocus RenderBox
error and denied fake Agent Mode presence/XP requests. Missing local env.txt
also logged a 404; no real environment file was read or copied. Screens and
the demo Cinema drawer rendered. A clean console is not claimed.

Remaining: actual iPhone Home Screen launch, adoption by an existing installed
icon, rotation, and real keyboard opening/dismissal. Keep the PR draft until
those checks and CI pass. This changes Safari-tab viewport fitting as well;
native layouts and data are untouched. The opaque system bar is deliberate.
