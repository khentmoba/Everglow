# Discord Watchparty Coordinator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the in-site watchparty sync + WebRTC voice with a serverless Discord coordinator: Share from Cinema posts an embed, host Go Lives manually, end from either side.

**Architecture:** Flutter calls authenticated `notifyDiscordWatch`, which posts to a Discord channel webhook and records one Firestore doc. Discord End button hits public `discordInteractions`, verified by Ed25519 signature, which edits the message to Ended. No bot token needed: webhook token edits + interaction tokens cover all writes. No always-on process.

**Tech Stack:** Cloud Functions for Firebase v1 `functions.https.onRequest` + v2 `onRequest` (Node 22), `libsodium-wrappers` for signature verify (already in functions/package.json), `node --test` for function tests, Flutter `http` following `lib/features/cinema/data/services/tmdb/tmdb_base.dart` auth pattern.

**Spec:** `docs/superpowers/specs/2026-09-03-discord-watchparty-design.md` (local-only scratch, gitignored)

## Global Constraints

- Node engine is 22 per functions/package.json; function tests run with `npm test` (`node --test`) from functions/.
- Flutter SDK ^3.11.3; run `flutter analyze` before any commit touching lib/.
- Never put Discord webhook URL, public key, user IDs, TMDB key, or passcodes in client code or --dart-define; server config only.
- Couple-only: server checks username in ['khentsgdz','clairjassen']; Discord allowlists only the two configured Discord user IDs.
- Share failure quiet-fails: snackbar + print log, cinema stays usable.
- Relative imports within lib/, no package imports for internal files.
- UI uses core/theme tokens and shared everglow widgets, never hardcoded colors.
- Firestore error paths always print log.
- Commit per task; deletion task runs last so the old path stays live until the new one is verified.

## File Structure

- Create `functions/discord.js`: pure embed builders + Discord webhook helpers + Ed25519 verify. One responsibility: Discord protocol details.
- Create `functions/test/discord.test.js`: unit tests for builders + signature verify with a generated keypair.
- Modify `functions/index.js`: add `notifyDiscordWatch`, `discordInteractions`, `sweepStaleDiscordWatch` exports only; all logic lives in `functions/discord.js`.
- Modify `firestore.rules`: add `discord_watch_sessions` match; old watchparty matches removed in the cutover task only.
- Create `lib/features/cinema/data/services/discord_share_service.dart`: POSTs Share payload with Firebase ID token, follows tmdb_base.dart header pattern.
- Modify cinema detail entry (`lib/features/cinema/presentation/screens/cinema_screen.dart` + episode drawer wiring): add Share to Discord button reusing watchparty `MediaRef` shape; exact widget anchor decided at implementation time by following the existing episode-drawer CTA pattern.
- Delete last: `lib/features/watch_party`, old rules matches, `onWatchPartyInvite` wiring, dashboard Watch Together card.

**Session doc shape** (`discord_watch_sessions/active`): `{ messageId: string, title: string, posterPath: string, mediaType: 'movie'|'tv', season: number|null, episode: number|null, startedBy: 'khentsgdz'|'clairjassen', startedAtMs: number, active: boolean, status: 'live'|'ended'|'replaced'|'expired'|'pending' }`

**Server config (functions config / env):** `DISCORD_WEBHOOK_URL`, `DISCORD_PUBLIC_KEY`, `DISCORD_VOICE_URL`, `DISCORD_KHENT_ID`, `DISCORD_CLAIR_ID`.

---

### Task 1: Discord server setup + embed builder with tests

**Files:**
- Create: `functions/discord.js`
- Test: `functions/test/discord.test.js`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `buildWatchPost(p)` used by Task 2; `buildEndedPost(p)` and `verifyDiscordSignature(p)` used by Task 3. Signatures: `buildWatchPost({title, posterPath, mediaType, season, episode, voiceUrl, hostDisplay, partnerMention})` returns `{content, embeds, components}`; `buildEndedPost({title, hostDisplay})` returns `{content, embeds, components}`; `verifyDiscordSignature({publicKeyHex, signatureHex, timestamp, body})` returns `Promise<boolean>`.

