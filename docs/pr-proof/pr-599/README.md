# PR 599 proof: faster media sections and section opens

Local release builds, headless Chrome, isolated agent demo session (no login,
no couple data). Before = `origin/main` `acb7927c` plus only the route timing
mark; after = this branch.

- `before-after-screens.png`: top row before, bottom row after. Anime phone
  (430px), Cinema phone (430px), Anime tablet (820px). The screens are meant
  to look identical; the change is in how often they rebuild and load.
- `raw/nav_*.json`: `node tool/perf/probe_navigation.mjs` runs (4 before,
  6 after).
- `raw/scroll_*.json`: `node tool/perf/probe_scroll.mjs --screen <name>` runs,
  2 per build per screen, plus a 3-run Mangacelestia recheck. CPU profile
  rankings are stripped to keep the files small.

Tables and limits: `docs/perf-baseline-sitewide.md`.
