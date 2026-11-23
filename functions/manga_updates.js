'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const common = require('./common.js');
const { sendFCMToUser } = require('./triggers.js');

const COUPLE_USERS = ['khentsgdz', 'clairjassen'];
const MANGA_HOME_URL = 'https://mangakatana.com/';
const MANGA_FEED_URL = 'https://mangakatana.com/feed';
const MANGADEX_API_BASE = 'https://api.mangadex.org';
const MANGADEX_PER_RUN_CAP = 25;
const KATANA_SERIES_PER_RUN_CAP = 10;
// Per-series page reads stop here so the hourly job finishes well inside its 120s budget.
const SERIES_LOOKUP_BUDGET_MS = 70000;
const HOUR_MS = 60 * 60 * 1000;
const MIN_CADENCE_MS = 6 * HOUR_MS;
const MAX_CADENCE_MS = 7 * 24 * HOUR_MS;
const DEFAULT_CADENCE_MS = 12 * HOUR_MS;

/**
 * Mihon Smart Updates cadence predictor ("hourglass"):
 * Estimates when a followed series is next due for a direct page check based on
 * observed notification intervals (`releaseIntervalMs` or `lastNotifiedAt - prevNotifiedAt`)
 * and how many consecutive checks saw no update (`consecutiveIdleChecks`).
 */
function computePredictedCadenceMs(data = {}, foundUpdate = false) {
  const prevInterval =
    typeof data.releaseIntervalMs === 'number' && data.releaseIntervalMs > 0
      ? data.releaseIntervalMs
      : typeof data.lastNotifiedAt === 'number' &&
          typeof data.prevNotifiedAt === 'number' &&
          data.lastNotifiedAt > data.prevNotifiedAt
        ? data.lastNotifiedAt - data.prevNotifiedAt
        : DEFAULT_CADENCE_MS;
  const base = Math.min(MAX_CADENCE_MS, Math.max(MIN_CADENCE_MS, Math.round(prevInterval * 0.5)));
  if (foundUpdate) return base;
  const idle = typeof data.consecutiveIdleChecks === 'number' && data.consecutiveIdleChecks > 0 ? data.consecutiveIdleChecks : 0;
  // Gently widen the check interval after repeated idle probes, capped at 24h for active series.
  const backoff = Math.min(24 * HOUR_MS, Math.round(base * (1 + Math.min(4, idle) * 0.15)));
  return Math.min(MAX_CADENCE_MS, Math.max(MIN_CADENCE_MS, backoff));
}

function computeNextCheckAt(data = {}, nowMs = Date.now(), foundUpdate = false) {
  return nowMs + computePredictedCadenceMs(data, foundUpdate);
}

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
  const s = String(raw || '').trim();
  if (!s) return Number.NaN;
  const explicit = /(?:ch(?:apter|\.)?\s*|#|c)(\d+(?:\.\d+)?)/i.exec(s);
  if (explicit) return Number.parseFloat(explicit[1]);
  const m = /(\d+(?:\.\d+)?)/.exec(s);
  return m ? Number.parseFloat(m[1]) : Number.NaN;
}