**Manual setup (do once, in Discord UI + Firebase config):**
- [ ] **Step 1: Create the private Discord surface.** Create a private server with members Khent + Clair only, a `#watch-party` text channel, and one static voice channel. Copy the voice channel URL into `DISCORD_VOICE_URL`. In channel settings create a webhook for `#watch-party`; store its URL as `DISCORD_WEBHOOK_URL` in Functions config. Create a Discord application, copy its public key to `DISCORD_PUBLIC_KEY`; its interactions endpoint URL gets filled in Task 3 after deploy. Enable Developer Mode, copy each member's user ID into `DISCORD_KHENT_ID` / `DISCORD_CLAIR_ID`.

- [ ] **Step 2: Write the failing test.** Create `functions/test/discord.test.js`:

```js
'use strict';
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { buildWatchPost, buildEndedPost } = require('../discord');

describe('buildWatchPost', () => {
  it('mentions partner, shows S/E for tv, keeps End button', () => {
    const post = buildWatchPost({
      title: 'Attack on Titan', posterPath: '/p.jpg', mediaType: 'tv',
      season: 1, episode: 5, voiceUrl: 'https://discord.com/channels/1/2',
      hostDisplay: 'Khent', partnerMention: '<@123>',
    });
    assert.ok(post.content.includes('<@123>'));
    assert.ok(post.embeds[0].title.includes('Attack on Titan'));
    assert.ok(post.embeds[0].description.includes('S1 E5'));
    assert.equal(post.components[0].components[0].custom_id, 'end_watch');
  });
  it('omits S/E for movies', () => {
    const post = buildWatchPost({
      title: 'Dune', posterPath: '', mediaType: 'movie',
      season: null, episode: null, voiceUrl: 'https://discord.com/channels/1/2',
      hostDisplay: 'Clair', partnerMention: '<@456>',
    });
    assert.ok(!post.embeds[0].description.includes('S1'));
  });
});

describe('buildEndedPost', () => {
  it('marks ended with no buttons', () => {
    const post = buildEndedPost({ title: 'Dune', hostDisplay: 'Khent' });
    assert.ok(post.embeds[0].title.includes('Ended'));
    assert.equal(post.components.length, 0);
  });
});
```

- [ ] **Step 3: Run test to verify it fails.**

Run: `cd functions && npm test -- test/discord.test.js`
Expected: FAIL with "Cannot find module '../discord.js'" (file does not exist yet).

- [ ] **Step 4: Write minimal implementation.** Create `functions/discord.js`:

```js
'use strict';

function epLabel(mediaType, season, episode) {
  if (mediaType !== 'tv' || season == null || episode == null) return null;
  return `S${season} E${episode}`;
}

function buildWatchPost({ title, posterPath, mediaType, season, episode, voiceUrl, hostDisplay, partnerMention }) {
  const ep = epLabel(mediaType, season, episode);
  const description = [
    `${hostDisplay} is hosting — join voice, then they Go Live.`,
    ep ? ep : null,
    `[Join voice](${voiceUrl})`,
  ].filter(Boolean).join('\n');
  return {
    content: `${partnerMention} movie night: ${title}`,
    embeds: [{
      title: `Now hosting: ${title}`,
      description,
      image: posterPath ? { url: posterPath } : undefined,
    }],
    components: [{
      type: 1,
      components: [
        { type: 2, style: 5, label: 'Join voice', url: voiceUrl },
        { type: 2, style: 4, label: 'End', custom_id: 'end_watch' },
      ],
    }],
  };
}

function buildEndedPost({ title, hostDisplay }) {
  return {
    content: `Movie night ended: ${title} (hosted by ${hostDisplay})`,
    embeds: [{ title: `Ended: ${title}`, description: 'Thanks for watching.' }],
    components: [],
  };
}

async function verifyDiscordSignature({ publicKeyHex, signatureHex, timestamp, body }) {
  const sodium = require('libsodium-wrappers');
  await sodium.ready;
  const msg = Buffer.concat([Buffer.from(timestamp, 'utf8'), Buffer.from(body)]);
  return sodium.crypto_sign_verify_detached(
    Buffer.from(signatureHex, 'hex'),
    msg,
    Buffer.from(publicKeyHex, 'hex'),
  );
}

module.exports = { buildWatchPost, buildEndedPost, verifyDiscordSignature };
```

- [ ] **Step 5: Run test to verify it passes.**

Run: `cd functions && npm test -- test/discord.test.js`
Expected: PASS (all suites green; other suites untouched).

- [ ] **Step 6: Commit.**

