'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const common = require('./common.js');
const { sendFCMToUser } = require('./triggers.js');

const COUPLE_USERS = ['khentsgdz', 'clairjassen'];
const MANGA_HOME_URL = 'https://mangakatana.com/';

function isWithinQuietHours(hour, startHour, endHour) {
  if (startHour === endHour) return false;
  if (startHour < endHour) return hour >= startHour && hour < endHour;
  return hour >= startHour || hour < endHour;
}

function manilaHourAndDay(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hour12: false,
  }).formatToParts(now);
  const get = (type) => parts.find((p) => p.type === type)?.value || '';
  const hour = Number(get('hour')) % 24;
  const dayKey = `${get('year')}-${get('month')}-${get('day')}`;
  return { hour, dayKey };
}

function parseChapterNumber(raw) {
  const m = /(\d+(?:\.\d+)?)/.exec(String(raw || ''));
  return m ? Number.parseFloat(m[1]) : Number.NaN;
}

function extractLatestChaptersFromHomeHtml(html) {
  const out = new Map();
  if (!html || typeof html !== 'string') return out;
  const itemRe = /href="https?:\/\/mangakatana\.com\/manga\/([^/"?#]+)(?:\/c([^/"?#]+))?"[^>]*>([^<]*)</gi;
  let match;
  while ((match = itemRe.exec(html)) !== null) {
    const slug = (match[1] || '').trim();
    const chId = (match[2] || '').trim();
    if (!slug || !chId) continue;
    const chNum = parseChapterNumber(chId);
    const prev = out.get(slug);
    if (!prev || (Number.isFinite(chNum) && chNum > prev.num)) {
      out.set(slug, {
        chapterId: `c${chId}`,
        chapterNum: chId,
        num: Number.isFinite(chNum) ? chNum : -1,
      });
    }
  }
  return out;
}

function buildMangaPushPayload(updates) {
  if (!Array.isArray(updates) || updates.length === 0) return null;
  if (updates.length === 1) {
    const u = updates[0];
    return {
      title: `New chapter: ${u.title}`,
      body: `Chapter ${u.chapterNum} is out now on Manga Celestia.`,
      data: { type: 'manga_update', slug: u.slug },
    };
  }
  const names = updates.slice(0, 2).map((u) => u.title).join(', ');
  const extra = updates.length > 2 ? ` +${updates.length - 2} more` : '';
  return {
    title: `${updates.length} followed manga updated`,
    body: `${names}${extra} have new chapters ready to read.`,
    data: { type: 'manga_update', slug: updates[0].slug },
  };
}

async function fetchMangaHomeLatest(fetchFn = common.fetchPublicUrl) {
  const upstream = await fetchFn(MANGA_HOME_URL, {
    headers: {
      'User-Agent': 'Everglow/1.0 (+https://everglow-1c6db.web.app)',
      Accept: 'text/html,application/xhtml+xml',
    },
    signal: AbortSignal.timeout(12000),
    httpsOnly: true,
    isAllowedUrl: (u) => {
      const host = u.hostname.toLowerCase();
      return host === 'mangakatana.com' || host === 'www.mangakatana.com';
    },
  });
  if (!upstream.ok) return new Map();
  const html = await common.readLimitedText(upstream.body, 1500 * 1024);
  return extractLatestChaptersFromHomeHtml(html);
}

async function runMangaUpdateCheck({
  db = common.getDb(),
  sendPush = sendFCMToUser,
  fetchLatest = fetchMangaHomeLatest,
  now = new Date(),
} = {}) {
  const latestBySlug = await fetchLatest();
  if (!latestBySlug || latestBySlug.size === 0) return { checkedUsers: 0, sentCount: 0 };

  const { hour, dayKey } = manilaHourAndDay(now);
  let sentCount = 0;

  for (const uid of COUPLE_USERS) {
    const prefsRef = db.collection('katana_bookmarks').doc(`${uid}|__prefs__`);
    const prefsSnap = await prefsRef.get();
    const prefs = prefsSnap.exists ? (prefsSnap.data() || {}) : {};

    if (prefs.chapterAlertsEnabled === false) continue;
    const quietEnabled = Boolean(prefs.alertPrefs?.quietHours ?? prefs.quietHoursEnabled);
    const quietStart = typeof prefs.quietStartHour === 'number' ? prefs.quietStartHour : 22;
    const quietEnd = typeof prefs.quietEndHour === 'number' ? prefs.quietEndHour : 8;
    if (quietEnabled && isWithinQuietHours(hour, quietStart, quietEnd)) continue;

    const mode = prefs.alertPrefs?.frequency === 'daily' || prefs.chapterAlertsMode === 'daily_digest'
      ? 'daily_digest'
      : 'instant';
    if (mode === 'daily_digest' && prefs.lastPushDigestDay === dayKey) continue;

    const snap = await db
      .collection('katana_bookmarks')
      .where('userName', '==', uid)
      .where('bookmarked', '==', true)
      .get();

    const freshUpdates = [];
    for (const docSnap of snap.docs) {
      if (docSnap.id.endsWith('|__prefs__')) continue;
      const data = docSnap.data() || {};
      if (data.notifyOnUpdate === false) continue;
      const slug = typeof data.slug === 'string' ? data.slug.trim() : '';
      if (!slug) continue;
      const latest = latestBySlug.get(slug);
      if (!latest) continue;

      const prevNotified = parseChapterNumber(data.lastNotifiedChapter || data.latestChapterNum || '');
      if (Number.isFinite(latest.num) && Number.isFinite(prevNotified) && latest.num <= prevNotified) {
        continue;
      }
      if (!Number.isFinite(latest.num) && (data.lastNotifiedChapter === latest.chapterNum)) {
        continue;
      }

      freshUpdates.push({
        ref: docSnap.ref,
        slug,
        title: data.title || slug,
        chapterNum: latest.chapterNum,
      });
    }

    if (freshUpdates.length === 0) continue;

    const payload = buildMangaPushPayload(freshUpdates);
    if (!payload) continue;

    const delivered = await sendPush(uid, payload);
    if (!delivered) continue;

    sentCount += 1;
    await Promise.all(
      freshUpdates.map((u) =>
        u.ref.set(
          {
            lastNotifiedChapter: u.chapterNum,
            latestChapterNum: u.chapterNum,
            lastNotifiedAt: Date.now(),
          },
          { merge: true },
        ),
      ),
    );
    if (mode === 'daily_digest') {
      await prefsRef.set({ lastPushDigestDay: dayKey }, { merge: true });
    }
  }

  return { checkedUsers: COUPLE_USERS.length, sentCount };
}

const checkMangaUpdates = onSchedule(
  { schedule: 'every 60 minutes', timeoutSeconds: 120, memory: '256MiB' },
  async () => {
    try {
      await runMangaUpdateCheck();
    } catch (e) {
      console.warn('[checkMangaUpdates] failed:', e.message);
    }
  },
);

module.exports = {
  checkMangaUpdates,
  runMangaUpdateCheck,
  extractLatestChaptersFromHomeHtml,
  buildMangaPushPayload,
  isWithinQuietHours,
};
