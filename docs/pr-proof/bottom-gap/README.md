# Restore the contained iPhone viewport

Khent confirmed PR #498 removed the bottom strip on his phone. PR #499
restored translucent fullscreen coverage and the supplied screenshot shows
the bottom strip returning. The physical screenshot contains private couple
data and is not copied into this public repository.

This restores #498's launch configuration: an opaque `black` status bar and
`viewport-fit=contain`, retained after Flutter rewrites its viewport metadata.
Khent chose removing the bottom strip over artwork behind the status bar.
The policy applies to every iOS version, with no user-agent checks or device
height guesses. It is a compatibility fallback, not proof for every iOS release.

[WebKit #301994](https://bugs.webkit.org/show_bug.cgi?id=301994) remains open
and includes a report of a bottom area drawn outside the DOM in standalone
apps. Keeping translucent fullscreen coverage cannot reliably fill that area.
Apple documents the opaque status bar placing content below it in
[Supported Meta Tags](https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariHTMLRef/Articles/MetaTags.html).

## Local evidence

The updated Node regression tests ran against the old HTML first: 3 passed,
4 failed. With the fix, all 7 pass. They exercise launch metadata and repair
of engine-replaced, duplicate, and missing viewport tags in browser, iOS,
standalone, and fullscreen modes without repeated resize loops.

The screenshots show the actual release app with synthetic Agent Mode data
in T3 Chromium. Temporary, untracked build pages set `navigator.standalone`
before startup to exercise Flutter's installed-app host; they do not override
safe-area or keyboard readings. Agent HUDs are collapsed.

- Dashboard phone: 430 x 873 CSS pixels.
- Dashboard tablet: 820 x 1180 CSS pixels.
- Cinema phone: 430 x 873 CSS pixels; also resized to 873 x 430.
- Measured Dashboard phone/tablet and Cinema landscape host, Flutter view,
  and document bounds equal the viewport, starting at zero with no excess height.

These images prove rendering in Chromium, which does not draw iOS system bars.
The existing installed icon's metadata adoption, a physical iPhone Home Screen
launch, real rotation, and keyboard opening/dismissal remain unverified here.
Keep the PR draft until CI and the device check pass.

## Verification

Windows; Flutter 3.44.4, Dart 3.12.2, Node 24.21.0.

- `flutter analyze --no-pub`: zero issues.
- `flutter test --exclude-tags="golden,network" --no-pub --reporter=expanded`:
  1,530 passed, using TEMP/TMP inside ignored `build/verification-temp`.
- Every listed `dart tool/ci/check_*.dart`: all 15 passed.
- `node --test tool/web_bootstrap_test.mjs`: 7 passed.
- `node tool/service_worker_test.mjs --browser`: 14 passed, zero skipped;
  real disposable Chrome verified paired loaders and deferred code offline.
- `flutter build web --release --dart-define=AGENT_MODE=true --no-pub`: passed.
  Existing WebAssembly compatibility warnings do not prevent the JS build.

The preview logged the existing early `didChangeViewFocus` RenderBox error,
missing local environment-file 404, and denied fake Agent Mode XP/presence
requests. No real environment file was read or copied. A clean console is
not claimed. Playback, real accounts, and private-data actions were not tested.
