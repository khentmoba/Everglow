# Coding Standards (Review Guide)

Judgement-call rules enforced during code review. Mechanical rules live in `tool/ci/run_checks.mjs` and ESLint instead.

## Auth and concurrency

- **Check owner/generation across `await`.** Any async read, retry, timer, or delete that touches user state (AI chats, watchlists, downloads, couple notes) must capture the current UID or session generation before `await` and discard stale work if `everglow:logout` or an account switch happened while waiting.
- **Guard abortable body reads.** Passing `AbortSignal.timeout(...)` to `fetch()` aborts body streaming too. Keep `res.text()` / `res.json()` inside the same `try`/`catch` or `.catch()` as the `fetch()` so a slow body degrades gracefully instead of throwing unhandled `TimeoutError`.

## Reliability and mobile performance

- **Pause background work when hidden.** Continuous `requestAnimationFrame` loops, countdowns, auto-read timers, and polling intervals must pause or return early while `document.hidden` is true, and clean up handles on unmount.
- **No per-frame React state.** 60fps animations (floating companion, heart pulse, progress scrubbers) write transforms directly to DOM refs rather than calling `setState` every frame.
- **Bound session-lived caches.** Module-level caches must have a size ceiling (`setBoundedCache` in `react/src/core/utils/boundedCache.ts`); caches holding user-specific or couple-private data must also clear on sign-out (`clearOnLogout`).

## Privacy and HTTP headers

- **Cover every private endpoint.** When adding or updating auth-gated Cloud Functions, verify every private route in the file sets `Cache-Control: private, no-store` and `Vary: Origin, Authorization` (do not miss one handler in a multi-route file).
- **Never log signed URLs or tokens.** Log only the object path or safe identifier, never full query strings containing `token=`.

## Separate-world theming

- **Keep couple framing on couple pages.** Couple-space pages (everything outside the media worlds) own the romantic rose framing and couple copy. Cinema, Anime, Books, and Manga Celestia keep their own world looks (`DESIGN.md`); do not default new media surfaces to couple pink/rose.
- **Cinema copy stays neutral.** Family guests share Cinema, so keep all Cinema text free of couple or romance framing.

## Tests

- **Use per-module backend test files.** Put new Cloud Functions unit tests in `functions/<module>.test.js` instead of appending to `functions/perf_reliability_security.test.js`, so concurrent PRs do not collide on one test file.
