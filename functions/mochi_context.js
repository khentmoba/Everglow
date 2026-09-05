'use strict';

// Mochi feature-context builders (Firestore reads for the AI system prompt).
// Moved verbatim from index.js; index.js requires back only what it calls.
const {
  getDb,
  getAdmin,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
} = require('./common.js');

async function buildContextForFeature(feature, callerUid, userMessage = '') {
  try {
    const queryHint = feature === 'assistant'
      ? `:${Buffer.from(userMessage || '').toString('base64').slice(0, 48)}`
      : '';
    const cacheKey = `${feature}:${callerUid || 'anon'}${queryHint}`;
    const cached = _contextCache.get(cacheKey);
    if (cached && (Date.now() - cached.ts) < 300000) {
      return cached.value;
    }

    let result;
    switch (feature) {
      case 'assistant': {
        const ctxPromises = [
          ['proactive', getProactiveContext()],
          ['daily', getDailyDigest()],
          ['mood', getMoodContext()],
          ['watchlist', getWatchContext()],
          ['books', getBooksContext()],
          ['starlight', getStarlightContext()],
          ['chat', getRecentChatContext()],
          ['music', getMusicContext()],
          ['garden', getGardenContext()],
          ['canvas', getCanvasContext()],
          ['play_zone', getPlayZoneContext()],
          ['relationship', getRelationshipStats()],
          ['activity', getRecentActivity()],
          ['sessions', getSessionHistoryContext()],
          ['calendar', getCalendarContext()],
          ['journal', getJournalContext()],
          ['bucket', getBucketContext()],
          ['travel', getTravelContext()],
          ['wellness', getWellnessContext()],
          ['budget', getBudgetContext()],
        ];
        const resolved = await Promise.all(
          ctxPromises.map(async ([key, promise]) => ({
            key,
            value: await promise,
          }))
        );
        const selected = selectContextBlocks(resolved, userMessage || '', 8);
        result = selected.map(b => b.value).filter(Boolean).join('\n\n');
        break;
      }
      case 'guardian':
        const mood = await getMoodContext();
        result = mood;
        break;
      case 'recommendations': {
        const [watch, books, trending, nowPlaying, upcoming] = await Promise.all([
          getWatchContext(),
          getBooksContext(),
          getTrendingMovies(),
          getNowPlayingMovies(),
          getUpcomingMovies(),
        ]);
        result = [watch, books, trending, nowPlaying, upcoming].filter(p => p).join('\n\n');
        break;
      }
      case 'date_ideas': {
        const [mood2, starlight] = await Promise.all([
          getMoodContext(),
          getStarlightContext(),
        ]);
        result = [mood2, starlight].filter(p => p).join('\n\n');
        break;
      }
      default:
        result = '';
        break;
    }

    _contextCache.set(cacheKey, { ts: Date.now(), value: result });
    return result;
  } catch (e) {
    console.warn('buildContextForFeature error:', e.message);
    return '';
  }
}

function getProactiveContext() {
  const now = new Date();
  const parts = [];

  // Anniversary (Feb 14)
  const anniv = new Date(now.getFullYear(), 1, 14);
  const annivDays = Math.ceil((anniv - now) / (1000 * 60 * 60 * 24));
  if (annivDays > 0) parts.push(`💕 Anniversary in ${annivDays} days (Feb 14)`);
  else if (annivDays === 0) parts.push(`💕 ANNIVERSARY TODAY!`);

  // Birthdays
  const khentBday = new Date(now.getFullYear(), 9, 26);
  const clairBday = new Date(now.getFullYear(), 1, 21);
  const toKhent = Math.ceil((khentBday - now) / (1000 * 60 * 60 * 24));
  const toClair = Math.ceil((clairBday - now) / (1000 * 60 * 60 * 24));
  if (toKhent === 0) parts.push('🎂 Dada\'s birthday TODAY!');
  else if (toKhent > 0 && toKhent <= 30) parts.push(`Dada's birthday in ${toKhent} days 🎂`);
  if (toClair === 0) parts.push('🎂 Mama\'s birthday TODAY!');
  else if (toClair > 0 && toClair <= 30) parts.push(`Mama's birthday in ${toClair} days 🎂`);

  if (parts.length === 0) return '';
  return `Today's digest: ${parts.join(' ')}`;
}

