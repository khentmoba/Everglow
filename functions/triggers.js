'use strict';

const functions = require('firebase-functions/v1');

const { getAdmin, getDb } = require('./common.js');

// ── FCM Helper ───────────────────────────────────────────────────
async function sendFCMToUser(uid, payload) {
  try {
    const db = getDb();
    const tokenDoc = await db.collection('fcm_tokens').doc(uid).get();
    if (!tokenDoc.exists) return;
    const token = tokenDoc.data()?.token;
    if (!token) return;
    await getAdmin().messaging().send({
      token,
      notification: { title: payload.title, body: payload.body },
      data: payload.data || {},
    });
  } catch (e) {
    console.warn(`FCM send to ${uid} failed:`, e.message);
  }
}

async function sendFCMToBoth(payload) {
  await Promise.all([
    sendFCMToUser('khentsgdz', payload),
    sendFCMToUser('clairjassen', payload),
  ]);
}

/**
 * Fire-and-forget observability: every Mochi tool call lands in
 * mochi_stats/tool_calls so failures and latency are reviewable.
 */
async function logToolCall(toolName, caller, result, elapsedMs) {
  try {
    let ok = true;
    let error = '';
    try {
      const parsed = JSON.parse(result);
      if (parsed && parsed.error) {
        ok = false;
        error = String(parsed.error).slice(0, 300);
      }
    } catch (_) {
      // Result is not JSON or was empty; leave ok as true.
    }
    await getDb().collection('mochi_stats').doc('tool_calls').collection('calls').add({
      tool: toolName,
      caller: caller || 'unknown',
      ok,
      error,
      elapsedMs,
      createdAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.warn('logToolCall failed:', e.message);
  }
}

// ── Firestore Triggers: Partner Notifications ─────────────────────
// UID ↔ display-name lookup. Keys are the Firebase Auth UIDs.
const USER_DISPLAY = {
  khentsgdz: 'Khent',
  clairjassen: 'Clair',
};
// Partner UID map — each user's partner UID.
const PARTNER_UID = {
  khentsgdz: 'clairjassen',
  clairjassen: 'khentsgdz',
};

/**
 * Chat message → notify the partner who didn't send it.
 * Runs on every new document in sanctuary_messages.
 */
const onNewChatMessage = functions.firestore
  .document('sanctuary_messages/{messageId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    // Use sender (username) not senderUid (Auth UID) for partner lookup
    const sender = (data.sender || '').toLowerCase();
    if (!sender || !PARTNER_UID[sender]) return;

    const partnerUid = PARTNER_UID[sender];
    const senderName = USER_DISPLAY[sender] || 'Someone';
    const preview = (data.text || '').slice(0, 120);

    await sendFCMToUser(partnerUid, {
      title: `💌 New message from ${senderName}`,
      body: preview || 'Sent you a message',
      data: { type: 'chat_message', sender },
    });
  });

/**
 * Mood submission → notify the partner.
 * Runs on every new document in moods.
 */
const onNewMood = functions.firestore
  .document('moods/{moodId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = data.uid || data.username;
    if (!uid || !PARTNER_UID[uid]) return;

    const partnerUid = PARTNER_UID[uid];
    const userName = USER_DISPLAY[uid] || 'Someone';
    const emoji = data.moodEmoji || data.mood || '💭';

    await sendFCMToUser(partnerUid, {
      title: `💕 ${userName} shared their mood`,
      body: `Feeling ${emoji} today`,
      data: { type: 'mood' },
    });
  });

/**
 * Starlight jar note → notify the partner.
 */
const onNewStarDrop = functions.firestore
  .document('starlight_notes/{noteId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = data.uid || data.username;
    if (!uid || !PARTNER_UID[uid]) return;

    await sendFCMToUser(PARTNER_UID[uid], {
      title: `⭐ ${USER_DISPLAY[uid] || 'Someone'} left a starlight note`,
      body: 'Open Everglow to read it',
      data: { type: 'starlight' },
    });
  });

/**
 * Watchlist item → notify the partner so you can watch together.
 */
const onNewWatchlistItem = functions.firestore
  .document('watchlist/{itemId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = data.uid || data.username;
    if (!uid || !PARTNER_UID[uid]) return;

    await sendFCMToUser(PARTNER_UID[uid], {
      title: '🍿 New watchlist item',
      body: data.title || 'Something new to watch together',
      data: { type: 'watchlist' },
    });
  });

/**
 * Gallery photo → notify the partner of the new memory.
 */
const onNewGalleryPhoto = functions.firestore
  .document('gallery/{photoId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = data.uid || data.username;
    if (!uid || !PARTNER_UID[uid]) return;

    await sendFCMToUser(PARTNER_UID[uid], {
      title: `📸 ${USER_DISPLAY[uid] || 'Someone'} added a photo`,
      body: data.caption || 'A new memory was added to the gallery',
      data: { type: 'gallery' },
    });
  });

/**
 * Watch party invite → notify the partner.
 */
const onWatchPartyInvite = functions.firestore
  .document('watch_party_invites/{inviteId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const to = (data.to || '').toLowerCase();
    if (!to || !PARTNER_UID[to]) return;

    await sendFCMToUser(PARTNER_UID[to], {
      title: '🎬 Watch party invite',
      body: data.message || 'You have been invited to a watch party',
      data: { type: 'watch_party' },
    });
  });

/**
 * Milestone → celebrate with the couple.
 */
const onNewMilestone = functions.firestore
  .document('milestones/{milestoneId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const title = data.title || 'New milestone';

    await sendFCMToBoth({
      title: '🎉 Milestone reached!',
      body: title,
      data: { type: 'milestone' },
    });
  });

module.exports = {
  sendFCMToUser,
  sendFCMToBoth,
  logToolCall,
  onNewChatMessage,
  onNewMood,
  onNewStarDrop,
  onNewWatchlistItem,
  onNewGalleryPhoto,
  onWatchPartyInvite,
  onNewMilestone,
};
