'use strict';

/* Motchi social tool executors — moved verbatim from
 * motchi_chat.js executeTool() (mechanical split, no behavior change).
 * Each executor is (ctx, args) => JSON string. Shared services
 * ride on ctx (see motchi_exec_tools.js createToolCtx).
 */

async function exec_set_mood(ctx, args) {
    // PHT day key + username mirror so app reads (username/
    // timestamp based) and server reads (date based) see the
    // same record.
    const today = ctx.phtDateString();
    await ctx.db.collection('moods').doc(`${ctx.callerUid}_${today}`).set({
      mood: args.mood,
      note: args.note || null,
      uid: ctx.callerUid,
      username: ctx.callerUid,
      date: today,
      timestamp: ctx.admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return JSON.stringify({ success: true, mood: args.mood });
}

async function exec_read_chat_messages(ctx, args) {
    const limit = Math.min(args.limit || 20, 50);
    let query = ctx.db.collection('sanctuary_messages')
      .orderBy('timestamp', 'desc')
      .limit(limit);
    const chatSnap = await query.get();
    let messages = chatSnap.docs.map(d => {
      const data = d.data();
      return {
        sender: data.sender || data.senderUid || 'unknown',
        text: (data.text || data.content || '').slice(0, 500),
        timestamp: data.timestamp?.toDate?.()?.toISOString() || null,
      };
    });
    // Filter by sender if specified
    if (args.sender && args.sender !== 'both') {
      messages = messages.filter(m => m.sender === args.sender);
    }
    // Reverse to chronological order
    messages.reverse();
    return JSON.stringify({ messages, count: messages.length });
}

async function exec_send_sanctuary_message(ctx, args) {
    const text = String(args.text || '').trim();
    if (!text) return JSON.stringify({ error: 'No text provided' });
    if (text.length > 2000) return JSON.stringify({ error: 'Message too long (max 2000)' });
    // Resolve sender username from ctx.callerUid (already verified)
    const sender = (ctx.callerUid || 'motchi').toLowerCase();
    await ctx.db.collection('sanctuary_messages').add({
      text,
      sender,
      senderUid: sender,
      timestamp: ctx.admin.firestore.FieldValue.serverTimestamp(),
      via: 'motchi',
      createdBy: ctx.callerUid,
    });
    // Notify partner (reuse FCM helper)
    const partnerMap = { khentsgdz: 'clairjassen', clairjassen: 'khentsgdz' };
    const partner = partnerMap[sender];
    if (partner) {
      await ctx.sendFCMToUser(partner, {
        title: `💌 New message from ${sender === 'khentsgdz' ? 'Khent' : 'Clair'} via Motchi`,
        body: text.slice(0, 120),
        data: { type: 'chat_message', sender },
      });
    }
    return JSON.stringify({ success: true, text: text.slice(0, 200) });
}

async function exec_send_note_to_partner(ctx, args) {
    const note = (args.note || '').trim();
    if (!note) return JSON.stringify({ error: 'No note provided' });
    const partnerUid = PARTNER_UID[ctx.callerUid];
    if (!partnerUid) return JSON.stringify({ error: 'Unknown partner for this user' });
    await ctx.db.collection('motchi_notes').add({
      from: ctx.callerUid,
      to: partnerUid,
      content: note,
      read: false,
      createdAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
      writtenBy: 'Motchi 🍡',
    });
    await ctx.sendFCMToUser(partnerUid, {
      title: '💌 Motchi has a note for you',
      body: note.slice(0, 120),
      data: { type: 'motchi_note', from: ctx.callerUid },
    });
    return JSON.stringify({ success: true, to: partnerUid });
}

async function exec_get_xp_stats(ctx, args) {
    const users = ['khentsgdz', 'clairjassen'];
    const targetUsers = args.user && args.user !== 'both'
      ? [args.user]
      : users;
    const stats = {};
    for (const uid of targetUsers) {
      const doc = await ctx.db.collection('users').doc(uid).collection('progress').doc('main').get();
      if (doc.exists) {
        const d = doc.data();
        stats[uid] = {
          level: d.level || 1,
          xpTotal: d.xpTotal || 0,
          streak: d.streak || 0,
        };
      } else {
        stats[uid] = { level: 1, xpTotal: 0, streak: 0 };
      }
    }
    return JSON.stringify({ stats });
}

// Motchi-awarded XP is capped per Philippine day so "give me XP" loops
// can't print levels. One level's worth (200) is generous; real
// activity awards (moods, garden, journal…) are unaffected — this
// guards the LLM-triggered tool only.
const MOTCHI_XP_DAILY_CAP = 200;

async function exec_add_xp(ctx, args) {
  const amount = Math.min(Math.max(Number(args.amount) || 25, 1), 100);
  const uid = ctx.callerUid || 'khentsgdz';
  const ref = ctx.db.collection('users').doc(uid).collection('progress').doc('main');
  const doc = await ref.get();
  const data = (doc.exists && doc.data()) || {};
  const current = data.xpTotal || 0;
  const today = ctx.phtDateString();
  const dayTotal = (data.motchiXpDate === today && data.motchiXpDayTotal) || 0;
  if (dayTotal >= MOTCHI_XP_DAILY_CAP) {
    return JSON.stringify({
      success: false,
      capped: true,
      dayTotal,
      cap: MOTCHI_XP_DAILY_CAP,
      xpTotal: current,
      level: ctx.levelForXp(current),
      message: 'Daily Motchi treat limit reached — more applause tomorrow!',
    });
  }
  const grant = Math.min(amount, MOTCHI_XP_DAILY_CAP - dayTotal);
  const xpTotal = current + grant;
  const level = ctx.levelForXp(xpTotal);
  await ref.set({
    xpTotal,
    level,
    streak: doc.exists ? (doc.data()?.streak || 0) : 0,
    lastAwardReason: args.reason || 'Motchi award',
    lastAwardedAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
    motchiXpDate: today,
    motchiXpDayTotal: dayTotal + grant,
  }, { merge: true });
  return JSON.stringify({
    success: true, uid, amount: grant, xpTotal, level,
    dayTotal: dayTotal + grant, cap: MOTCHI_XP_DAILY_CAP,
  });
}

async function exec_log_activity(ctx, args) {
    await ctx.db.collection('recent_activity').add({
      activity: args.activity,
      category: args.category || 'other',
      loggedBy: ctx.callerUid,
      timestamp: ctx.admin.firestore.FieldValue.serverTimestamp(),
    });
    return JSON.stringify({ success: true });
}

async function exec_get_gallery(ctx, args) {
  const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
  const wantImages = args.include_images === true;
  const snap = await ctx.db.collection('gallery').orderBy('createdAt', 'desc').limit(limit).get();
  if (snap.empty) return JSON.stringify({ photos: [], count: 0 });
  const vision = [];
  const photos = snap.docs.map((d) => {
    const data = d.data();
    // Vision is thumbnails-first (400px is plenty to see contents) and
    // capped at 3 per call — each image costs vision tokens.
    if (wantImages && vision.length < 3) {
      const url = data.thumbUrl || data.imageUrl || '';
      if (url) vision.push({ url, caption: (data.caption || '').slice(0, 120) });
    }
    return {
      caption: (data.caption || '').slice(0, 200),
      uploadedBy: data.uploadedBy || data.author || '',
      imageUrl: data.imageUrl ? '[image]' : '',
      createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
    };
  });
  const out = { photos, count: photos.length };
  if (vision.length > 0) out.vision_images = vision;
  return JSON.stringify(out);
}

async function exec_get_garden(ctx, args) {
    const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
    const snap = await ctx.db.collection('garden_plants').orderBy('plantedAt', 'desc').limit(limit).get();
    if (snap.empty) return JSON.stringify({ plants: [], count: 0 });
    const plants = snap.docs.map(d => {
      const data = d.data();
      return {
        name: data.name || data.plantName || 'Plant',
        status: data.status || 'growing',
        plantedBy: data.plantedBy || '',
        plantedAt: data.plantedAt?.toDate?.()?.toISOString() || null,
      };
    });
    return JSON.stringify({ plants, count: plants.length });
}

async function exec_get_canvas(ctx, args) {
    const limit = Math.min(Math.max(Number(args.limit) || 10, 1), 20);
    const snap = await ctx.db.collection('canvas_drawings').orderBy('createdAt', 'desc').limit(limit).get();
    if (snap.empty) return JSON.stringify({ drawings: [], count: 0 });
    const drawings = snap.docs.map(d => {
      const data = d.data();
      return {
        title: data.title || 'Untitled',
        drawnBy: data.drawnBy || data.createdBy || '',
        createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
      };
    });
    return JSON.stringify({ drawings, count: drawings.length });
}

module.exports = {
  exec_set_mood,
  exec_read_chat_messages,
  exec_send_sanctuary_message,
  exec_send_note_to_partner,
  exec_get_xp_stats,
  exec_add_xp,
  exec_log_activity,
  exec_get_gallery,
  exec_get_garden,
  exec_get_canvas,
};
