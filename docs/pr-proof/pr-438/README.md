# Motchi read receipts — proof

## Problem (reported from the anime Motchi sidechat)

A Mushoku Tensei Season 3 question came back with a **correct, complete answer**,
but the receipt card under it read:

```
What happened
Some steps still need attention.
✓ Done · web search
   Mushoku Tensei Season 3 announcement release date…
✓ Done · read web page          <- no subject
(!) Did not complete · read web page   <- no subject
```

Three defects, all reproduced before fixing:

1. **The failed read hijacked the whole card.** `MotchiReplyDetails.summary`
   returned "Some steps still need attention." for *any* non-`done` step. Reads
   (`web_search`, `read_web_page`, `browse_web`) cannot leave anything half-saved,
   so nothing was left for Clair to finish — the honest summary for this reply is
   "Information found — nothing saved yet."
2. **Both read rows had no subject at all.** `toolReceipt` built its title only
   from `result.title / args.title / args.name / args.query`. `read_web_page`
   takes `urls`, which was never read, so every read receipt was blank —
   "Did not complete · read web page" with no idea which page.
3. **One blocked page could kill a whole batch.** `exec_read_web_page` sent up to
   3 URLs in a single request; any failure returned one hard error and discarded
   the pages that had loaded. A bot-protected Facebook/Reddit page took the Fandom
   page down with it.

## Fix

1. `lib/features/ai/domain/motchi_reply_details.dart` — only a step that can leave
   something half-saved demands action. Anything not explicitly `write: false`
   still counts, so older saved replies predate the flag and fail safe into the
   alarm rather than silence.
2. `functions/motchi_reply_details.js` — receipts take their subject from the URL
   hosts, so each read row names the site it was about.
3. `functions/motchi_exec_insights.js` — one request per URL, all in parallel
   (same wall-clock as the old single batch), so one blocked page no longer
   discards the rest. A slow page gets exactly one retry, and both this tool and
   `web_search`'s top page now share one per-URL cache entry.

The failed read is still shown. Trust means showing what Motchi could not open,
not hiding it — only the alarm framing changed.

## Verification

- `functions/test/motchi_exec_tools.test.js` — 3 new tests: a blocked URL keeps the
  other two pages, a timeout gets exactly one more try, and a read that did not
  complete is distinguished from a write that did. All three failed before the fix.
- `test/features/ai/motchi_reply_details_test.dart` — 2 new widget tests: the exact
  screenshot scenario (row visible, no alarm, no "Help finish unfinished steps")
  and a failed write that still demands attention.
- `flutter analyze` clean; `flutter test` 1389 passing; functions suite 140/141
  (the one failure, `buildContextForFeature`, needs GCP credentials and fails
  identically on the base commit).
- All 12 `tool/ci/check_*.dart` guards pass.
- Chrome via CDP, fake demo data only, no console errors or exceptions.
- The CI preview deploy for this PR was opened over CDP after navigating from
  `about:blank` (so a stale service-worker shell could not be what was
  inspected). It boots to the logged-out lock screen with no console errors or
  exceptions — see `shot-preview-deploy-430.png`. Reaching the receipt card
  needs a signed-in account, which was deliberately not done: this repo is
  public and only fake demo data belongs in proof.

`shot-receipts-phone-430.png` and `shot-receipts-tablet-800.png` show both cases
side by side: the read failure stays visible without the alarm, and a failed
write still shows "Some steps still need attention." plus the continue button.