```bash
git add functions/discord.js functions/test/discord.test.js
git commit -m "feat(discord): watch embed builders with tests"
```

---

### Task 2: notifyDiscordWatch post endpoint + supersede

**Files:**
- Modify: `functions/index.js` (add export + require only)
- Create: logic lives in `functions/discord.js` (append `postToWebhook`, `patchWebhookMessage`)

**Interfaces:**
- Consumes: `buildWatchPost` from Task 1 with identical arg names.
- Produces: Firestore doc `discord_watch_sessions/active` in the shape from File Structure; `messageId` consumed by Task 3.

- [ ] **Step 1: Write the failing test.** Append to `functions/test/discord.test.js`:

```js
const { postToWebhook } = require('../discord');

describe('postToWebhook', () => {
  it('appends wait=true and returns parsed id', async () => {
    const calls = [];
    const fakeFetch = async (url, opts) => {
      calls.push(url);
      return { ok: true, status: 200, json: async () => ({ id: 'msg1' }) };
    };
    const id = await postToWebhook({
      webhookUrl: 'https://discord.com/api/webhooks/a/b',
      payload: { content: 'hi' },
      fetchImpl: fakeFetch,
    });
    assert.equal(id, 'msg1');
    assert.ok(calls[0].includes('wait=true'));
  });
});
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `cd functions && npm test -- test/discord.test.js`
Expected: FAIL with "postToWebhook is not a function".

- [ ] **Step 3: Write minimal implementation.** Append to `functions/discord.js`:

```js
async function postToWebhook({ webhookUrl, payload, fetchImpl }) {
  const useFetch = fetchImpl || fetch;
  const sep = webhookUrl.includes('?') ? '&' : '?';
  const resp = await useFetch(`${webhookUrl}${sep}wait=true`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(12000),
  });
  if (!resp.ok) throw new Error(`Discord post failed: ${resp.status}`);
  const data = await resp.json();
  return data.id;
}

