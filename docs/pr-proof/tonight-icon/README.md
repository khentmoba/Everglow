# Tonight icon font refresh

Synthetic, logged-out fixture using the production TonightCard and QuickActionTile. No couple data or credentials.

- `shot-before-phone.png`: intercepted the MaterialIcons font with a subset missing the two new Tonight glyphs; both icon containers rendered blank, matching the report.
- `shot-phone.png` / `shot-tablet.png`: repeated the same preview with the current font; both icons render. Chrome reported no JavaScript exceptions.
- The visual check proves the missing-font symptom, not a live account update. `functions/web_icon_cache.test.js` separately reproduces stale service-worker bytes, checks refresh/HTTP revalidation, offline reuse, and migration without evicting CanvasKit/core.

Checks: flutter analyze, 1,292 Flutter tests, release web build, targeted Node tests (4), functions lint, and hosting guard passed.

Local blockers: the asset and no-new-goldens guards compare forward-slash allowlists with Windows backslash paths; the full backend suite needs Firestore credentials/emulators. These checks are not claimed green. No deployment or live-account verification was performed.
