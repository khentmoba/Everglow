'use strict';

const functions = require('firebase-functions/v1');

const { getAdmin, getDb } = require('./common.js');

// ── FCM Helper ───────────────────────────────────────────────────
async function sendFCMToUser(username, payload) {
  try {
    const db = getDb();
    const tokenDocs = await db
      .collection('fcm_tokens')
      .where('username', '==', username)
      .limit(20)
      .get();
    const invalidDocs = [];
    await Promise.all(
      tokenDocs.docs.map(async (tokenDoc) => {
        const token = tokenDoc.data()?.token;
        if (!token) {
          invalidDocs.push(tokenDoc.ref);
          return;
        }
        try {
          await getAdmin().messaging().send({
            token,
            notification: { title: payload.title, body: payload.body },
            data: payload.data || {},
          });
        } catch (error) {
          const invalidCodes = [
            'messaging/registration-token-not-registered',
            'messaging/invalid-registration-token',
          ];
          if (invalidCodes.includes(error.code)) {
            invalidDocs.push(tokenDoc.ref);
          }
          throw error;
        }
      }),
    ).catch((errors) => {
      for (const error of errors) {
        if (error?.reason) console.warn(`FCM send to ${username} failed:`, error.reason.message);
      }
    });
    if (invalidDocs.length > 0) {
      const snapshots = await db.getAll(...invalidDocs);
      await Promise.all(snapshots.map((snapshot) => snapshot.ref.delete()));
    }
  } catch (error) {
    console.warn(`FCM token lookup for ${username} failed:`, error.message);
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
    const uid = data.author;
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
    const uid = data.userName;
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
    const uid = data.uploadedBy;
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
  .document('watch_party_rooms/{roomId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const partnerUid = data.partnerUid;
    if (!partnerUid) return;
    const partnerDoc = await getDb().collection('users').doc(partnerUid).get();
    const partnerUsername = partnerDoc.data()?.username;
    if (!partnerUsername) return;

    await sendFCMToUser(partnerUsername, {
      title: '🎬 Watch party invite',
      body: data.title ? `Ready to watch ${data.title}?` : 'Your partner started a watch party',
      data: { type: 'watch_party_invite', roomId: snap.id },
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