async function getDailyDigest() {
  try {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrowStart = new Date(todayStart);
    tomorrowStart.setDate(tomorrowStart.getDate() + 1);

    const db = getDb();
    const snapshot = await db.collection('daily_digest')
      .where('date', '>=', todayStart.toISOString())
      .where('date', '<', tomorrowStart.toISOString())
      .limit(1)
      .get();

    if (snapshot.empty) return '';
    const data = snapshot.docs[0].data();
    return data.summary ? `Daily digest: ${data.summary}` : '';
  } catch (_) { return ''; }
}

async function getMoodContext() {
  try {
    const usernames = ['khentsgdz', 'clairjassen'];
    const moodParts = [];
    for (const username of usernames) {
      const db = getDb();
      const snapshot = await db.collection('moods')
        .where('username', '==', username)
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get();
      if (!snapshot.empty) {
        const moods = snapshot.docs.map(doc => {
          const d = doc.data();
          return `${d.moodEmoji || '😊'} ${d.moodLabel || 'okay'}`;
        }).join(', ');
        moodParts.push(`${username}: ${moods}`);
      }
    }
    return moodParts.length ? `Recent moods:\n${moodParts.join('\n')}` : '';
  } catch (_) { return ''; }
}

async function getWatchContext() {
  try {
    const watchParts = [];
    for (const username of ['khentsgdz', 'clairjassen']) {
      const db = getDb();
      const snapshot = await db.collection('our_cinema')
        .where('userId', '==', username)
        .orderBy('addedAt', 'desc')
        .limit(15)
        .get();
      if (!snapshot.empty) {
        const items = snapshot.docs.map(doc => {
          const d = doc.data();
          return `${d.title || 'Unknown'} (${d.mediaType || 'movie'}) - ${d.status || 'plan to watch'}`;
        }).join('\n');
        watchParts.push(`${username}'s watchlist:\n${items}`);
      }
    }
    return watchParts.length ? watchParts.join('\n\n') : '';
  } catch (_) { return ''; }
}

// TMDB API key — uses Firebase env config, falls back to client-side key for dev
function getTmdbKey() {
  return process.env.TMDB_API_KEY || '';
}

async function getTrendingMovies() {
  const cacheKey = 'trending:movie:week';
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.trending);
  if (cached) return cached;
  try {
    const key = getTmdbKey();
    const res = await fetch(
      `https://api.themoviedb.org/3/trending/movie/week?api_key=${key}`
    );
    if (!res.ok) return '';
    const data = await res.json();
    if (!data.results?.length) return '';
    const movies = data.results.slice(0, 15).map(m =>
      `${m.title} (${(m.release_date || '').slice(0, 4)}) — ${(m.overview || '').slice(0, 200)}`
    ).join('\n');
    const result = `Trending movies this week:\n${movies}`;
    _setExternalCache(cacheKey, result);
    return result;
  } catch (_) { return ''; }
}

async function getNowPlayingMovies() {
  const cacheKey = 'tmdb:now_playing:PH';
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.trending);
  if (cached) return cached;
  try {
    const key = getTmdbKey();
    const res = await fetch(
      `https://api.themoviedb.org/3/movie/now_playing?api_key=${key}&region=PH`
    );
    if (!res.ok) return '';
    const data = await res.json();
    if (!data.results?.length) return '';
    const movies = data.results.slice(0, 12).map(m =>
      `${m.title} (${(m.release_date || '').slice(0, 4)}) — ${(m.overview || '').slice(0, 200)}`
    ).join('\n');
    const result = `Now playing in theaters:\n${movies}`;
    _setExternalCache(cacheKey, result);
    return result;
  } catch (_) { return ''; }
}

async function getUpcomingMovies() {
  const cacheKey = 'tmdb:upcoming:PH';
  const cached = _getExternalCache(cacheKey, _EXTERNAL_CACHE_TTLS.trending);
  if (cached) return cached;
  try {
    const key = getTmdbKey();
    const res = await fetch(
      `https://api.themoviedb.org/3/movie/upcoming?api_key=${key}&region=PH`
    );
    if (!res.ok) return '';
    const data = await res.json();
    if (!data.results?.length) return '';
    const movies = data.results.slice(0, 12).map(m =>
      `${m.title} (${(m.release_date || '').slice(0, 4)}) — ${(m.overview || '').slice(0, 200)}`
    ).join('\n');
    const result = `Coming soon:\n${movies}`;
    _setExternalCache(cacheKey, result);
    return result;
  } catch (_) { return ''; }
}

