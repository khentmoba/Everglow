# Automatic lighter phone effects

The before image uses the original `d82ba068` release agent build. The after
image uses this branch's release agent build. Both show the real dashboard
with isolated agent fixtures, at 414 x 896 CSS pixels and DPR 2. Screenshots
are reduced to 414 x 896 for review. No live couple data was accessed.

Phone decoration stays visible but still: dashboard auroras, petals, title
shimmer, emblem breath/halo, and divider heart. Shared and anime loading
placeholders use their existing still appearance. The policy uses the viewport
shortest side below 600 logical pixels, so landscape phones remain light and
tablets retain their motion. It does not identify a phone model.

The hidden-page and background shimmer tests both failed before the fix.
Afterwards they pass. The phone widget check also confirms that the dashboard
decoration and loading placeholders request no continuing animation frames;
tablet motion resumes after resizing. This proves the scheduling behavior,
not whole-app battery use or device smoothness.

Windows desktop Chrome was launched with the existing `tool/perf/_harness.mjs`
in a disposable profile. Each capture opened
`/dashboard?agent=clair&perf=1`, enabled semantics, collapsed the Agent HUD,
waited for the dashboard, allowed four seconds to settle, reset the frame meter,
and sampled ten seconds of idle activity. No CPU or network throttle was used.
The raw snapshots are in `before.json` and `after.json`. These are one-run
diagnostics, without enough repetitions to claim a percentage speed gain.
The whole dashboard still animates other elements; its total frame count did
not decrease. Headless timing cadence is not the phone's presentation rate.

The after capture also sent a vertical scroll gesture. The title's semantic
position moved from 319 to 181.5 CSS pixels, confirming actual content movement.
The existing agent smoke check rendered Cinema and Anime at 430px and 810px.
The T3 preview reported that no connected automation host was available, so
browser evidence came from the repository's disposable Chrome harness.

Validation: Flutter 3.44.4 / Dart 3.12.2, Node 24.21.0, Windows.

- `flutter analyze --no-pub`: no issues.
- `flutter test --exclude-tags="golden,network" --no-pub`: 1,499 passed.
- All 15 discovered `tool/ci/check_*.dart` guards: passed.
- `flutter build web --release --no-pub --dart-define=AGENT_MODE=true`: passed.
- `node tool/agent_smoke.mjs build/web cinema`: 2 viewports passed.
- `node tool/agent_smoke.mjs build/web anime`: 2 viewports passed.

Clair's iPhone 11, Safari/PWA behavior, battery use, heat, and sustained movie
playback remain unmeasured. The original phone acceptance target in
`docs/PERF_NOTES.md` remains open.
