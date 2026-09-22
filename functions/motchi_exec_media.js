'use strict';

/* Motchi media tool executors — moved verbatim from
 * motchi_chat.js executeTool() (mechanical split, no behavior change).
 * Each executor is (ctx, args) => JSON string. Shared services
 * ride on ctx (see motchi_exec_tools.js createToolCtx).
 */

async function exec_add_to_watchlist(ctx, args) {
    // W2-A3: Support tmdb_id disambiguation + candidate return
    const mediaType = args.media_type || 'movie';
    const providedId = args.tmdb_id || args.tmdbId || args.tmdbId === 0 ? Number(args.tmdb_id || args.tmdbId) : null;
    if (providedId) {
      // Direct fetch by ID for disambiguated choice
      const detailKey = `tmdb:detail:${mediaType}:${providedId}`;
      let detail;
      const cachedDetail = ctx.cacheGet(detailKey, ctx.cacheTTLs.tmdb);
      if (cachedDetail) {
        detail = cachedDetail;
      } else {
        const detailRes = await fetch(
          `https://api.themoviedb.org/3/${mediaType === 'tv' ? 'tv' : 'movie'}/${providedId}?api_key=${ctx.getTmdbKey()}`
        );
        if (!detailRes.ok) return JSON.stringify({ error: `TMDB ID ${providedId} not found for ${mediaType}` });
        detail = await detailRes.json();
        ctx.cacheSet(detailKey, detail);
      }
      const title = detail.title || detail.name || String(args.title || '').trim();
      if (!title) return JSON.stringify({ error: 'No title found for that TMDB ID' });
      await ctx.db.collection('our_cinema').add({
        tmdbId: providedId,
        title,
        mediaType,
        posterPath: detail.poster_path ? `https://image.tmdb.org/t/p/w500${detail.poster_path}` : null,
        addedBy: ctx.callerUid,
        addedAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
        status: 'plan_to_watch',
      });
      return JSON.stringify({ success: true, title, tmdbId: providedId });
    }
    const queryRaw = String(args.title || '').trim();
    if (!queryRaw) return JSON.stringify({ error: 'No title provided' });
    const tmdbCacheKey = `tmdb:add:${mediaType}:${queryRaw.toLowerCase()}`;
    let tmdbData;
    const cachedTmdb = ctx.cacheGet(tmdbCacheKey, ctx.cacheTTLs.tmdb);
    if (cachedTmdb) {
      tmdbData = cachedTmdb;
    } else {
      const tmdbRes = await fetch(
        `https://api.themoviedb.org/3/search/${mediaType === 'multi' ? 'multi' : mediaType}?query=${encodeURIComponent(queryRaw)}&api_key=${ctx.getTmdbKey()}`
      );
      tmdbData = await tmdbRes.json();
      ctx.cacheSet(tmdbCacheKey, tmdbData);
    }
    const results = (tmdbData.results || []).filter(r => r.title || r.name);
    if (results.length === 0) return JSON.stringify({ error: `No results found for "${queryRaw}"` });
    // W2-A3 disambiguation: if query not exact and multiple candidates share substring, ask to confirm
    const qLower = queryRaw.toLowerCase();
    const exact = results.find(r => (r.title || r.name || '').toLowerCase() === qLower);
    const substringMatches = results.filter(r => {
      const t = (r.title || r.name || '').toLowerCase();
      return t.includes(qLower) || qLower.includes(t);
    }).slice(0, 3);
    const isAmbiguous = !exact && substringMatches.length >= 2;
    if (isAmbiguous) {
      const candidates = substringMatches.map(r => ({
        tmdbId: r.id,
        title: r.title || r.name,
        year: (r.release_date || r.first_air_date || '').slice(0, 4),
        mediaType: r.media_type || mediaType,
        overview: (r.overview || '').slice(0, 180),
        popularity: r.popularity || 0,
      }));
      return JSON.stringify({
        needs_confirmation: true,
        message: `Found multiple matches for "${queryRaw}". Ask the user which one they mean and re-call add_to_watchlist with the chosen tmdb_id.`,
        candidates,
      });
    }
    const result = results[0];
    await ctx.db.collection('our_cinema').add({
      tmdbId: result.id,
      title: result.title || result.name,
      mediaType: result.media_type || mediaType,
      posterPath: result.poster_path ? `https://image.tmdb.org/t/p/w500${result.poster_path}` : null,
      addedBy: ctx.callerUid,
      addedAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
      status: 'plan_to_watch',
    });
    return JSON.stringify({ success: true, title: result.title || result.name, tmdbId: result.id });
}