async function patchWebhookMessage({ webhookUrl, messageId, payload, fetchImpl }) {
  const useFetch = fetchImpl || fetch;
  const resp = await useFetch(`${webhookUrl}/messages/${messageId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(12000),
  });
  if (!resp.ok) throw new Error(`Discord edit failed: ${resp.status}`);
}

module.exports.postToWebhook = postToWebhook;
module.exports.patchWebhookMessage = patchWebhookMessage;
```

Then add the endpoint in `functions/index.js` next to `proxyTmdb` (same CORS + requireAuth pattern):

```js
exports.notifyDiscordWatch = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'private, no-store');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  let username = '';
  try { username = await getVerifiedUsername(decoded); } catch (e) { console.warn('[notifyDiscordWatch] user lookup failed:', e.message); }
  if (username !== 'khentsgdz' && username !== 'clairjassen') { res.status(403).json({ error: 'Couple only' }); return; }
  const { title, posterPath, mediaType, season, episode } = req.body || {};
  if (!title || (mediaType !== 'movie' && mediaType !== 'tv')) { res.status(400).json({ error: 'title + mediaType required' }); return; }
  const { buildWatchPost, postToWebhook, patchWebhookMessage } = require('./discord.js');
  const hostDisplay = username === 'khentsgdz' ? 'Khent' : 'Clair';
  const partnerMention = username === 'khentsgdz'
    ? `<@${(process.env.DISCORD_CLAIR_ID || '').trim()}>`
    : `<@${(process.env.DISCORD_KHENT_ID || '').trim()}>`;
  const voiceUrl = (process.env.DISCORD_VOICE_URL || '').trim();
  const webhookUrl = (process.env.DISCORD_WEBHOOK_URL || '').trim();
  if (!webhookUrl || !voiceUrl) { res.status(503).json({ error: 'Discord is not configured' }); return; }
  const db = getDb();
  const ref = db.collection('discord_watch_sessions').doc('active');
  try {
    const prev = await ref.get();
    if (prev.exists && prev.data().active && prev.data().messageId) {
      try {
        await patchWebhookMessage({ webhookUrl, messageId: prev.data().messageId, payload: { content: `Replaced by new pick: ${title}`, components: [] } });
      } catch (e) { console.warn('[notifyDiscordWatch] supersede edit failed:', e.message); }
    }
    const payload = buildWatchPost({ title, posterPath: posterPath || '', mediaType, season: season ?? null, episode: episode ?? null, voiceUrl, hostDisplay, partnerMention });
    let messageId;
    try {
      messageId = await postToWebhook({ webhookUrl, payload });
    } catch (e) {
      console.warn('[notifyDiscordWatch] post failed:', e.message);
      await ref.set({ title, posterPath: posterPath || '', mediaType, season: season ?? null, episode: episode ?? null, startedBy: username, startedAtMs: Date.now(), active: false, status: 'pending', messageId: '' }, { merge: true });
      res.status(502).json({ error: 'Discord post failed, saved as pending' });
      return;
    }
    await ref.set({ messageId, title, posterPath: posterPath || '', mediaType, season: season ?? null, episode: episode ?? null, startedBy: username, startedAtMs: Date.now(), active: true, status: 'live' });
    res.status(200).json({ messageId });
  } catch (e) { console.warn('[notifyDiscordWatch] failed:', e.message); res.status(500).json({ error: 'Share failed' }); }
});
```

- [ ] **Step 4: Run tests.**

Run: `cd functions && npm test -- test/discord.test.js`
Expected: PASS. Then `cd functions && npm test` full suite still green.

- [ ] **Step 5: Commit.**

```bash
git add functions/discord.js functions/test/discord.test.js functions/index.js
git commit -m "feat(discord): notifyDiscordWatch post endpoint with supersede"
```

---

### Task 3: discordInteractions end back-channel

**Files:**
- Modify: `functions/index.js` (add export), `functions/discord.js` (append `isAllowedDiscordUser`)

**Interfaces:**
- Consumes: `buildEndedPost`, `verifyDiscordSignature`, `patchWebhookMessage` (Tasks 1-2); session doc shape from Task 2.
- Produces: edited Discord message + `active=false, status='ended'`; nothing downstream except Task 6 sweep reads status.

- [ ] **Step 1: Write the failing test.** Append to `functions/test/discord.test.js`:

```js
const { isAllowedDiscordUser } = require('../discord');

describe('isAllowedDiscordUser', () => {
  it('allows only the two configured ids', () => {
    const env = { khent: '111', clair: '222' };
    assert.equal(isAllowedDiscordUser({ userId: '111', env }), true);
    assert.equal(isAllowedDiscordUser({ userId: '222', env }), true);
    assert.equal(isAllowedDiscordUser({ userId: '999', env }), false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `cd functions && npm test -- test/discord.test.js`
Expected: FAIL with "isAllowedDiscordUser is not a function".

- [ ] **Step 3: Write minimal implementation.** Append to `functions/discord.js`:

```js
function isAllowedDiscordUser({ userId, env }) {
  return userId === env.khent || userId === env.clair;
}
module.exports.isAllowedDiscordUser = isAllowedDiscordUser;
```

Add endpoint in `functions/index.js` (public invoker, Discord signature auth — NOT Firebase auth):

```js
exports.discordInteractions = onRequest({ invoker: 'public' }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const sig = req.get('X-Signature-Ed25519') || '';
  const ts = req.get('X-Signature-Timestamp') || '';
  const raw = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(req.body);
  const { verifyDiscordSignature, buildEndedPost, patchWebhookMessage, isAllowedDiscordUser } = require('./discord.js');
  let ok = false;
  try {
    ok = await verifyDiscordSignature({ publicKeyHex: (process.env.DISCORD_PUBLIC_KEY || '').trim(), signatureHex: sig, timestamp: ts, body: raw });
  } catch (e) { console.warn('[discordInteractions] verify failed:', e.message); }
  if (!ok) { res.status(401).json({ error: 'Bad signature' }); return; }
  const body = req.body || {};
  if (body.type === 1) { res.status(200).json({ type: 1 }); return; }
  const memberId = body?.member?.user?.id || body?.user?.id || '';
  const env = { khent: (process.env.DISCORD_KHENT_ID || '').trim(), clair: (process.env.DISCORD_CLAIR_ID || '').trim() };
  if (!isAllowedDiscordUser({ userId: memberId, env })) { res.status(200).json({ type: 4, data: { content: 'Not for you.', flags: 64 } }); return; }
  const name = body?.data?.name || '';
  const button = body?.data?.custom_id || '';
  if (name !== 'end' && button !== 'end_watch') { res.status(200).json({ type: 4, data: { content: 'Unknown command.', flags: 64 } }); return; }
  const db = getDb();
  const ref = db.collection('discord_watch_sessions').doc('active');
  try {
    const snap = await ref.get();
    if (!snap.exists || !snap.data().active) { res.status(200).json({ type: 4, data: { content: 'Nothing active.', flags: 64 } }); return; }
    const s = snap.data();
    const hostDisplay = s.startedBy === 'khentsgdz' ? 'Khent' : 'Clair';
    const webhookUrl = (process.env.DISCORD_WEBHOOK_URL || '').trim();
    try {
      await patchWebhookMessage({ webhookUrl, messageId: s.messageId, payload: buildEndedPost({ title: s.title, hostDisplay }) });
    } catch (e) { console.warn('[discordInteractions] edit failed:', e.message); }
    await ref.set({ active: false, status: 'ended' }, { merge: true });
    res.status(200).json({ type: 4, data: { content: `Ended: ${s.title}`, flags: 64 } });
  } catch (e) { console.warn('[discordInteractions] failed:', e.message); res.status(200).json({ type: 4, data: { content: 'End failed, try again.', flags: 64 } }); }
});
```

After deploy, paste the deployed URL into the Discord app Interactions Endpoint URL and click verify. Register one guild command `/end` (description: End the current movie night) on your private server.

- [ ] **Step 4: Run tests.**

Run: `cd functions && npm test`
Expected: PASS full suite.

- [ ] **Step 5: Commit.**

```bash
git add functions/discord.js functions/test/discord.test.js functions/index.js
git commit -m "feat(discord): interactions end back-channel with signature verify"
```

---

### Task 4: Expiry sweep + Firestore rules for the session doc

**Files:**
- Modify: `functions/index.js` (add scheduled export), `firestore.rules` (add match)

**Interfaces:**
- Consumes: session doc shape from Task 2.
- Produces: `status='expired'` docs the app treats as inactive; rules allow couple read/write.

- [ ] **Step 1: Add the sweep export** in `functions/index.js` beside `sweepStalePresence`:

```js
exports.sweepStaleDiscordWatch = onSchedule({ schedule: 'every 60 minutes' }, async () => {
  const db = getDb();
  const ref = db.collection('discord_watch_sessions').doc('active');
  try {
    const snap = await ref.get();
    if (!snap.exists || !snap.data().active) return;
    if (Date.now() - (snap.data().startedAtMs || 0) < 12 * 60 * 60 * 1000) return;
    const { patchWebhookMessage } = require('./discord.js');
    const webhookUrl = (process.env.DISCORD_WEBHOOK_URL || '').trim();
    try {
      await patchWebhookMessage({ webhookUrl, messageId: snap.data().messageId, payload: { content: `Expired: ${snap.data().title}`, components: [] } });
    } catch (e) { console.warn('[sweepStaleDiscordWatch] edit failed:', e.message); }
    await ref.set({ active: false, status: 'expired' }, { merge: true });
  } catch (e) { console.warn('[sweepStaleDiscordWatch] failed:', e.message); }
});
```

- [ ] **Step 2: Add the rules match** in `firestore.rules` next to the other couple collections:

```
match /discord_watch_sessions/{docId} { allow read: if isCouple(); allow create: if isCouple() && request.resource.data.size() < 8192; allow update: if isCouple() && request.resource.data.size() < 8192; allow delete: if isCouple(); }
```

- [ ] **Step 3: Verify.** Run `cd functions && npm test` (green) and deploy rules only: `firebase deploy --only firestore:rules`. Confirm in Firebase console the match exists.

- [ ] **Step 4: Commit.**

```bash
git add functions/index.js firestore.rules
git commit -m "feat(discord): session expiry sweep and rules"
```

---

### Task 5: Flutter Share to Discord from Cinema

**Files:**
- Create: `lib/features/cinema/data/services/discord_share_service.dart`
- Modify: `lib/features/cinema/presentation/screens/cinema_screen.dart` (+ episode drawer CTA wiring, following the existing drawer CTA pattern)

**Interfaces:**
- Consumes: deployed `notifyDiscordWatch` URL; Firebase ID token from AuthService; media fields (title, posterPath, mediaType, season, episode) already present in the drawer.
- Produces: POST + snackbar feedback; no Firestore writes from client.

- [ ] **Step 1: Create the service** `lib/features/cinema/data/services/discord_share_service.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Posts the current pick to Discord via notifyDiscordWatch.
/// Quiet-fails: returns false and print-logs, cinema stays usable.
class DiscordShareService {
  DiscordShareService({required this.endpoint, http.Client? client})
      : _client = client ?? http.Client();

  final String endpoint;
  final http.Client _client;

  Future<bool> share({
    required String idToken,
    required String title,
    required String posterPath,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    try {
      final resp = await _client.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
        body: jsonEncode({
          'title': title,
          'posterPath': posterPath,
          'mediaType': mediaType,
          if (season != null) 'season': season,
          if (episode != null) 'episode': episode,
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('DiscordShareService.share failed: ${resp.statusCode} ${resp.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('DiscordShareService.share failed: $e');
      return false;
    }
  }
}
```

Wire the endpoint URL the same way `tmdb_base.dart` resolves its function URL (public client value pattern already in repo; never add secrets here). Add a Share to Discord button next to the episode-drawer CTA using theme tokens and EverglowButton; on press, fetch the ID token, call share, show success/error snackbar.

- [ ] **Step 2: Verify.** Run `flutter analyze` (must be clean), `flutter run -d chrome`, pick a movie, tap Share, confirm the A1 embed lands in `#watch-party` with ping + Join voice + End button, and failure with functions offline shows snackbar without crashing cinema.

- [ ] **Step 3: Commit.**

```bash
git add lib/features/cinema/data/services/discord_share_service.dart lib/features/cinema/presentation/screens/cinema_screen.dart
git commit -m "feat(cinema): share to Discord watchparty button"
```

---

### Task 6: Cutover — delete the old watchparty system

Run only after Tasks 1-5 are deployed and one real movie night works end to end over Discord.

**Files:**
- Delete: `lib/features/watch_party`
- Modify: `firestore.rules` (remove `watch_party_rooms`, `watch_party_chats`, `temporary_chats`, `voice_rooms` matches), `functions/index.js` (remove `onWatchPartyInvite` from triggers import/export), dashboard Watch Together card + `StartWatchPartyButton` usages, `core/router/app_router.dart` (remove watchparty routes)

**Interfaces:** Consumes nothing new. Keeps `discord_watch_sessions` rules from Task 4.

- [ ] **Step 1: Remove Firestore matches** for `watch_party_rooms/{roomId}`, `watch_party_chats/{roomId}/messages/{messageId}`, `temporary_chats/{roomId}` (+ subcollection), `voice_rooms/{roomId}` (+ candidates). Keep `discord_watch_sessions`.

- [ ] **Step 2: Remove function trigger.** In `functions/index.js` remove `onWatchPartyInvite` from the triggers require and from exports. Leave all other triggers untouched.

- [ ] **Step 3: Delete the feature.** Delete `lib/features/watch_party`, remove its routes from `core/router/app_router.dart` and DI registrations in `core/di/app_providers.dart`, remove dashboard Watch Together card and cinema `StartWatchPartyButton` usages (Share to Discord from Task 5 is the replacement).

- [ ] **Step 4: Verify.** Run `flutter analyze` (clean), `flutter test` (green), `cd functions && npm test` (green). Cold-start the app, confirm no dead routes or imports reference watch_party. Run one more Share + End cycle.

- [ ] **Step 5: Decide ac-relay.** If play_zone still uses it, keep `ac-relay/server.js` running and note that in the commit message. If nothing references it, stop the process and note decommission.

- [ ] **Step 6: Commit + deploy.**

```bash
git add -A
git commit -m "feat!: replace in-app watchparty with Discord coordinator"
firebase deploy --only functions,firestore:rules,hosting
```

---

## Self-Review

1. Spec coverage: A/A1 coordinator yes (Tasks 1-2, 5); end back-channel yes (Task 3); auto-expiry yes (Task 4); quiet-fail + print logging yes (Tasks 2, 5); couple-only + server-side secrets yes (Tasks 2-4, Global Constraints); deletion list yes (Task 6); flat bills yes (no minInstances anywhere, pay-per-invocation only); ac-relay open point carried into Task 6 Step 5.
2. Placeholder scan: no TBD/TODO/similar-to; every code step shows exact code; env names exact; commands exact.
3. Type consistency: `buildWatchPost` arg names identical in Tasks 1-2; session shape identical in Tasks 2-4; `end_watch` custom_id identical in Tasks 1 and 3; endpoint names identical across tasks.
