'use strict';

// Everglow Cloud Functions — Motchi schedules group.
// Morning digest, night recap, mood check-in, smart nudges,
// weekly recap, special-day nudge, reminder checker, memory sweep.

const { onSchedule } = require('firebase-functions/v2/scheduler');

const { getAdmin, getDb } = require('./common.js');
const { composeTodayRecap, simpleEmbedding, needsEmbeddingBackfill, phtDateString, phtDayBounds } = require('./motchi_core.js');
const { sendFCMToUser, sendFCMToBoth } = require('./triggers.js');
const { getRemoteEmbedding } = require('./motchi_memory.js');

// Cap on remote embedding calls per nightly sweep. Local vectors are
// free and unbounded; remote ones cost time + money, so the first 25
// invalid facts per night upgrade and the rest wait their turn.

/**
 * Shared recap fetch for the morning/night/weekly digests: one parallel
 * sweep (moods + activity + starlight + memories, plus watchlist when
 * asked) mapped into the shape composeTodayRecap wants. Raw snapshots
 * ride along so callers can run their own quiet-day checks.
 */
async function collectRecapData(db, {
  dateLabel,
  moodsQuery,
  activityLimit = 5,
  starlightLimit = 3,
  includeWatchlist = true,
}) {
  const jobs = [
    moodsQuery.get(),
    db.collection('recent_activity').orderBy('timestamp', 'desc').limit(activityLimit).get(),
    db.collection('starlight_jar').orderBy('timestamp', 'desc').limit(starlightLimit).get(),
    db.collection('ai_memories').doc('shared').collection('facts').orderBy('createdAt', 'desc').limit(150).get(),
  ];
  if (includeWatchlist) jobs.push(db.collection('our_cinema').limit(5).get());
  const [moodsSnap, activitySnap, starSnap, memorySnap, watchSnap] = await Promise.all(jobs);
  return {
    recapData: {
      dateLabel,
      moods: moodsSnap.docs.map((d) => ({
        uid: d.data().uid || d.data().username || 'someone',
        mood: d.data().mood || d.data().moodEmoji || d.data().moodLabel || 'okay',
      })),
      activities: activitySnap.docs.map((d) => d.data().activity || d.data().description || '').filter(Boolean),
      starlight: starSnap.docs.map((d) => d.data().content || '').filter(Boolean),
      watchlist: watchSnap ? watchSnap.docs.map((d) => d.data().title || '').filter(Boolean) : [],
      memories: memorySnap.docs.map((d) => {
        const data = d.data();
        return {
          fact: data.fact || '',
          occurredAt: data.occurredAt?.toDate?.() || null,
        };
      }),
    },
    snaps: { moodsSnap, activitySnap, starSnap, memorySnap, watchSnap: watchSnap || null },
  };
}

// ── Scheduled: Daily Digest (8:00 AM PHT wall time) ───────────
// NOTE: cron is interpreted in timeZone Asia/Manila below, so these
// are Philippine wall times (NOT UTC — do not 'correct' them).
const motchiDailyDigest = onSchedule({
  schedule: '0 8 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  // Outer guard: a failed Firestore read must log, not throw — an
  // uncaught scheduled run just burns a retry and pages the logs.
  try {
  const db = getDb();
  const today = phtDateString();

  const { recapData, snaps } = await collectRecapData(db, {
    dateLabel: today,
    moodsQuery: db.collection('moods').where('date', '==', today),
  });
  const { moodsSnap, activitySnap, starSnap } = snaps;

  // Quiet-day skip: no moods, no fresh activity, no starlight — the paid
  // LLM polish would just gush over an empty week. The deterministic
  // recap below still goes out, so Clair never misses her digest.
  const _cutoff = Date.now() - 36 * 60 * 60 * 1000;
  const _freshActivity = activitySnap.docs.some((d) => {
    const t = d.data().timestamp;
    const ms = t?.toMillis?.() ?? t?.toDate?.()?.getTime?.() ?? 0;
    return ms > _cutoff;
  });
  const _quietDay = moodsSnap.empty && starSnap.empty && !_freshActivity;
  if (_quietDay) console.log('[motchiDailyDigest] quiet day — skipping LLM polish');

  // Try a real Motchi voice first; fall back to the deterministic recap.
  let digest = composeTodayRecap(recapData);
  try {
    const apiKey = process.env.AGNES_API_KEY;
    if (apiKey && !_quietDay) {
      const dataBlob = JSON.stringify(recapData).slice(0, 6000);
      const resp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'agnes-3.0-flash',
          messages: [
            {
              role: 'system',
              content: 'You are Motchi 🍡, a warm white cat companion for Khent and Clair. Write a short 2-3 sentence morning digest in their voice: reference real details from the data, stay warm, and do not list raw fields.',
            },
            {
              role: 'user',
              content: `Morning data for ${today}:\n${dataBlob}`,
            },
          ],
          max_tokens: 300,
          temperature: 0.7,
          stream: false,
        }),
        signal: AbortSignal.timeout(30000),
      });
      if (resp.ok) {
        const body = await resp.json();
        const text = (body.choices?.[0]?.message?.content || '').trim();
        if (text) digest = text;
      }
    }
  } catch (e) {
    console.warn('motchiDailyDigest LLM failed, using fallback:', e.message);
  }

  await sendFCMToBoth({
    title: '🍡 Motchi\'s Morning Digest',
    body: digest.slice(0, 240),
    data: { type: 'daily_digest' },
  });
  } catch (e) {
    console.warn('[motchiDailyDigest] failed:', e.message);
  }
});

