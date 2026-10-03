# PR-431 proof — fix(deps): bump @fastify/busboy past GHSA DoS advisories

`npm audit --omit=dev --audit-level=moderate` (exact CI command) failed
on main with 1 HIGH: `@fastify/busboy@3.2.0` DoS via oversized multipart
boundary (GHSA-xjh9-v7x6-24jw) + prototype-named part header
(GHSA-x8mw-p69m-v3mx). Fix: `npm update @fastify/busboy` → 3.2.2 within
firebase-admin's existing `^3.0.0` range. Lockfile-only, 3 lines.

Verification (all green):
- Clean `npm ci` + exact audit command → exit 0, "found 0 vulnerabilities"
- `node --test anime.test.js rules_static.test.js` — 36/36 pass
- No `package.json` change, no overrides added.

Visual proof: N/A (dependency metadata only; nothing renders).