async function exec_search_movies(ctx, args) {
    const mediaType = args.media_type || 'multi';
    const endpoint = mediaType === 'multi' ? 'multi' : args.media_type;
    const cacheKey = `tmdb:search:${endpoint}:${String(args.query || '').toLowerCase().trim()}`;
    let tmdbData;
    const cached = ctx.cacheGet(cacheKey, ctx.cacheTTLs.tmdb);
    if (cached) {
      tmdbData = cached;
    } else {
      const tmdbRes = await fetch(
        `https://api.themoviedb.org/3/search/${endpoint}?query=${encodeURIComponent(args.query)}&api_key=${ctx.getTmdbKey()}`
      );
      tmdbData = await tmdbRes.json();
      ctx.cacheSet(cacheKey, tmdbData);
    }
    const results = (tmdbData.results || [])              .slice(0, 8).map(r => ({
      id: r.id,
      title: r.title || r.name,
      year: (r.release_date || r.first_air_date || '').slice(0, 4),
      mediaType: r.media_type || args.media_type || 'movie',
      overview: (r.overview || '').slice(0, 400),
    }));
    return JSON.stringify({ results });
}

async function exec_get_watchlist(ctx, args) {
    const limit = Math.min(args.limit || 15, 40);
    const parts = [];
    for (const username of ['khentsgdz', 'clairjassen']) {
      const snapshot = await ctx.db.collection('our_cinema')
        .where('userId', '==', username)
        .orderBy('addedAt', 'desc')
        .limit(limit)
        .get();
      const items = snapshot.docs.map(d => {
        const x = d.data();
        return `${x.title || 'Unknown'} (${x.mediaType || 'movie'}) - ${x.status || 'plan to watch'}`;
      });
      if (items.length) parts.push(`${username}'s watchlist:\n${items.join('\n')}`);
    }
    return JSON.stringify({ watchlist: parts.length ? parts.join('\n\n') : 'Watchlist is empty' });
}