// ── Scheduled: Night Recap (11:11 PM PHT wall time) ──────────────
const motchiNightRecap = onSchedule({
  schedule: '11 23 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  try {
  const db = getDb();
  const today = phtDateString();
  const { recapData } = await collectRecapData(db, {
    dateLabel: today,
    moodsQuery: db.collection('moods').where('date', '==', today),
    includeWatchlist: false,
  });

  const recap = composeTodayRecap(recapData);

  await sendFCMToBoth({
    title: '🌙 Motchi\'s Night Recap',
    body: recap.slice(0, 240),
    data: { type: 'night_recap' },
  });
  } catch (e) {
    console.warn('[motchiNightRecap] failed:', e.message);
  }
});

// ── Scheduled: Mood Check-In (8:00 PM PHT wall time) ──────────
const motchiMoodCheckIn = onSchedule({
  schedule: '0 20 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const today = phtDateString();

  try {
    const moods = await db.collection('moods').where('date', '==', today).get();
    const loggedUids = new Set(moods.docs.map(d => d.data().uid || d.data().username));

    for (const uid of ['khentsgdz', 'clairjassen']) {
      if (!loggedUids.has(uid)) {
        await sendFCMToUser(uid, {
          title: '🍡 Motchi wants to know...',
          body: 'How are you feeling today? Tell me your mood! 💭',
          data: { type: 'mood_checkin' },
        });
      }
    }
  } catch (e) {
    console.warn('[motchiMoodCheckIn] check-in failed:', e.message);
  }

  // W4-D14: Behavior-based initiative — silence gap + mood trend
  try {
    // 48h silence in Sanctuary
    const chatSnap = await db.collection('sanctuary_messages').orderBy('timestamp', 'desc').limit(1).get();
    if (!chatSnap.empty) {
      const last = chatSnap.docs[0].data().timestamp?.toDate?.();
      if (last && (Date.now() - last.getTime()) > 48 * 60 * 60 * 1000) {
        await sendFCMToBoth({
          title: '💭 Motchi misses you two',
          body: "Haven't heard from you in a couple days — everything okay? Send a little hello? 🐾",
          data: { type: 'silence_nudge' },
        });
      }
    }
    // 7-day negative mood trend (sad/stressed/tired/anxious/down)
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const weekMoods = await db.collection('moods').where('timestamp', '>=', weekAgo).limit(100).get();
    const negative = new Set(['sad', 'stressed', 'tired', 'anxious', 'down', 'upset', 'angry', 'lonely']);
    const byUser = { khentsgdz: 0, clairjassen: 0 };
    weekMoods.forEach(doc => {
      const d = doc.data();
      const m = String(d.mood || d.moodEmoji || d.moodLabel || '').toLowerCase();
      const uid = String(d.uid || d.username || '').toLowerCase();
      if (negative.has(m) && Object.hasOwn(byUser, uid)) byUser[uid]++;
    });
    for (const [uid, count] of Object.entries(byUser)) {
      if (count >= 3) {
        await sendFCMToUser(uid, {
          title: '🫶 Motchi is here for you',
          body: "You've had a few tough days — I'm here, and your person is too. Want to talk or pick a gentle date idea? 💗",
          data: { type: 'mood_trend_nudge' },
        });
      }
    }
  } catch (e) {
    console.warn('[motchiMoodCheckIn] behavior nudge failed:', e.message);
  }
});

