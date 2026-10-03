# PR-430 proof — docs(agents): free-first web search

Docs-only change (`AGENTS.md`, web search policy section): default to
free tools (`google_search`, `agent_browser`, `curl`), use TinyFish CLI
only when free tools fail, ask Khent before wallet-burning agent runs.

- No app, functions, rules, or test code touched — nothing to screenshot.
- Visual proof: N/A. `flutter analyze` / `flutter test` unaffected by
  construction (single Markdown file).