function extractLatestChaptersFromFeedXml(xml) {
  const out = new Map();
  if (!xml || typeof xml !== 'string') return out;
  const linkRe = /<link>\s*(https?:\/\/mangakatana\.com\/manga\/([^/"?<\s]+)\/c([^/"?<\s]+))\s*<\/link>/gi;
  let match;
  while ((match = linkRe.exec(xml)) !== null) {
    const slug = (match[2] || '').trim();
    const chId = (match[3] || '').trim();
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
      data: {
        type: 'manga_update',
        slug: u.slug,
        ...(u.chapterId ? { chapterId: String(u.chapterId) } : {}),
      },
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
  const isKatanaHost = (u) => {
    const host = u.hostname.toLowerCase();
    return host === 'mangakatana.com' || host === 'www.mangakatana.com';
  };
  // Prefer structured RSS feed first; fall back to homepage HTML only if the feed returns nothing.
  try {
    const feedResp = await fetchFn(MANGA_FEED_URL, {
      headers: {
        'User-Agent': 'Everglow/1.0 (+https://everglow-1c6db.web.app)',
        Accept: 'application/rss+xml,application/xml,text/xml',
      },
      signal: AbortSignal.timeout(10000),
      httpsOnly: true,
      isAllowedUrl: isKatanaHost,
    });
    if (feedResp.ok) {
      const xml = await common.readLimitedText(feedResp.body, 1024 * 1024);
      const fromFeed = extractLatestChaptersFromFeedXml(xml);
      if (fromFeed.size > 0) return fromFeed;
    }
  } catch {
    // fall back to homepage HTML below
  }

  const upstream = await fetchFn(MANGA_HOME_URL, {
    headers: {
      'User-Agent': 'Everglow/1.0 (+https://everglow-1c6db.web.app)',
      Accept: 'text/html,application/xhtml+xml',
    },
    signal: AbortSignal.timeout(12000),
    httpsOnly: true,
    isAllowedUrl: isKatanaHost,
  });
  if (!upstream.ok) return new Map();
  const html = await common.readLimitedText(upstream.body, 1500 * 1024);
  return extractLatestChaptersFromHomeHtml(html);
}

async function fetchMangaDexLatestChapter(slug, fetchFn = common.fetchPublicUrl) {
  if (!slug || !slug.startsWith('md-')) return null;
  const uuid = slug.slice(3).trim();
  if (!/^[0-9a-f-]{16,64}$/i.test(uuid)) return null;
  const url = `${MANGADEX_API_BASE}/manga/${encodeURIComponent(uuid)}/feed?translatedLanguage[]=en&order[chapter]=desc&limit=1`;
  try {
    const upstream = await fetchFn(url, {
      headers: {
        'User-Agent': 'Everglow/1.0 (+https://everglow-1c6db.web.app)',
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(10000),
      httpsOnly: true,
      isAllowedUrl: (u) => u.hostname.toLowerCase() === 'api.mangadex.org',
    });
    if (!upstream.ok) return null;
    const text = await common.readLimitedText(upstream.body, 256 * 1024);
    const json = JSON.parse(text);
    const item = Array.isArray(json?.data) ? json.data[0] : null;
    const chRaw = item?.attributes?.chapter;
    if (!item?.id || chRaw == null || String(chRaw).trim() === '') return null;
    const chapterNum = String(chRaw).trim();
    const num = parseChapterNumber(chapterNum);
    return {
      chapterId: `md-${item.id}`,
      chapterNum,
      num: Number.isFinite(num) ? num : -1,
    };
  } catch {
    return null;
  }
}

async function fetchKatanaSeriesLatestChapter(slug, fetchFn = common.fetchPublicUrl) {
  if (!slug || slug.startsWith('md-') || !/^[\w.-]{1,160}$/.test(slug)) return null;
  try {
    const upstream = await fetchFn(`${MANGA_HOME_URL}manga/${encodeURIComponent(slug)}`, {
      headers: {
        'User-Agent': 'Everglow/1.0 (+https://everglow-1c6db.web.app)',
        Accept: 'text/html',
      },
      signal: AbortSignal.timeout(10000),
      httpsOnly: true,
      isAllowedUrl: (u) => {
        const host = u.hostname.toLowerCase();
        return host === 'mangakatana.com' || host === 'www.mangakatana.com';
      },
    });
    if (!upstream.ok) return null;
    const html = await common.readLimitedText(upstream.body, 1500 * 1024);
    return extractLatestChaptersFromHomeHtml(html).get(slug) || null;
  } catch {
    return null;
  }
}

async function runMangaUpdateCheck({
  db = common.getDb(),
  sendPush = sendFCMToUser,
  fetchLatest = fetchMangaHomeLatest,
  fetchMangaDexLatest = fetchMangaDexLatestChapter,
  fetchKatanaSeriesLatest = fetchKatanaSeriesLatestChapter,
  now = new Date(),
} = {}) {
  const lookupDeadline = Date.now() + SERIES_LOOKUP_BUDGET_MS;
  const latestBySlug = await fetchLatest();
  const hasKatanaMap = latestBySlug && latestBySlug.size > 0;

  const { hour, dayKey } = manilaHourAndDay(now);
  let sentCount = 0;

  for (const uid of COUPLE_USERS) {
    const prefsRef = db.collection('katana_bookmarks').doc(`${uid}|__prefs__`);
    const prefsSnap = await prefsRef.get();
    const prefs = prefsSnap.exists ? (prefsSnap.data() || {}) : {};

    if (prefs.chapterAlertsEnabled === false) continue;
    const quietEnabled = Boolean(prefs.alertPrefs?.quietHours ?? prefs.quietHoursEnabled);
    const quietStart =
      typeof prefs.alertPrefs?.quietStartHour === 'number'
        ? prefs.alertPrefs.quietStartHour
        : typeof prefs.quietStartHour === 'number'
          ? prefs.quietStartHour
          : 22;
    const quietEnd =
      typeof prefs.alertPrefs?.quietEndHour === 'number'
        ? prefs.alertPrefs.quietEndHour
        : typeof prefs.quietEndHour === 'number'
          ? prefs.quietEndHour
          : 8;
    if (quietEnabled && isWithinQuietHours(hour, quietStart, quietEnd)) continue;

    const mode = prefs.alertPrefs?.frequency === 'daily' || prefs.chapterAlertsMode === 'daily_digest'
      ? 'daily_digest'
      : 'instant';
    if (mode === 'daily_digest' && prefs.lastPushDigestDay === dayKey) continue;

    const skipCompleted = prefs.alertPrefs?.skipCompleted !== false;
    const skipOnHold = Boolean(prefs.alertPrefs?.skipOnHold);

    const snap = await db
      .collection('katana_bookmarks')
      .where('userName', '==', uid)
      .where('bookmarked', '==', true)
      .get();

    const freshUpdates = [];
    const checkedSeriesUpdates = [];
    const nowMs = now.getTime();
    // Sort stalest lastCheckedAt first so cursor-based round-robin covers every followed series across runs.
    const sortedDocs = [...snap.docs].sort((a, b) => {
      const ta = Number(a.data()?.lastCheckedAt || 0);
      const tb = Number(b.data()?.lastCheckedAt || 0);
      return ta - tb;
    });
    let mdLookups = 0;
    let katanaLookups = 0;
    for (const docSnap of sortedDocs) {
      if (docSnap.id.endsWith('|__prefs__')) continue;
      const data = docSnap.data() || {};
      if (data.notifyOnUpdate === false) continue;
      const readingStatus = typeof data.libraryStatus === 'string'
        ? data.libraryStatus
        : typeof data.readingStatus === 'string'
          ? data.readingStatus
          : '';
      if (skipCompleted && (readingStatus === 'completed' || readingStatus === 'dropped')) continue;
      if (skipOnHold && readingStatus === 'on_hold') continue;

      const slug = typeof data.slug === 'string' ? data.slug.trim() : '';
      if (!slug) continue;

      let latest = hasKatanaMap ? latestBySlug.get(slug) : null;
      let fromSeriesPage = false;
      // Mihon Smart Updates: only probe an individual series page when its predicted cadence window is due.
      const dueForDirectProbe = typeof data.nextCheckAt !== 'number' || nowMs >= data.nextCheckAt;
      const canLookup = dueForDirectProbe && Date.now() < lookupDeadline;
      if (!latest && canLookup && slug.startsWith('md-') && mdLookups < MANGADEX_PER_RUN_CAP) {
        mdLookups += 1;
        latest = await fetchMangaDexLatest(slug);
        checkedSeriesUpdates.push({ ref: docSnap.ref, data });
        fromSeriesPage = true;
      } else if (!latest && canLookup && !slug.startsWith('md-') && katanaLookups < KATANA_SERIES_PER_RUN_CAP) {
        // Followed series that missed the latest-updates feed: read its own page (stalest first).
        katanaLookups += 1;
        latest = await fetchKatanaSeriesLatest(slug);
        checkedSeriesUpdates.push({ ref: docSnap.ref, data });
        fromSeriesPage = true;
      }
      if (!latest) continue;

      const prevNotified = parseChapterNumber(data.lastNotifiedChapter || data.latestChapterNum || '');
      if (fromSeriesPage && !Number.isFinite(prevNotified) && !data.lastNotifiedChapter) {
        // First look at this series: remember where it is instead of announcing an old chapter.
        const cadenceMs = computePredictedCadenceMs(data, false);
        await docSnap.ref.set(
          {
            latestChapterNum: latest.chapterNum,
            lastCheckedAt: nowMs,
            nextCheckAt: nowMs + cadenceMs,
            cadenceHours: Math.round(cadenceMs / HOUR_MS),
          },
          { merge: true },
        );
        continue;
      }
      if (Number.isFinite(latest.num) && Number.isFinite(prevNotified) && latest.num <= prevNotified) {
        continue;
      }
      if (!Number.isFinite(latest.num) && (data.lastNotifiedChapter === latest.chapterNum)) {
        continue;
      }

      freshUpdates.push({
        ref: docSnap.ref,
        data,
        slug,
        title: data.title || slug,
        chapterNum: latest.chapterNum,
        chapterId: latest.chapterId,
      });
    }

    const freshRefs = new Set(freshUpdates.map((u) => u.ref));
    if (checkedSeriesUpdates.length > 0) {
      await Promise.all(
        checkedSeriesUpdates
          .filter((item) => !freshRefs.has(item.ref))
          .map(({ ref, data }) => {
            const idleCount = (typeof data.consecutiveIdleChecks === 'number' ? data.consecutiveIdleChecks : 0) + 1;
            const cadenceMs = computePredictedCadenceMs({ ...data, consecutiveIdleChecks: idleCount }, false);
            return ref.set(
              {
                lastCheckedAt: nowMs,
                nextCheckAt: nowMs + cadenceMs,
                cadenceHours: Math.round(cadenceMs / HOUR_MS),
                consecutiveIdleChecks: idleCount,
              },
              { merge: true },
            );
          }),
      );
    }

    if (freshUpdates.length === 0) {
      await prefsRef.set({ lastUpdateCheckAt: nowMs }, { merge: true });
      continue;
    }

    const payload = buildMangaPushPayload(freshUpdates);
    if (!payload) continue;

    const delivered = await sendPush(uid, payload);
    if (!delivered) continue;

    sentCount += 1;
    await Promise.all(
      freshUpdates.map((u) => {
        const prevNotifiedAt = typeof u.data?.lastNotifiedAt === 'number' ? u.data.lastNotifiedAt : undefined;
        const observedInterval =
          prevNotifiedAt && nowMs > prevNotifiedAt
            ? Math.min(MAX_CADENCE_MS, Math.max(MIN_CADENCE_MS, nowMs - prevNotifiedAt))
            : undefined;
        const cadenceMs = computePredictedCadenceMs(
          {
            ...u.data,
            ...(observedInterval ? { releaseIntervalMs: observedInterval } : {}),
            consecutiveIdleChecks: 0,
          },
          true,
        );
        return u.ref.set(
          {
            lastNotifiedChapter: u.chapterNum,
            latestChapterNum: u.chapterNum,
            ...(prevNotifiedAt ? { prevNotifiedAt } : {}),
            ...(observedInterval ? { releaseIntervalMs: observedInterval } : {}),
            lastNotifiedAt: nowMs,
            lastCheckedAt: nowMs,
            nextCheckAt: nowMs + cadenceMs,
            cadenceHours: Math.round(cadenceMs / HOUR_MS),
            consecutiveIdleChecks: 0,
          },
          { merge: true },
        );
      }),
    );
    await prefsRef.set(
      mode === 'daily_digest'
        ? { lastPushDigestDay: dayKey, lastUpdateCheckAt: nowMs }
        : { lastUpdateCheckAt: nowMs },
      { merge: true },
    );
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
  fetchKatanaSeriesLatestChapter,
  extractLatestChaptersFromFeedXml,
  extractLatestChaptersFromHomeHtml,
  buildMangaPushPayload,
  isWithinQuietHours,
  parseChapterNumber,
  computePredictedCadenceMs,
  computeNextCheckAt,
};