// ── Scheduled: Smart Behavior Nudge (7pm PHT daily) — checks streaks, overdue bucket, journal silence, tomorrow calendar ───────
const motchiSmartNudge = onSchedule({
  schedule: '0 19 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const now = new Date();
  const todayStr = phtDateString(now.getTime());
  try {
    const logRef = db.collection('motchi_nudge_log').doc(todayStr);
    const logSnap = await logRef.get();
    const logged = logSnap.exists ? logSnap.data() : {};
    try {
      const habitsSnap = await db.collection('habits').where('isActive','==',true).limit(20).get();
      for (const doc of habitsSnap.docs) {
        const h = doc.data();
        const completedToday = (h.completedDates||[]).some(d => {
          const dt = d.toDate ? d.toDate() : new Date(d);
          return phtDateString(dt.getTime()) === todayStr;
        });
        if (!completedToday && (h.streak||0) >= 2 && !logged[`habit_${doc.id}`]) {
          const owner = h.createdBy || 'khentsgdz';
          await sendFCMToUser(owner, {
            title: `Keep your ${h.streak}-day streak!`,
            body: `Don't break your "${h.title}" streak — log it today? Motchi is cheering you on!`,
            data: { type: 'habit_streak', habitId: doc.id },
          });
          await logRef.set({ [`habit_${doc.id}`]: true, updatedAt: getAdmin().firestore.FieldValue.serverTimestamp() }, { merge: true });
          break;
        }
      }
    } catch (e) { console.warn('[smartNudge] habit', e.message); }
    try {
      const bucketSnap = await db.collection('bucket_list').where('status','in',['wish','planned']).limit(30).get();
      const dueSoon = bucketSnap.docs.filter(d => {
        const dd = d.data().dueDate?.toDate?.();
        if (!dd) return false;
        const diff = Math.ceil((dd - now)/(24*60*60*1000));
        return diff >= 0 && diff <= 2;
      });
      if (dueSoon.length > 0 && !logged.bucket) {
        const item = dueSoon[0].data();
        await sendFCMToBoth({
          title: `"${item.title}" is due soon!`,
          body: `Your bucket dream is around the corner — want to plan it? Motchi remembers!`,
          data: { type: 'bucket_due' },
        });
        await logRef.set({ bucket: true, updatedAt: getAdmin().firestore.FieldValue.serverTimestamp() }, { merge: true });
      }
    } catch (e) { console.warn('[smartNudge] bucket', e.message); }
    try {
      const journalSnap = await db.collection('journal_entries').orderBy('createdAt','desc').limit(1).get();
      if (!journalSnap.empty) {
        const last = journalSnap.docs[0].data().createdAt?.toDate?.();
        if (last && (now - last)/(24*60*60*1000) > 4 && !logged.journal) {
          await sendFCMToBoth({
            title: 'Motchi misses your words',
            body: 'It has been a few quiet days — want to write a little memory together?',
            data: { type: 'journal_nudge' },
          });
          await logRef.set({ journal: true, updatedAt: getAdmin().firestore.FieldValue.serverTimestamp() }, { merge: true });
        }
      }
    } catch (e) { console.warn('[smartNudge] journal', e.message); }
    try {
      const { start: startTomorrow, end: endTomorrow } = phtDayBounds(now.getTime() + 24 * 60 * 60 * 1000);
      const calSnap = await db.collection('calendar_events')
        .where('date','>=', getAdmin().firestore.Timestamp.fromDate(startTomorrow))
        .where('date','<=', getAdmin().firestore.Timestamp.fromDate(endTomorrow))
        .limit(3).get();
      if (!calSnap.empty && !logged.calendar) {
        const titles = calSnap.docs.map(d => d.data().title || 'Untitled').join(', ');
        await sendFCMToBoth({
          title: `Tomorrow: ${titles}`,
          body: 'Motchi sees you have plans — sleep well and enjoy tomorrow together!',
          data: { type: 'calendar_preview' },
        });
        await logRef.set({ calendar: true, updatedAt: getAdmin().firestore.FieldValue.serverTimestamp() }, { merge: true });
      }
    } catch (e) { console.warn('[smartNudge] calendar', e.message); }
  } catch (e) {
    console.warn('[motchiSmartNudge] failed', e.message);
  }
});

