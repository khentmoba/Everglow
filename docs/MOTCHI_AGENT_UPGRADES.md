# Motchi agent upgrades

This change keeps Motchi's shared cat persona and improves seven existing paths.
It uses the current Provider services, tool loop, memory cache and push-token documents.
No new dependency, polling listener or background cleanup job is added.

1. **Memory:** automatic extraction sees only the user's words and requires an exact supporting quote. Temporary moods are rejected. Facts distinguish self reports, partner reports and explicit saves/corrections. Automatic extraction cannot overwrite an explicit correction; users can still correct it through the Memory Book receipt. This is conservative evidence checking, not a guarantee that the model understands every statement correctly. Existing memories are not migrated or relabelled.
2. **Actions:** new chat turns carry a saved action scope; Continue and Retry reuse it. A server-only `motchi_actions` document reserves a write before execution and records its result. A completed action is replayed; a pending or uncertain action is blocked rather than repeated. A crash between the real write and receipt completion therefore leaves an uncertain result that must be checked. Reads, XP awards and unconfirmed deletion previews do not get reservations. Different arguments or a new scope represent a different action, so this is duplicate protection within a task, not global exactly-once execution. Old clients without a scope retain the previous in-memory guard.
3. **Recommendations:** confirmed catalog titles mentioned in a reply get feedback controls: seen, not tonight, too long, more like this. Feedback belongs to the person tapping it. The model gets both people's bounded feedback when asked for recommendations. Not-tonight feedback expires from the prompt after 24 hours. No automatic watchlist changes are made by feedback.
4. **Continuity:** messages retain action scopes and include receipt target IDs in the existing request history. Ordinal follow-ups inherit retrieval topics. Cinema and Trip Kit can open Motchi with the selected title or trip ID already in the composer. Sending the prepared question remains explicit.
5. **Waiting and Stop:** the complete model/tool request has a 45-second greeting, 90-second ordinary, 180-second reasoning or 280-second artifact budget, with respective model-call limits of 2, 8, 10 and 14. Web fetch/XHR and native SSE transports can be cancelled. A disconnected client aborts further model work and prevents new tools from starting; an already-started write can still finish and store its receipt. Tool-side external requests can finish within their existing timeout.
6. **Attention:** Motchi Preferences offers individual daily/weekly/off nudges, recap on/off and Philippine-time quiet hours. Scheduled sends reuse the existing push-token read and reserve their frequency slot transactionally. Non-habit nudge categories also have a three-day repetition floor. Explicit reminders (including partner reminder notifications) bypass these controls. Quiet-hour sends are skipped, not queued. A failed push can consume its reserved slot; it is not blindly resent.
7. **Evaluation:** offline tests exercise extraction evidence, ownership, cache/query counts, bounded feedback, action replay across cache resets, simultaneous duplicates, uncertain writes, cancellation, feedback UI, and phone/tablet settings failures. Existing real-handler streaming and JSON journeys still run. Numeric completion/unknown-write counts join the existing session diagnostic write. `motchiStats?journeys=1` optionally summarizes the latest 25 sessions; ordinary stats requests do not read those sessions. This is a bounded sample, not a population-wide success claim.

## Added Firestore operations

These are incremental operations, in addition to existing authentication, usage,
context, conversation and logging work. Transaction contention can retry reads.

- Ordinary chat and follow-up state: no new queries.
- Recommendation feedback context: at most two document reads on a cold instance; cached for five minutes per person, including concurrent in-flight reads.
- Open preferences: one document read on a cold cache. Changing controls: zero operations. Save preferences: one write.
- Submit feedback: one transactional document read and one write; latest 20 entries retained per person.
- Reserved write action: one transactional document read plus two receipt writes, in addition to the original action. Replay: one read and no receipt writes. Reads and XP awards: no receipt operations.
- Scheduled send: the same token document read already used by FCM, plus one write only when a notification slot is accepted. Skipped sends do not write a slot.
- Automatic extraction: reuse the warm facts cache; otherwise retain the existing bounded 30-document dedupe query. No extra extraction request per ordinary turn is added; the existing 30-minute throttle remains.
- Optional journey diagnostics: up to 25 session documents when explicitly requested. No new telemetry collection or per-turn telemetry write.

Receipts expire after 30 days using the configured Firestore TTL field; result
bodies and the TTL timestamp have no single-field indexes. This avoids a cleanup
scan. TTL deletion is asynchronous and incurs document-delete costs, as described
in [Firebase's TTL documentation](https://firebase.google.com/docs/firestore/ttl).
The configuration uses the supported `fieldOverrides` format in
[Firebase's index reference](https://firebase.google.com/docs/reference/firestore/indexes).
The existing deployment workflow deploys indexes; verify TTL enablement after deployment.
Retry protection is bounded by receipt retention. It does not restore records deleted by TTL.

## Verification

Local environment: Windows, Flutter/Dart from `C:/dev/flutter`, Node 24.21.0
(production functions target Node 22), installed Chrome with a disposable profile.

- `flutter analyze`: no issues.
- `flutter test --exclude-tags="golden,network"`: 1,585 passed.
- All 15 discovered `tool/ci/check_*.dart` guards passed.
- Functions: `npm run lint -- --max-warnings=25` passed with 24 existing warnings; `npm test` passed 322 tests with one emulator-only skip; `node eval_gate.js` passed all 19 gates (69 tools, 140 routing cases). The failure corpus passed 176/176 cases.
- Real production handler paths are tested with synthetic auth/storage/model responses. No paid model calls or production writes were used.
- Phone/tablet screenshots under `docs/pr-proof/motchi-agent-upgrades/` use isolated Agent Mode preferences. Local Chrome exercised the recap switch and Save. Widget tests separately verify values saved and failure recovery at 320px and 810px.
- T3 Preview failed twice with `Preview automation snapshot timed out after 15000ms`; the documented disposable-Chrome release-preview workflow was used instead.
- Additional `flutter test --platform chrome test/features/ai/motchi_streaming_scroll_test.dart` was stopped at loading: the local Flutter test host returned 404 for `canvaskit/chromium/canvaskit.js` and `.wasm`, then raised `Exception: Web test for featuresaimotchi_streaming_scroll_test.dart not found`. This Windows test-host run did not execute tests. The existing Linux Quality workflow runs this suite; leave the PR draft until it passes there. The release-browser screenshots are separate evidence, not a replacement for that suite.

Live model answer quality, real-device battery/speed, production transaction contention,
FCM delivery and deployed TTL activation remain unmeasured. No live deployment or merge is part of this change.
