'use strict';

/* Motchi planning tool executors — moved verbatim from
 * motchi_chat.js executeTool() (mechanical split, no behavior change).
 * Each executor is (ctx, args) => JSON string. Shared services
 * ride on ctx (see motchi_exec_tools.js createToolCtx).
 */

async function exec_create_reminder(ctx, args) {
    // W1-A2: Parse remind_at into a Firestore Timestamp for the
    // scheduled checker. Accepts ISO 8601 or common relatives.
    let remindAtTs = null;
    const rawRemind = String(args.remind_at || '').trim();
    if (rawRemind) {
      const parsed = new Date(rawRemind);
      if (!Number.isNaN(parsed.getTime())) {
        remindAtTs = ctx.admin.firestore.Timestamp.fromDate(parsed);
      } else if (/tomorrow/i.test(rawRemind)) {
        const d = new Date(Date.now() + 24 * 60 * 60 * 1000);
        const timeMatch = rawRemind.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
        if (timeMatch) {
          let h = parseInt(timeMatch[1], 10);
          const m = timeMatch[2] ? parseInt(timeMatch[2], 10) : 0;
          const ap = (timeMatch[3] || '').toLowerCase();
          if (ap === 'pm' && h < 12) h += 12;
          if (ap === 'am' && h === 12) h = 0;
          d.setHours(h, m, 0, 0);
        }
        remindAtTs = ctx.admin.firestore.Timestamp.fromDate(d);
      }
    }
    await ctx.db.collection('reminders').add({
      title: args.title,
      note: args.note || null,
      remindAt: args.remind_at,
      remindAtTs,
      fired: false,
      createdBy: ctx.callerUid,
      createdAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    return JSON.stringify({ success: true, title: args.title, remindAt: args.remind_at, scheduled: !!remindAtTs });
}

async function exec_add_calendar_event(ctx, args) {
    const title = String(args.title || '').trim();
    if (!title) return JSON.stringify({ error: 'title required' });
    const dateStr = String(args.date || args.start_date || '').trim();
    if (!dateStr) return JSON.stringify({ error: 'date required' });
    let date = new Date(dateStr);
    if (Number.isNaN(date.getTime())) return JSON.stringify({ error: `Invalid date: ${dateStr}` });
    let endDate = null;
    if (args.end_date) {
      const ed = new Date(String(args.end_date).trim());
      if (!Number.isNaN(ed.getTime())) endDate = ed;
    }
    const type = ['dateNight','anniversary','reminder','custom'].includes(String(args.type||'')) ? String(args.type) : 'custom';
    const data = {
      title,
      description: String(args.description||''),
      date: ctx.admin.firestore.Timestamp.fromDate(date),
      type,
      createdBy: ctx.callerUid,
      color: null,
      recurring: 'none',
      location: args.location ? String(args.location) : null,
      attendees: [],
      isAllDay: !!args.is_all_day,
    };
    if (endDate) data.endDate = ctx.admin.firestore.Timestamp.fromDate(endDate);
    const ref = await ctx.db.collection('calendar_events').add(data);
    return JSON.stringify({ success: true, id: ref.id, title, date: date.toISOString() });
}

async function exec_get_calendar_events(ctx, args) {
    const days = Math.min(Math.max(Number(args.days)||14,1),60);
    const limit = Math.min(Math.max(Number(args.limit)||10,1),20);
    const now = new Date();
    const end = new Date(now.getTime()+days*24*60*60*1000);
    const snap = await ctx.db.collection('calendar_events')
      .where('date','>=', ctx.admin.firestore.Timestamp.fromDate(now))
      .where('date','<=', ctx.admin.firestore.Timestamp.fromDate(end))
      .orderBy('date','asc').limit(limit).get();
    if (snap.empty) return JSON.stringify({ events: [], count: 0 });
    const events = snap.docs.map(d => {
      const v = d.data();
      return { id: d.id, title: v.title||'', date: v.date?.toDate?.()?.toISOString()||null, type: v.type||'custom', location: v.location||null };
    });
    return JSON.stringify({ events, count: events.length });
}

async function exec_add_bucket_item(ctx, args) {
    const title = String(args.title||'').trim();
    if (!title) return JSON.stringify({ error: 'title required' });
    const cat = ['travel','experience','food','adventure','milestone','other'].includes(String(args.category||'')) ? String(args.category) : 'other';
    const pri = ['low','medium','high','urgent'].includes(String(args.priority||'')) ? String(args.priority) : 'medium';
    let dueDate = null;
    if (args.due_date) {
      const d = new Date(String(args.due_date));
      if (!Number.isNaN(d.getTime())) dueDate = d;
    }
    const data = {
      title,
      description: String(args.description||''),
      category: cat,
      status: 'wish',
      createdBy: ctx.callerUid,
      createdAt: ctx.admin.firestore.Timestamp.now(),
      notes: '',
      priority: pri,
    };
    if (dueDate) data.dueDate = ctx.admin.firestore.Timestamp.fromDate(dueDate);
    const ref = await ctx.db.collection('bucket_list').add(data);
    return JSON.stringify({ success: true, id: ref.id, title, category: cat });
}

async function exec_get_bucket_list(ctx, args) {
    const limit = Math.min(Math.max(Number(args.limit)||10,1),20);
    const status = String(args.status||'all').toLowerCase();
    let q = ctx.db.collection('bucket_list').orderBy('createdAt','desc').limit(limit);
    if (['wish','planned','completed'].includes(status)) q = ctx.db.collection('bucket_list').where('status','==',status).orderBy('createdAt','desc').limit(limit);
    const snap = await q.get();
    if (snap.empty) return JSON.stringify({ items: [], count: 0 });
    const items = snap.docs.map(d => {
      const v=d.data();
      return { id: d.id, title: v.title||'', status: v.status||'wish', category: v.category||'other', priority: v.priority||'medium' };
    });
    return JSON.stringify({ items, count: items.length });
}

async function exec_add_trip(ctx, args) {
    const title = String(args.title||'').trim();
    if (!title) return JSON.stringify({ error: 'title required' });
    const sd = new Date(String(args.start_date||''));
    const ed = new Date(String(args.end_date||''));
    if (Number.isNaN(sd.getTime()) || Number.isNaN(ed.getTime())) return JSON.stringify({ error: 'Invalid start_date or end_date' });
    const data = {
      title,
      description: String(args.description||''),
      coverUrl: '',
      startDate: ctx.admin.firestore.Timestamp.fromDate(sd),
      endDate: ctx.admin.firestore.Timestamp.fromDate(ed),
      status: 'planning',
      createdBy: ctx.callerUid,
      createdAt: ctx.admin.firestore.Timestamp.now(),
      budgetEstimate: Number(args.budget)||0,
      currency: 'PHP',
      memberIds: ['khentsgdz','clairjassen'],
      searchKey: `${title.toLowerCase()} ${(args.description||'').toLowerCase()}`,
    };
    const ref = await ctx.db.collection('travel_trips').add(data);
    return JSON.stringify({ success: true, id: ref.id, title, start: sd.toISOString().slice(0,10), end: ed.toISOString().slice(0,10) });
}

async function exec_add_trip_pin(ctx, args) {
    const title = String(args.title||'').trim();
    if (!title) return JSON.stringify({ error: 'title required' });
    let tripId = String(args.trip_id||'').trim();
    if (!tripId && args.trip_title) {
      const tTitle = String(args.trip_title).trim().toLowerCase();
      const q = await ctx.db.collection('travel_trips').where('title','==', String(args.trip_title).trim()).limit(1).get();
      if (!q.empty) tripId = q.docs[0].id;
      else {
        const all = await ctx.db.collection('travel_trips').limit(20).get();
        const found = all.docs.find(d => (d.data().title||'').toLowerCase().includes(tTitle));
        if (found) tripId = found.id;
      }
    }
    if (!tripId) return JSON.stringify({ error: 'trip_id or trip_title required and not found' });
    // Verify trip exists
    const tripSnap = await ctx.db.collection('travel_trips').doc(tripId).get();
    if (!tripSnap.exists) return JSON.stringify({ error: `Trip ${tripId} not found` });
    const lat = Number(args.lat)||0;
    const lng = Number(args.lng)||0;
    const cat = ['stay','eat','sight','activity','transit'].includes(String(args.category||'')) ? String(args.category) : 'sight';
    // Determine order
    const existing = await ctx.db.collection('travel_pins').where('tripId','==',tripId).get();
    const order = existing.size;
    const pin = {
      tripId,
      title,
      note: String(args.note||''),
      lat,
      lng,
      category: cat,
      order,
      createdBy: ctx.callerUid,
    };
    const ref = await ctx.db.collection('travel_pins').add(pin);
    return JSON.stringify({ success: true, id: ref.id, tripId, title });
}

async function exec_get_trips(ctx, args) {
    const limit = Math.min(Math.max(Number(args.limit)||5,1),10);
    const snap = await ctx.db.collection('travel_trips').orderBy('startDate','asc').limit(limit).get();
    if (snap.empty) return JSON.stringify({ trips: [], count: 0 });
    const trips = snap.docs.map(d => {
      const v=d.data();
      return { id: d.id, title: v.title||'', start: v.startDate?.toDate?.()?.toISOString()?.slice(0,10)||null, end: v.endDate?.toDate?.()?.toISOString()?.slice(0,10)||null, status: v.status||'planning' };
    });
    return JSON.stringify({ trips, count: trips.length });
}

async function exec_log_habit(ctx, args) {
    const title = String(args.title||'').trim();
    if (!title) return JSON.stringify({ error: 'title required' });
    const cat = ['health','fitness','mindfulness','learning','social','other'].includes(String(args.category||'')) ? String(args.category) : 'health';
    const freq = ['daily','weekly','custom'].includes(String(args.frequency||'')) ? String(args.frequency) : 'daily';
    // Check duplicate
    const existingH = await ctx.db.collection('habits').where('title','==',title).limit(1).get();
    if (!existingH.empty) return JSON.stringify({ success: false, error: `Habit "${title}" already exists`, id: existingH.docs[0].id });
    const data = {
      title,
      description: String(args.description||''),
      category: cat,
      frequency: freq,
      createdBy: ctx.callerUid,
      createdAt: ctx.admin.firestore.Timestamp.now(),
      completedDates: [],
      streak: 0,
      longestStreak: 0,
      isActive: true,
    };
    const ref = await ctx.db.collection('habits').add(data);
    return JSON.stringify({ success: true, id: ref.id, title });
}

async function exec_complete_habit(ctx, args) {
    const title = String(args.title||'').trim();
    const hid = String(args.habit_id||'').trim();
    let docRef = null;
    let docSnap = null;
    if (hid) {
      docRef = ctx.db.collection('habits').doc(hid);
      docSnap = await docRef.get();
    } else {
      const q = await ctx.db.collection('habits').where('title','==',title).limit(1).get();
      if (q.empty) {
        // try case-insensitive
        const all = await ctx.db.collection('habits').limit(50).get();
        const found = all.docs.find(d => (d.data().title||'').toLowerCase() === title.toLowerCase());
        if (found) { docRef = found.ref; docSnap = found; } else return JSON.stringify({ error: `Habit "${title}" not found` });
      } else { docRef = q.docs[0].ref; docSnap = q.docs[0]; }
    }
    if (!docSnap.exists) return JSON.stringify({ error: 'Habit not found' });
    const data = docSnap.data();
    const now = new Date();
    // PHT day basis so after-midnight completions count right.
    const todayKey = ctx.phtDateString(now.getTime());
    const completedDates = (data.completedDates||[]).map(d => {
      if (d.toDate) return ctx.phtDateString(d.toDate().getTime());
      const parsed = new Date(String(d));
      return Number.isNaN(parsed.getTime()) ? String(d).slice(0,10) : ctx.phtDateString(parsed.getTime());
    });
    if (completedDates.includes(todayKey)) return JSON.stringify({ success: false, error: 'Already completed today', streak: data.streak||0 });
    // Compute streak - naive increment
    const newStreak = (data.streak||0)+1;
    const longest = Math.max(newStreak, data.longestStreak||0);
    await docRef.update({
      completedDates: ctx.admin.firestore.FieldValue.arrayUnion(ctx.admin.firestore.Timestamp.fromDate(now)),
      streak: newStreak,
      longestStreak: longest,
    });
    return JSON.stringify({ success: true, title: data.title, streak: newStreak, longestStreak: longest });
}

async function exec_plan_date_night(ctx, args) {
    const location = (args.location || 'Cabadbaran').trim();
    const count = Math.min(args.count || 3, 5);
    const pKey = `weather:${location.toLowerCase()}`;
    const cachedPlanWeather = ctx.cacheGet(pKey, ctx.cacheTTLs.weather);
    let weatherText = cachedPlanWeather || null;
    const [ideaSnap, watchSnap, fetchedWeather] = await Promise.all([
      ctx.db.collection('date_ideas').limit(100).get(),
      ctx.db.collection('our_cinema').limit(5).get(),
      weatherText ? Promise.resolve(null) : fetch(`https://wttr.in/${encodeURIComponent(location)}?format=%C+%t+%h+%w`, {
        headers: { 'User-Agent': 'curl/8.5.0' },
      }),
    ]);
    if (!weatherText && fetchedWeather) {
      weatherText = (await fetchedWeather.text()).trim();
      ctx.cacheSet(pKey, weatherText);
    }
    weatherText = weatherText || 'Weather unavailable';
    const allIdeas = ideaSnap.docs
      .map(d => d.data().title || d.data().name || '')
      .filter(Boolean);
    const shuffled = [...allIdeas].sort(() => Math.random() - 0.5);
    const watchlist = watchSnap.docs
      .map(d => d.data().title || '')
      .filter(Boolean)
      .slice(0, 2);
    return JSON.stringify({
      location,
      weather: weatherText || 'Weather unavailable',
      ideas: shuffled.slice(0, count),
      watchlist,
      suggestion: [
        `Start with ${shuffled[0] || 'a cozy evening'}`,
        watchlist.length
          ? `then finish the night with "${watchlist[0]}"`
          : 'then just talk until late',
      ].join(', '),
    });
}

async function exec_get_date_ideas(ctx, args) {
    const count = Math.min(args.count || 3, 10);
    const snapshot = await ctx.db.collection('date_ideas').limit(100).get();
    const allIdeas = snapshot.docs.map(d => d.data().title || d.data().name || '').filter(Boolean);
    // Random selection
    const shuffled = allIdeas.sort(() => Math.random() - 0.5);
    return JSON.stringify({ ideas: shuffled.slice(0, count) });
}

async function exec_get_weather(ctx, args) {
    const wKey = `weather:${String(args.location || '').toLowerCase().trim()}`;
    const cachedWeather = ctx.cacheGet(wKey, ctx.cacheTTLs.weather);
    if (cachedWeather) return JSON.stringify({ location: args.location, weather: cachedWeather });
    const weatherRes = await fetch(
      `https://wttr.in/${encodeURIComponent(args.location)}?format=%C+%t+%h+%w`,
      { headers: { 'User-Agent': 'curl/8.5.0' } }
    );
    const weatherText = await weatherRes.text();
    const trimmed = weatherText.trim();
    ctx.cacheSet(wKey, trimmed);
    return JSON.stringify({ location: args.location, weather: trimmed });
}

async function exec_list_reminders(ctx, args) {
  // Equality-only query (no composite index); due-soonest sort in code.
  const snap = await ctx.db.collection('reminders').where('fired', '==', false).limit(20).get();
  const items = snap.docs.map((d) => {
    const data = d.data();
    const ts = data.remindAtTs;
    return {
      id: d.id,
      title: data.title || '',
      note: (data.note || '').slice(0, 180),
      remind_at: data.remindAt || null,
      created_by: data.createdBy || '',
      _due: (ts && typeof ts.toDate === 'function') ? ts.toDate().getTime() : null,
    };
  }).sort((a, b) => (a._due ?? Infinity) - (b._due ?? Infinity));
  return JSON.stringify({
    count: items.length,
    reminders: items.map(({ _due, ...r }) => r),
  });
}

async function exec_cancel_reminder(ctx, args) {
  const id = String(args.id || args.reminder_id || '').trim();
  const title = String(args.title || '').trim();
  if (!id && !title) return JSON.stringify({ error: 'Provide id or title' });
  const stamp = () => ({
    fired: true,
    cancelled: true,
    cancelledAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
  });
  if (id) {
    const ref = ctx.db.collection('reminders').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return JSON.stringify({ error: `Reminder ${id} not found` });
    if (snap.data()?.cancelled) {
      return JSON.stringify({ success: true, id, already_cancelled: true });
    }
    if (snap.data()?.fired) {
      return JSON.stringify({ error: 'That reminder already fired' });
    }
    await ref.update(stamp());
    return JSON.stringify({ success: true, id, title: snap.data()?.title || '' });
  }
  // Title match (case-insensitive substring, like the watchlist flow).
  const snap = await ctx.db.collection('reminders').where('fired', '==', false).limit(50).get();
  const qLower = title.toLowerCase();
  const matches = snap.docs.filter((d) => {
    const t = (d.data().title || '').toLowerCase();
    return t.includes(qLower) || qLower.includes(t);
  });
  if (matches.length === 0) return JSON.stringify({ error: `No pending reminder found for "${title}"` });
  const preview = matches.slice(0, 3).map((d) => ({ id: d.id, title: d.data().title || '' }));
  if (!args.confirm) {
    return JSON.stringify({
      needs_confirmation: true,
      message: `Cancel ${preview.length > 1 ? 'these reminders' : 'this reminder'}? ${preview.map((p) => p.title).join(', ')} — re-call cancel_reminder with confirm:true to proceed.`,
      preview,
      count: preview.length,
    });
  }
  for (const doc of matches.slice(0, 3)) {
    await doc.ref.update(stamp());
  }
  return JSON.stringify({ success: true, cancelled: preview.map((p) => p.title), count: preview.length });
}

module.exports = {
  exec_create_reminder,
  exec_list_reminders,
  exec_cancel_reminder,
  exec_add_calendar_event,
  exec_get_calendar_events,
  exec_add_bucket_item,
  exec_get_bucket_list,
  exec_add_trip,
  exec_add_trip_pin,
  exec_get_trips,
  exec_log_habit,
  exec_complete_habit,
  exec_plan_date_night,
  exec_get_date_ideas,
  exec_get_weather,
};