// ── Scheduled: Weekly Recap (Sunday 9am PHT) — W4-D15 ───────
const motchiWeeklyRecap = onSchedule({
  schedule: '0 9 * * 0',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const todayStr = phtDateString(now.getTime());
  const weekStartStr = phtDateString(weekAgo.getTime());
  try {
    const { recapData, snaps } = await collectRecapData(db, {
      dateLabel: `${weekStartStr} to ${todayStr}`,
      moodsQuery: db.collection('moods').where('timestamp', '>=', weekAgo).limit(50),
      activityLimit: 10,
      starlightLimit: 5,
    });
    const { moodsSnap, activitySnap, starSnap } = snaps;
    let recap = composeTodayRecap(recapData);
    // Quiet-week skip: same idea as the daily digest — empty weeks get
    // the deterministic recap, no paid polish.
    const _wCutoff = Date.now() - 8 * 24 * 60 * 60 * 1000;
    const _wFresh = activitySnap.docs.some((d) => {
      const t = d.data().timestamp;
      const ms = t?.toMillis?.() ?? t?.toDate?.()?.getTime?.() ?? 0;
      return ms > _wCutoff;
    });
    const _quietWeek = moodsSnap.empty && starSnap.empty && !_wFresh && recapData.activities.length === 0;
    if (_quietWeek) console.log('[motchiWeeklyRecap] quiet week — skipping LLM polish');
    // Try LLM polish (same as daily digest, but weekly)
    try {
      const apiKey = process.env.AGNES_API_KEY;
      if (apiKey && !_quietWeek) {
        const dataBlob = JSON.stringify(recapData).slice(0, 6000);
        const resp = await fetch('https://apihub.agnes-ai.com/v1/chat/completions', {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: 'agnes-3.0-flash',
            messages: [
              { role: 'system', content: 'You are Motchi 🍡, a warm white cat companion for Khent and Clair. Write a cozy 3-4 sentence weekly recap for their week — reference real moods, activities, starlight notes, and watchlist naturally. Stay warm, celebrate their rhythm, and don\'t list raw fields.' },
              { role: 'user', content: `Week ${weekStartStr} to ${todayStr} data:\n${dataBlob}` },
            ],
            max_tokens: 400,
            temperature: 0.7,
            stream: false,
          }),
          signal: AbortSignal.timeout(30000),
        });
        if (resp.ok) {
          const body = await resp.json();
          const text = (body.choices?.[0]?.message?.content || '').trim();
          if (text) recap = text;
        }
      }
    } catch (e) {
      console.warn('motchiWeeklyRecap LLM failed, using fallback:', e.message);
    }
    await sendFCMToBoth({
      title: '📅 Motchi\'s Weekly Recap',
      body: recap.slice(0, 240),
      data: { type: 'weekly_recap' },
    });
  } catch (e) {
    console.warn('[motchiWeeklyRecap] failed:', e.message);
  }
});

// ── Scheduled: Special Day Nudge (9:00 AM PHT wall time) ───────
const motchiSpecialDayNudge = onSchedule({
  schedule: '0 9 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const now = new Date();
  const mmdd = phtDateString(now.getTime()).slice(5);

  const specialDays = {
    '02-14': 'Valentine\'s Day (Anniversary!)',
    '10-26': 'Khent\'s Birthday',
    '02-21': 'Clair\'s Birthday',
  };

  if (specialDays[mmdd]) {
    await sendFCMToBoth({
      title: `💕 ${specialDays[mmdd]}`,
      body: `Today is ${specialDays[mmdd]}! Motchi has something special planned~`,
      data: { type: 'special_day', event: specialDays[mmdd] },
    });
  }

  // Check upcoming special days within 7 days
  for (const [date, event] of Object.entries(specialDays)) {
    if (date === mmdd) continue;
    const [m, d] = date.split('-').map(Number);
    const thisYear = new Date(now.getFullYear(), m - 1, d);
    if (thisYear < now) thisYear.setFullYear(thisYear.getFullYear() + 1);
    const daysUntil = Math.ceil((thisYear - now) / (1000 * 60 * 60 * 24));
    if (daysUntil > 0 && daysUntil <= 7) {
      await sendFCMToBoth({
        title: `💕 Coming Up: ${event}`,
        body: `${event} is in ${daysUntil} days! Maybe plan something special?`,
        data: { type: 'special_day_upcoming', event, days_until: daysUntil.toString() },
      });
    }
  }
});

