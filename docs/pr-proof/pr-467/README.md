# PR-467 Proof — Watched episodes show their story inline

## Change

When Hide spoilers is on, episodes Khent and Clair already finished used to
hide behind a "What happened" link (desktop sidebar) or show the story plus
a redundant link row (mobile rail). Now a finished episode shows its title
and story straight away — no extra tap. The episode being watched and
upcoming ones stay guarded behind "Reveal details" as before.

Boundary is unchanged: episodes with a number below the selected episode
are treated as watched (selected-episode boundary, no new tracking).

## Proof (fake demo data only)

- `shot-watched-inline-desktop.png`: sidebar playing episode 3 — episodes 1
  and 2 show their titles and full stories inline; episode 3 shows
  Watching + Reveal details; episode 4 shows Reveal details.
- `shot-watched-inline-mobile.png`: watched mobile card shows title and
  story inline with no "What happened" step.

Tapping an inline story still opens the full episode sheet for long
synopses (covered by the new widget test).

## Verification

- `flutter test test/features/anime/animex_spoilers_test.dart` — 17/17 pass,
  including the new "watched episodes show the story inline" test on both
  layouts.
- `flutter test test/features/anime/animex_watch_page_test.dart
  test/features/cinema/cinema_preferences_spoilers_test.dart` — all pass.
- `flutter analyze` — no issues.
- `dart tool/ci/check_*.dart` — all regression guards pass.
- Release-mode screenshots above rendered from a clean `origin/main` +
  this change only (temp preview entry removed afterwards).
