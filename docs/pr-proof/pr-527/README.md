# Audit security fixes — verification

## Scope and privacy

- Removed the 23 personal milestone photos from Git tracking and the Flutter asset bundle; the originals remain ignored on the local machine.
- Removed the unused seed script and the automatic login-page seed records. Existing Firestore memories are unchanged. A local backup of the old login source was saved outside the repository before removal.
- Existing milestone asset references resolve to authenticated Storage reads at `milestones/legacy/`. Both timeline and creator previews use the same renderer. Demo artwork stays synthetic.
- With Khent's explicit approval, changed the GitHub repository to PRIVATE and uploaded 23 private Storage objects after a dry run. All 23 MD5 checksums matched the originals; no objects have Firebase download tokens. An unauthenticated media read returned HTTP 403.
- Nothing deleted from live Storage or Firestore. No live app/functions/rules deployment performed by this task.

## Behavioral changes

1. Removed the unused remote-WASM video handler, embed handler, invite trigger, vault rule, and nine unused collection rules.
2. Anonymous tokens are rejected by `requireAuth`; study generation requires a recognized app profile. Cinema identity must match the email in a signed password-login token against the configured server email, not just a client-writable profile name. Missing server email configuration fails closed. The existing `BREYAN_EMAIL` and `OCTAGRAM_EMAIL` repository secrets (names confirmed, values not read) now flow to Functions too. Approved cinema profiles retain their existing 50/day allowance.
3. Watch streams validate and pin public DNS on each redirect hop. Image bodies stream with backpressure and disconnect cancellation.
4. Login failures share an atomic 100-per-24-hour budget across IPs, in addition to per-IP protection. Active lockouts and counter failures reject *all* attempts, including a correct guess. Existing codes remain unchanged at Khent's request. An attacker can deliberately exhaust the shared budget and temporarily block new logins; this is a known tradeoff of retaining short PINs.
5. Canonical production domains cannot activate or restore Agent Mode. Logout clears its saved state. Local development and PR previews still support demo fixtures.
6. Subscription renewals use Philippine calendar days, including month-end recurrence.

## Browser evidence

- `dashboard-phone.png`: actual release app at 430×932, synthetic Living Archive photo and story, minimized agent HUD.
- `dashboard-tablet.png`: actual release app at 820×1180, synthetic Living Archive alongside Starlight. HUD remains visible below the changed region.
- `production-guard.png`: a **local** HTTPS simulation of the canonical production hostname, not the live site. A disposable Chrome profile was preloaded with saved demo mode, then opened with `?agent=dashboard`. The app stayed at `/`, cleared the saved preference, and showed the login door without the agent HUD.
- Firestore, Storage and notification network requests were blocked during screenshot capture. No real couple data was used.
- The production-host assertions passed, but Chrome cleanup exceeded the harness timeout afterward. A follow-up process inspection found no remaining matching Chrome process; the temporary TLS files were removed. This is not a clean pass for the entire browser script.
- Built-in T3 preview snapshots timed out and agent-browser was unavailable; capture used the existing dependency-free Chrome/CDP harness with disposable profiles instead.

## Before/after evidence

- Before: a bundled private photo returned HTTP 200 without login (confirmed during the audit). After migration: the new private Storage copy returns HTTP 403 without login. **The old live Hosting copy remains until this PR is deployed**; copies already downloaded or cached cannot be recalled.
- Fresh-checkout simulation initially caught 23 obsolete login seed asset references when the ignored originals were temporarily moved aside. After removing the private seed records, the asset/privacy guards passed with no local photos present. Originals were restored immediately.
- The scanlation handler test fails if it calls `arrayBuffer`; it now sends the synthetic response through the streaming body helper.

## Remaining operational limits

- Merge through the normal PR workflow to remove the old public Hosting files and deploy the function/rule fixes. Verify old public photo paths no longer return an image afterward; the SPA fallback may return HTTP 200 HTML rather than 404.
- Check old Hosting preview channels/releases and public caches as part of incident cleanup. Making GitHub private does not recall clones or previously downloaded files.
- Current four-digit codes and client-verified cinema credentials are unchanged by explicit user choice for the couple codes. Server-side caps reduce abuse, but this is not a replacement for stronger authentication.
- Repository privacy can affect anonymous raw-image URLs, badges and integrations. PR proof files are committed for authenticated review.

## Final local checks

Environment: Windows; Flutter 3.44.4 stable; Node 24.21.0 (CI uses Node 22); Java 21 from Android Studio for the Firebase demo emulators.

- `flutter analyze`: no issues.
- `flutter test --exclude-tags="golden,network"`: 1,706 passed. The outer tool's five-minute budget elapsed while this run was still active; the retained Flutter process then completed, and its final log was checked for `All tests passed!`.
- All 15 discovered `dart tool/ci/check_*.dart` guards passed.
- `cd functions && npm run lint -- --max-warnings=25`: zero errors, 10 warnings (within budget).
- `cd functions && npm test`: 348 passed, five emulator-only tests skipped. Those five were run separately and all passed.
- `cd functions && node eval_gate.js`: passed (140 evaluation cases).
- `firebase emulators:exec --only firestore,storage --config firebase.emulators.json --project demo-everglow "node --test functions/security_rules.emulator.test.js functions/push_rules.emulator.test.js"`: five passed, zero skipped; Java 21 selected explicitly.
- `node --test tool/migrate_private_milestone_photos.test.mjs`: two passed.
- `flutter build web --release --no-source-maps`: passed; no milestone image files in the output. Existing optional WASM dry-run warnings remain; this was the normal JavaScript build.
- `node tool/agent_smoke.mjs build/web dashboard`: rendered at 430px and 810px with disposable Chrome profiles.
- `git diff --check`: passed.

No speed claim is made. Performance/offline tooling code and Quality browser wiring were not changed, so their opt-in manual tooling suites were not required. Remote CI and preview results belong to the PR, not these local results.

The migration script uses existing Application Default Credentials, defaults to a dry run, skips existing objects and uses a generation-zero precondition to prevent overwrites. Its fake-bucket tests do not need credentials.