// ── Scheduled: Reminder Checker (every 10 min PHT) — W1-A2 ───────
const motchiReminderChecker = onSchedule({
  schedule: 'every 10 minutes',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  try {
    const now = getAdmin().firestore.Timestamp.now();
    // Indexed due query (reminders/fired+remindAtTs in firestore.indexes.json)
    // so the 10-minute tick reads only what's due instead of scanning up
    // to 100 pending docs. Falls back to the old scan when the index is
    // still building — reminders must never silently stop firing.
    let snap;
    try {
      snap = await db.collection('reminders')
        .where('fired', '==', false)
        .where('remindAtTs', '<=', now)
        .limit(100).get();
    } catch (e) {
      console.warn('[motchiReminderChecker] indexed query failed, falling back to scan:', e.message);
      snap = await db.collection('reminders').where('fired', '==', false).limit(100).get();
    }
    if (snap.empty) return;
    let firedCount = 0;
    const jobs = snap.docs.map(async (doc) => {
      const data = doc.data();
      const ts = data.remindAtTs;
      if (!ts || typeof ts.toDate !== 'function') return;
      const due = ts.toDate();
      if (due > now.toDate()) return;
      const createdBy = (data.createdBy || '').toString().toLowerCase();
      const title = (data.title || 'Reminder').toString().slice(0, 120);
      const note = (data.note || '').toString().slice(0, 180);
      const body = note ? `${title} — ${note}` : title;
      // Fire notification to creator (and partner if available)
      if (createdBy) {
        await sendFCMToUser(createdBy, {
          title: '⏰ Motchi Reminder',
          body: body.slice(0, 240),
          data: { type: 'reminder', reminderId: doc.id, title },
        });
        // Also notify partner for shared awareness (inline map to avoid forward-ref)
        const partnerMap = { khentsgdz: 'clairjassen', clairjassen: 'khentsgdz' };
        const partner = partnerMap[createdBy];
        if (partner) {
          await sendFCMToUser(partner, {
            title: `⏰ Reminder for ${createdBy === 'khentsgdz' ? 'Khent' : 'Clair'}`,
            body: body.slice(0, 240),
            data: { type: 'reminder_shared', reminderId: doc.id, title, for: createdBy },
          });
        }
      }
      await doc.ref.update({
        fired: true,
        firedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      });
      firedCount++;
      return null; // map-to-promises: values unused, allSettled joins only
    });
    await Promise.allSettled(jobs);
    if (firedCount > 0) console.log(`[motchiReminderChecker] fired ${firedCount}/${snap.size}`);
  } catch (e) {
    console.warn('[motchiReminderChecker] failed:', e.message);
  }
});

// ── Scheduled: Memory sweep (daily 3am PHT) — W3-C12 ───────
// Halves confidence for memories not accessed in 90d and prunes
// those that fall below 0.15 (except pinned). Keeps fact store lean.
const motchiMemorySweep = onSchedule({
  schedule: '0 3 * * *',
  timeZone: 'Asia/Manila',
  region: 'us-central1',
}, async () => {
  const db = getDb();
  try {
    const snap = await db.collection('ai_memories').doc('shared').collection('facts').limit(300).get();
    if (snap.empty) return;
    const now = Date.now();
    let pruned = 0;
    let updated = 0;
    let backfilled = 0;
    let remoteBudget = 25;
    const jobs = snap.docs.map(async (doc) => {
      const data = doc.data();
      // Backfill: invalid embeddings (missing, malformed, odd dims)
      // recompute remote-first within budget, else locally. Runs for
      // pinned docs too. (Check-and-decrement is sync, so the budget
      // holds exactly even though the jobs run concurrently.)
      if (data.fact && needsEmbeddingBackfill(data.embedding)) {
        try {
          let emb = null;
          if (remoteBudget > 0) {
            remoteBudget--;
            emb = await getRemoteEmbedding(String(data.fact));
          }
          if (!emb) emb = simpleEmbedding(String(data.fact), 64);
          if (emb) {
            await doc.ref.update({ embedding: emb });
            backfilled++;
          }
        } catch (_) {}
      }
      if (data.pinned === true) return;
      const last = data.lastAccessed?.toDate?.() ? data.lastAccessed.toDate().getTime() : (data.createdAt?.toDate?.()?.getTime() || now);
      const daysSince = (now - last) / (1000 * 60 * 60 * 24);
      if (daysSince <= 90) return;
      const currentConf = Number(data.confidence ?? 1);
      const decayed = currentConf * Math.pow(0.5, daysSince / 90);
      if (decayed < 0.15) {
        await doc.ref.delete();
        pruned++;
      } else if (Math.abs(decayed - currentConf) > 0.05) {
        await doc.ref.update({ confidence: decayed });
        updated++;
      }
      return null; // map-to-promises: values unused, allSettled joins only
    });
    await Promise.allSettled(jobs);
    if (pruned > 0 || updated > 0 || backfilled > 0) console.log(`[motchiMemorySweep] pruned=${pruned} updated=${updated} backfilled=${backfilled} scanned=${snap.size}`);
  } catch (e) {
    console.warn('[motchiMemorySweep] failed:', e.message);
  }
});

module.exports = {
  motchiDailyDigest,
  motchiNightRecap,
  motchiMoodCheckIn,
  motchiSmartNudge,
  motchiWeeklyRecap,
  motchiSpecialDayNudge,
  motchiReminderChecker,
  motchiMemorySweep,
  collectRecapData,
};