async function getBooksContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('our_books').limit(20).get();
    if (snapshot.empty) return '';
    const books = snapshot.docs.map(doc => {
      const d = doc.data();
      const readBy = [];
      if (d.khentReadAt) readBy.push('Khent');
      if (d.clairReadAt) readBy.push('Clair');
      const readStr = readBy.length ? ` [read by ${readBy.join(', ')}]` : '';
      return `${d.title || 'Unknown'} by ${d.author || ''} (added by ${d.addedBy || ''})${readStr}`;
    }).join('\n');
    return `Books:\n${books}`;
  } catch (_) { return ''; }
}

async function getStarlightContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('starlight_jar')
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();
    if (snapshot.empty) return '';
    const notes = snapshot.docs.map(doc => {
      const d = doc.data();
      return `- "${d.content || ''}" — ${d.author || ''}`;
    }).join('\n');
    return `Starlight Jar notes (recent):\n${notes}`;
  } catch (_) { return ''; }
}

async function getRecentChatContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('sanctuary_messages')
      .orderBy('timestamp', 'desc')
      .limit(30)
      .get();
    if (snapshot.empty) return '';
    const msgs = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.username || 'user'}: ${d.text || d.content || ''}`;
    }).reverse().join('\n');
    return `Recent sanctuary chat:\n${msgs}`;
  } catch (_) { return ''; }
}

async function getMusicContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('music')
      .orderBy('addedAt', 'desc')
      .limit(25)
      .get();
    if (snapshot.empty) return '';
    const songs = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.title || 'Unknown'} by ${d.artist || 'Unknown'}`;
    }).join('\n');
    return `Recent music:\n${songs}`;
  } catch (_) { return ''; }
}

async function getGardenContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('garden_plants')
      .orderBy('plantedAt', 'desc')
      .limit(20)
      .get();
    if (snapshot.empty) return '';
    const plants = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.name || d.plantName || 'Plant'} - ${d.status || 'growing'} (${d.plantedBy || ''})`;
    }).join('\n');
    return `Garden:\n${plants}`;
  } catch (_) { return ''; }
}

async function getRecentActivity() {
  try {
    const db = getDb();
    const snapshot = await db.collection('recent_activity')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    if (snapshot.empty) return '';
    const activities = snapshot.docs.map(doc => {
      const d = doc.data();
      return `- ${d.description || d.activity || d.text || ''}`;
    }).join('\n');
    return `Recent activity:\n${activities}`;
  } catch (_) { return ''; }
}

async function getCanvasContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('canvas_drawings')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    if (snapshot.empty) return '';
    const drawings = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.title || 'Untitled'} by ${d.drawnBy || d.createdBy || ''}`;
    }).join('\n');
    return `Canvas drawings:\n${drawings}`;
  } catch (_) { return ''; }
}

async function getPlayZoneContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('playzone_scores')
      .orderBy('playedAt', 'desc')
      .limit(12)
      .get();
    if (snapshot.empty) return '';
    const scores = snapshot.docs.map(doc => {
      const d = doc.data();
      return `${d.game || 'Game'}: ${d.score || ''} (${d.player || ''})`;
    }).join('\n');
    return `PlayZone:\n${scores}`;
  } catch (_) { return ''; }
}

async function getRelationshipStats() {
  try {
    const db = getDb();
    const snapshot = await db.collection('relationship_stats')
      .orderBy('updatedAt', 'desc')
      .limit(1)
      .get();
    if (snapshot.empty) return '';
    const d = snapshot.docs[0].data();
    const stats = [];
    if (d.daysTogether) stats.push(`Days together: ${d.daysTogether}`);
    if (d.messagesExchanged) stats.push(`Messages: ${d.messagesExchanged}`);
    return stats.length ? `Relationship:\n${stats.join('\n')}` : '';
  } catch (_) { return ''; }
}

async function getSessionHistoryContext() {
  try {
    const db = getDb();
    const snapshot = await db.collection('ai_memories')
      .doc('shared')
      .collection('sessions')
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();
    if (snapshot.empty) return '';

    const summaries = [];
    const recentSessions = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.hasSummary && data.summary) {
        summaries.push(data.summary);
      } else if (data.messages && data.messages.length > 0) {
        recentSessions.push(data.messages);
      }
    }

    const parts = [];
    if (summaries.length > 0) {
      parts.push(`## Past Session Summaries\n${summaries.slice(0, 25).map((s, i) => `Session ${i + 1}: ${s}`).join('\n')}`);
    }
    if (recentSessions.length > 0) {
      // With 512K context, we can afford richer session history.
      const CHAR_LIMIT = 40_000;
      let totalChars = 0;
      const sessionBlocks = [];
      for (let si = 0; si < Math.min(recentSessions.length, 8); si++) {
        const msgs = recentSessions[si];
        const lines = [];
        for (const m of msgs) {
          const who = m.role === 'user' ? 'User' : 'Mochi';
          const content = (m.content || '').length > 3000
            ? (m.content || '').substring(0, 3000) + '… [truncated]'
            : (m.content || '');
          lines.push(`${who}: ${content}`);
        }
        const block = `--- Session ${si + 1} ---\n${lines.join('\n')}`;
        if (totalChars + block.length > CHAR_LIMIT && sessionBlocks.length > 0) {
          break;
        }
        totalChars += block.length;
        sessionBlocks.push(block);
      }
      if (sessionBlocks.length > 0) {
        parts.push(`## Previous Conversations\n${sessionBlocks.join('\n\n')}`);
      }
    }
    return parts.join('\n\n');
  } catch (_) { return ''; }
}

