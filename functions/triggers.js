'use strict';

const functions = require('firebase-functions/v1');

const { getAdmin, getDb } = require('./common.js');
const { allowsPush, pushReservation } = require('./motchi_agent.js');

// ── FCM Helper ───────────────────────────────────────────────────
async function sendFCMToUser(uid, payload) {
  try {
    const db = getDb();
    const ref = db.collection('fcm_tokens').doc(uid);
    const type = payload.data?.type || 'nudge';
    const devices = await ref.collection('devices').get();
    if (!devices.docs.length) return;
    if (payload.motchi && !type.startsWith('reminder')) {
      const allowed = await db.runTransaction(async (tx) => {
        const doc = await tx.get(ref);
        if (!allowsPush(doc.exists ? doc.data()?.motchi : undefined, type)) return false;
        tx.set(ref, { motchi: pushReservation(type) }, { merge: true });
        return true;
      });
      if (!allowed) return;
    }

    // Parent `token` fields are legacy and may belong to a logged-out device.
    // Only explicitly registered installation documents are deliverable.
    const messaging = getAdmin().messaging();
    await Promise.all(devices.docs.map(async (device) => {
      const token = device.data()?.token;
      if (!token) return;
      try {
        await messaging.send({
          token,
          notification: { title: payload.title, body: payload.body },
          data: payload.data || {},
        });
      } catch (e) {
        const code = e.code || e.errorInfo?.code;
        if (code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token') {
          try { await device.ref.delete(); } catch (cleanupError) {
            console.warn(`FCM token cleanup for ${uid} failed:`, cleanupError.message);
          }
        } else {
          console.warn(`FCM send to ${uid} failed:`, e.message);
        }
      }
    }));
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
 * Fire-and-forget observability: every Motchi tool call lands in
 * motchi_stats/tool_calls so failures and latency are reviewable.
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
    await getDb().collection('motchi_stats').doc('tool_calls').collection('calls').add({
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
      data: { type: 'mood_update' },
    });
  });

/**
 * Starlight jar note → notify the partner.
 */
const onNewStarDrop = functions.firestore
  .document('starlight_jar/{noteId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = (data.author || '').toLowerCase();
    if (!uid || !PARTNER_UID[uid]) return;

    await sendFCMToUser(PARTNER_UID[uid], {
      title: `⭐ ${USER_DISPLAY[uid] || 'Someone'} left a starlight note`,
      body: 'Open Everglow to read it',
      data: { type: 'starlight_drop' },
    });
  });

/**
 * Watchlist item → notify the partner so you can watch together.
 */
const onNewWatchlistItem = functions.firestore
  .document('watch_list/{itemId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = (data.userName || '').toLowerCase();
    if (!uid || !PARTNER_UID[uid]) return;

    await sendFCMToUser(PARTNER_UID[uid], {
      title: '🍿 New watchlist item',
      body: data.title || 'Something new to watch together',
      data: { type: 'watchlist_update' },
    });
  });

/**
 * Gallery photo → notify the partner of the new memory.
 */
const onNewGalleryPhoto = functions.firestore
  .document('gallery/{photoId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const uid = (data.uploadedBy || '').toLowerCase();
    if (!uid || !PARTNER_UID[uid]) return;

    await sendFCMToUser(PARTNER_UID[uid], {
      title: `📸 ${USER_DISPLAY[uid] || 'Someone'} added a photo`,
      body: data.caption || 'A new memory was added to the gallery',
      data: { type: 'gallery_photo' },
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

    await sendFCMToUser(to, {
      title: '🎬 Watch party invite',
      body: data.message || 'You have been invited to a watch party',
      data: { type: 'watch_party_invite' },
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