async function exec_mark_watchlist_item_watched(ctx, args) {
    const title = (args.title || '').trim();
    if (!title) return JSON.stringify({ error: 'No title provided' });
    const snapshot = await ctx.db.collection('our_cinema').get();
    const matches = snapshot.docs.filter(d => {
      const t = (d.data().title || '').toLowerCase();
      return t.includes(title.toLowerCase()) || title.toLowerCase().includes(t);
    });
    if (matches.length === 0) {
      return JSON.stringify({ error: `No watchlist item found for "${title}"` });
    }
    const batch = ctx.db.batch();
    for (const doc of matches) {
      batch.update(doc.ref, {
        status: 'watched',
        watchedBy: ctx.callerUid,
        watchedAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return JSON.stringify({
      success: true,
      title: matches[0].data().title || title,
      updated: matches.length,
    });
}

async function exec_remove_from_watchlist(ctx, args) {
    const title = String(args.title || '').trim();
    const tid = args.tmdb_id ? Number(args.tmdb_id) : (args.tmdbId ? Number(args.tmdbId) : null);
    if (!title && !tid) return JSON.stringify({ error: 'Provide title or tmdb_id' });
    let snap;
    if (tid) {
      snap = await ctx.db.collection('our_cinema').where('tmdbId', '==', tid).limit(5).get();
    } else {
      snap = await ctx.db.collection('our_cinema').get();
    }
    let matches = snap.docs;
    if (!tid) {
      const qLower = title.toLowerCase();
      matches = snap.docs.filter(d => {
        const t = (d.data().title || '').toLowerCase();
        return t.includes(qLower) || qLower.includes(t);
      });
    }
    if (matches.length === 0) return JSON.stringify({ error: `No watchlist item found for "${title || tid}"` });
    const preview = matches.slice(0, 3).map(d => d.data().title || '');
    if (!args.confirm) {
      return JSON.stringify({ needs_confirmation: true, message: `Remove from watchlist? ${preview.join(', ')} — re-call remove_from_watchlist with confirm:true to proceed.`, preview, count: preview.length });
    }
    const batch = ctx.db.batch();
    for (const doc of matches.slice(0, 3)) batch.delete(doc.ref);
    await batch.commit();
    return JSON.stringify({ success: true, removed: preview, count: preview.length });
}

async function exec_search_anime(ctx, args) {
    const aKey = `anime:search:${String(args.query || '').toLowerCase().trim()}`;
    let animeData;
    const cachedAnime = ctx.cacheGet(aKey, ctx.cacheTTLs.anime);
    if (cachedAnime) {
      animeData = cachedAnime;
    } else {
      const animeRes = await fetch(
        `https://api.jikan.moe/v4/anime?q=${encodeURIComponent(args.query)}&limit=5&sfw=true`
      );
      animeData = await animeRes.json();
      ctx.cacheSet(aKey, animeData);
    }
    const anime = (animeData.data || []).slice(0, 5).map(a => ({
      title: a.title,
      titleEnglish: a.title_english || null,
      episodes: a.episodes || null,
      score: a.score || null,
      status: a.status || null,
      synopsis: (a.synopsis || '').slice(0, 300),
      genres: (a.genres || []).map(g => g.name),
      malId: a.mal_id || null,
    }));
    return JSON.stringify({ results: anime });
}

async function exec_search_books(ctx, args) {
    const bKey = `books:search:${String(args.query || '').toLowerCase().trim()}`;
    let searchData;
    const cachedBooks = ctx.cacheGet(bKey, ctx.cacheTTLs.books);
    if (cachedBooks) {
      searchData = cachedBooks;
    } else {
      const searchRes = await fetch(
        `https://openlibrary.org/search.json?q=${encodeURIComponent(args.query)}&limit=5&fields=key,title,author_name,first_publish_year,isbn,cover_i`
      );
      searchData = await searchRes.json();
      ctx.cacheSet(bKey, searchData);
    }
    const books = (searchData.docs || []).slice(0, 5).map(b => ({
      title: b.title,
      authors: (b.author_name || []).slice(0, 2).join(', '),
      year: b.first_publish_year || null,
      coverId: b.cover_i || null,
      openLibraryKey: b.key || null,
    }));
    return JSON.stringify({ results: books });
}

async function exec_add_book_to_our_books(ctx, args) {
    const queryRaw = String(args.query || '').trim();
    if (!queryRaw) return JSON.stringify({ error: 'No query provided' });
    const providedKey = args.open_library_key || args.openLibraryKey || null;
    const abKey = `books:add:${queryRaw.toLowerCase()}`;
    let searchData;
    const cachedAb = ctx.cacheGet(abKey, ctx.cacheTTLs.books);
    if (cachedAb) {
      searchData = cachedAb;
    } else {
      const searchRes = await fetch(
        `https://openlibrary.org/search.json?q=${encodeURIComponent(queryRaw)}&limit=5&fields=key,title,author_name,first_publish_year,isbn,cover_i`
      );
      searchData = await searchRes.json();
      ctx.cacheSet(abKey, searchData);
    }
    const docs = (searchData.docs || []).filter(d => d.title);
    if (docs.length === 0) return JSON.stringify({ error: `No book found for "${queryRaw}"` });
    let book;
    if (providedKey) {
      const normKey = String(providedKey).trim();
      book = docs.find(d => d.key === normKey) || docs[0];
    } else {
      // W2-A3 disambiguation: if multiple substring matches and no exact, return candidates
      const qLower = queryRaw.toLowerCase();
      const exact = docs.find(d => (d.title || '').toLowerCase() === qLower);
      const subMatches = docs.filter(d => {
        const t = (d.title || '').toLowerCase();
        return t.includes(qLower) || qLower.includes(t);
      }).slice(0, 3);
      const isAmbiguous = !exact && subMatches.length >= 2;
      if (isAmbiguous) {
        const candidates = subMatches.map(b => ({
          openLibraryKey: b.key,
          title: b.title,
          authors: (b.author_name || []).slice(0, 2).join(', '),
          year: b.first_publish_year || null,
          coverId: b.cover_i || null,
        }));
        return JSON.stringify({
          needs_confirmation: true,
          message: `Found multiple books for "${queryRaw}". Ask the user which one they mean and re-call with the chosen open_library_key.`,
          candidates,
        });
      }
      book = docs[0];
    }
    if (!book) return JSON.stringify({ error: `No book found for "${queryRaw}"` });
    const title = book.title || 'Unknown';
    const author = (book.author_name || []).slice(0, 2).join(', ');
    await ctx.db.collection('our_books').add({
      title,
      author,
      coverUrl: book.cover_i ? `https://covers.openlibrary.org/b/id/${book.cover_i}-M.jpg` : '',
      year: book.first_publish_year ? String(book.first_publish_year) : '',
      workKey: book.key || '',
      addedBy: ctx.callerUid,
      addedAt: new Date().toISOString(),
    });
    return JSON.stringify({ success: true, title, author, openLibraryKey: book.key || null });
}

async function exec_update_book_progress(ctx, args) {
    const title = (args.title || '').trim();
    const progress = Math.min(Math.max(Number(args.progress) || 0, 0), 100);
    if (!title) return JSON.stringify({ error: 'No title provided' });
    const snapshot = await ctx.db.collection('our_books').get();
    const matches = snapshot.docs.filter(d => {
      const t = (d.data().title || '').toLowerCase();
      return t.includes(title.toLowerCase()) || title.toLowerCase().includes(t);
    });
    if (matches.length === 0) {
      return JSON.stringify({ error: `No book found for "${title}"` });
    }
    const field = ctx.callerUid === 'khentsgdz' ? 'khentReadAt' : 'clairReadAt';
    const readFlag = progress >= 100
      ? ctx.admin.firestore.FieldValue.serverTimestamp()
      : null;
    const batch = ctx.db.batch();
    for (const doc of matches.slice(0, 3)) {
      batch.update(doc.ref, {
        progress: progress,
        [field]: readFlag,
        lastUpdatedBy: ctx.callerUid,
        lastUpdatedAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return JSON.stringify({
      success: true,
      title: matches[0].data().title || title,
      progress,
      read: progress >= 100,
    });
}

async function exec_search_spotify(ctx, args) {
    const q = String(args.query || args.track || '').trim();
    const artist = String(args.artist || '').trim();
    const track = String(args.track || '').trim();
    const query = q || (artist && track ? `${artist} ${track}` : '') || artist || track;
    if (!query) return JSON.stringify({ error: 'No query provided' });
    const sKey = `spotify:search:${query.toLowerCase()}`;
    let cached = ctx.cacheGet(sKey, 10 * 60 * 1000);
    if (cached) return JSON.stringify(cached);
    const token = await ctx.getSpotifyAppToken();
    if (!token) return JSON.stringify({ error: 'Spotify not configured' });
    try {
      const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '5', market: 'US' }).toString();
      const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(10000) });
      if (!r.ok) return JSON.stringify({ error: `Spotify search failed ${r.status}` });
      const data = await r.json();
      const items = data.tracks && data.tracks.items;
      if (!Array.isArray(items) || items.length === 0) return JSON.stringify({ tracks: [], count: 0 });
      const tracks = items.slice(0, 5).map(t => ({
        trackId: t.id,
        trackName: t.name,
        artistName: (t.artists && t.artists[0] && t.artists[0].name) || '',
        albumName: (t.album && t.album.name) || '',
        imageUrl: (t.album && t.album.images && t.album.images[0] && t.album.images[0].url) || null,
        spotifyUrl: 'https://open.spotify.com/track/' + t.id,
      }));
      const result = { tracks, count: tracks.length };
      ctx.cacheSet(sKey, result);
      return JSON.stringify(result);
    } catch (e) {
      return JSON.stringify({ error: e.message });
    }
}

module.exports = {
  exec_add_to_watchlist,
  exec_search_movies,
  exec_get_watchlist,
  exec_mark_watchlist_item_watched,
  exec_remove_from_watchlist,
  exec_search_anime,
  exec_search_books,
  exec_add_book_to_our_books,
  exec_update_book_progress,
  exec_search_spotify,
};