async function getCalendarContext() {
  try {
    const db = getDb();
    const now = new Date();
    const end = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
    const snap = await db.collection('calendar_events')
      .where('date', '>=', getAdmin().firestore.Timestamp.fromDate(now))
      .where('date', '<=', getAdmin().firestore.Timestamp.fromDate(end))
      .orderBy('date', 'asc').limit(12).get();
    if (snap.empty) return '';
    const lines = snap.docs.map(d => {
      const v = d.data();
      const dt = v.date?.toDate?.()?.toISOString()?.slice(0,10) || '';
      return `${dt} ${v.title || 'Untitled'} (${v.type || 'event'}) ${v.location ? '@'+v.location : ''}`.trim();
    }).join('\n');
    return `Upcoming calendar (14d):\n${lines}`;
  } catch (_) { return ''; }
}

async function getJournalContext() {
  try {
    const db = getDb();
    const snap = await db.collection('journal_entries').orderBy('createdAt','desc').limit(8).get();
    if (snap.empty) return '';
    const lines = snap.docs.map(d => {
      const v = d.data();
      return `${v.title || 'Untitled'} (${v.category||'daily'}) by ${v.author||''} - ${(v.content||'').slice(0,120).replace(/\n/g,' ')}`;
    }).join('\n');
    return `Recent journal:\n${lines}`;
  } catch (_) { return ''; }
}

async function getBucketContext() {
  try {
    const db = getDb();
    const snap = await db.collection('bucket_list').orderBy('createdAt','desc').limit(12).get();
    if (snap.empty) return '';
    const lines = snap.docs.map(d => {
      const v = d.data();
      return `${v.title || ''} [${v.status||'wish'}] ${v.category||''} ${v.dueDate ? '(due '+(v.dueDate.toDate?.()?.toISOString()?.slice(0,10)||'')+')' : ''}`;
    }).join('\n');
    return `Bucket list (recent):\n${lines}`;
  } catch (_) { return ''; }
}

async function getTravelContext() {
  try {
    const db = getDb();
    const snap = await db.collection('travel_trips').orderBy('startDate','asc').limit(6).get();
    if (snap.empty) return '';
    const lines = snap.docs.map(d => {
      const v = d.data();
      const s = v.startDate?.toDate?.()?.toISOString()?.slice(0,10) || '';
      const e = v.endDate?.toDate?.()?.toISOString()?.slice(0,10) || '';
      return `${v.title || 'Trip'} ${s}-${e} (${v.status||'planning'})`;
    }).join('\n');
    return `Trips:\n${lines}`;
  } catch (_) { return ''; }
}

async function getWellnessContext() {
  try {
    const db = getDb();
    const snap = await db.collection('habits').where('isActive','==',true).limit(10).get();
    if (snap.empty) return '';
    const lines = snap.docs.map(d => {
      const v = d.data();
      return `${v.title||''} (${v.category||'health'}) streak:${v.streak||0}`;
    }).join('\n');
    return `Active habits:\n${lines}`;
  } catch (_) { return ''; }
}

async function getBudgetContext() {
  try {
    const db = getDb();
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const snap = await db.collection('budget_transactions')
      .where('date','>=', getAdmin().firestore.Timestamp.fromDate(start))
      .orderBy('date','desc').limit(10).get();
    if (snap.empty) return '';
    const lines = snap.docs.map(d => {
      const v = d.data();
      return `${v.title||v.category||'Expense'} ${v.amount||''} ${v.currency||'PHP'} by ${v.paidBy||''}`;
    }).join('\n');
    return `Recent spending (this month):\n${lines}`;
  } catch (_) { return ''; }
}

module.exports = {
  buildContextForFeature,
  getTmdbKey,
};
