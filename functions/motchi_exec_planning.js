'use strict';

/* Motchi planning tool executors — moved verbatim from
 * motchi_chat.js executeTool() (mechanical split, no behavior change).
 * Each executor is (ctx, args) => JSON string. Shared services
 * ride on ctx (see motchi_exec_tools.js createToolCtx).
 */

const { parseReminderDate } = require('./motchi_core.js');

async function exec_create_reminder(ctx, args) {
    // W1-A2: Parse remind_at into a Firestore Timestamp for the
    // scheduled checker. ISO 8601 plus today/tonight/tomorrow, in-N-units,
    // and next week — clock times read as Philippine wall time.
    let remindAtTs = null;
    const rawRemind = String(args.remind_at || '').trim();
    if (rawRemind) {
      const parsed = parseReminderDate(rawRemind);
      if (parsed) remindAtTs = ctx.admin.firestore.Timestamp.fromDate(parsed);
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

async function exec_update_calendar_event(ctx, args) {
  const id = String(args.id || '').trim();
  const title = String(args.title || '').trim();
  if (!id && !title) return JSON.stringify({ error: 'Provide id or title' });
  let ref = id ? ctx.db.collection('calendar_events').doc(id) : null;
  if (!ref) {
    const snap = await ctx.db.collection('calendar_events').limit(30).get();
    const qLower = title.toLowerCase();
    const matches = snap.docs.filter((d) => {
      const t = (d.data().title || '').toLowerCase();
      return t.includes(qLower) || qLower.includes(t);
    });
    if (matches.length === 0) return JSON.stringify({ error: `No calendar event found for "${title}"` });
    if (matches.length > 1) {
      const cands = matches.slice(0, 5).map((d) => ({ id: d.id, title: d.data().title || '' }));
      return JSON.stringify({ needs_confirmation: true, message: `Which event? Re-call update_calendar_event with one of these ids: ${cands.map((c) => c.title).join(', ')}.`, candidates: cands });
    }
    ref = matches[0].ref;
  }
  const snap = await ref.get();
  if (!snap.exists) return JSON.stringify({ error: `Calendar event ${id} not found` });
  const update = {};
  if (args.new_title !== undefined) {
    const t = String(args.new_title).trim();
    if (!t) return JSON.stringify({ error: 'new_title must not be empty' });
    update.title = t;
  }
  if (args.description !== undefined) update.description = String(args.description);
  const rawDate = args.date || args.start_date;
  if (rawDate !== undefined) {
    const d = new Date(String(rawDate).trim());
    if (Number.isNaN(d.getTime())) return JSON.stringify({ error: `Invalid date: ${rawDate}` });
    update.date = ctx.admin.firestore.Timestamp.fromDate(d);
  }
  if (args.end_date !== undefined) {
    const d = new Date(String(args.end_date).trim());
    if (Number.isNaN(d.getTime())) return JSON.stringify({ error: `Invalid end_date: ${args.end_date}` });
    update.endDate = ctx.admin.firestore.Timestamp.fromDate(d);
  }
  if (args.location !== undefined) update.location = String(args.location) || null;
  if (args.type !== undefined) {
    const type = String(args.type);
    if (!['dateNight','anniversary','reminder','custom'].includes(type)) {
      return JSON.stringify({ error: `Invalid type: ${type}` });
    }
    update.type = type;
  }
  if (args.is_all_day !== undefined) update.isAllDay = !!args.is_all_day;
  if (Object.keys(update).length === 0) return JSON.stringify({ error: 'Nothing to update — provide a field to change' });
  await ref.update(update);
  return JSON.stringify({ success: true, id: ref.id, title: update.title || snap.data()?.title || '' });
}

async function exec_delete_calendar_event(ctx, args) {
  const id = String(args.id || '').trim();
  const title = String(args.title || '').trim();
  if (!id && !title) return JSON.stringify({ error: 'Provide id or title' });
  let ref = id ? ctx.db.collection('calendar_events').doc(id) : null;
  if (!ref) {
    const snap = await ctx.db.collection('calendar_events').limit(30).get();
    const qLower = title.toLowerCase();
    const matches = snap.docs.filter((d) => {
      const t = (d.data().title || '').toLowerCase();
      return t.includes(qLower) || qLower.includes(t);
    });
    if (matches.length === 0) return JSON.stringify({ error: `No calendar event found for "${title}"` });
    if (matches.length > 1) {
      const cands = matches.slice(0, 5).map((d) => ({ id: d.id, title: d.data().title || '' }));
      return JSON.stringify({ needs_confirmation: true, message: `Which event? Re-call delete_calendar_event with one of these ids: ${cands.map((c) => c.title).join(', ')}.`, candidates: cands });
    }
    ref = matches[0].ref;
  }
  const snap = await ref.get();
  if (!snap.exists) return JSON.stringify({ error: `Calendar event ${id} not found` });
  const eventTitle = snap.data()?.title || '';
  if (!args.confirm) {
    return JSON.stringify({ needs_confirmation: true, message: `Delete the event "${eventTitle}"? Re-call delete_calendar_event with confirm:true to proceed.`, id: ref.id, title: eventTitle });
  }
  await ref.delete();
  return JSON.stringify({ success: true, id: ref.id, title: eventTitle });
}

async function exec_complete_bucket_item(ctx, args) {
  const id = String(args.id || '').trim();
  const title = String(args.title || '').trim();
  if (!id && !title) return JSON.stringify({ error: 'Provide id or title' });
  let ref = id ? ctx.db.collection('bucket_list').doc(id) : null;
  if (!ref) {
    const snap = await ctx.db.collection('bucket_list').limit(30).get();
    const qLower = title.toLowerCase();
    const matches = snap.docs.filter((d) => {
      const t = (d.data().title || '').toLowerCase();
      return t.includes(qLower) || qLower.includes(t);
    });
    if (matches.length === 0) return JSON.stringify({ error: `No bucket item found for "${title}"` });
    if (matches.length > 1) {
      const cands = matches.slice(0, 5).map((d) => ({ id: d.id, title: d.data().title || '' }));
      return JSON.stringify({ needs_confirmation: true, message: `Which one did you finish? Re-call complete_bucket_item with one of these ids: ${cands.map((c) => c.title).join(', ')}.`, candidates: cands });
    }
    ref = matches[0].ref;
  }
  const snap = await ref.get();
  if (!snap.exists) return JSON.stringify({ error: `Bucket item ${id} not found` });
  if (snap.data()?.status === 'completed') {
    return JSON.stringify({ success: true, id: ref.id, already_completed: true });
  }
  await ref.update({
    status: 'completed',
    completedAt: ctx.admin.firestore.Timestamp.now(),
    completedBy: ctx.callerUid,
  });
  return JSON.stringify({ success: true, id: ref.id, title: snap.data()?.title || '' });
}

async function exec_delete_bucket_item(ctx, args) {
  const id = String(args.id || '').trim();
  const title = String(args.title || '').trim();
  if (!id && !title) return JSON.stringify({ error: 'Provide id or title' });
  let ref = id ? ctx.db.collection('bucket_list').doc(id) : null;
  if (!ref) {
    const snap = await ctx.db.collection('bucket_list').limit(30).get();
    const qLower = title.toLowerCase();
    const matches = snap.docs.filter((d) => {
      const t = (d.data().title || '').toLowerCase();
      return t.includes(qLower) || qLower.includes(t);
    });
    if (matches.length === 0) return JSON.stringify({ error: `No bucket item found for "${title}"` });
    if (matches.length > 1) {
      const cands = matches.slice(0, 5).map((d) => ({ id: d.id, title: d.data().title || '' }));
      return JSON.stringify({ needs_confirmation: true, message: `Which one? Re-call delete_bucket_item with one of these ids: ${cands.map((c) => c.title).join(', ')}.`, candidates: cands });
    }
    ref = matches[0].ref;
  }
  const snap = await ref.get();
  if (!snap.exists) return JSON.stringify({ error: `Bucket item ${id} not found` });
  const itemTitle = snap.data()?.title || '';
  if (!args.confirm) {
    return JSON.stringify({ needs_confirmation: true, message: `Delete "${itemTitle}" from the bucket list? Re-call delete_bucket_item with confirm:true to proceed.`, id: ref.id, title: itemTitle });
  }
  await ref.delete();
  return JSON.stringify({ success: true, id: ref.id, title: itemTitle });
}

async function _lookupByIdOrTitle(ctx, collection, id, title, label) {
  const cleanId = String(id || '').trim();
  const cleanTitle = String(title || '').trim();
  if (!cleanId && !cleanTitle) return { error: 'Provide id or title' };
  let ref = cleanId ? ctx.db.collection(collection).doc(cleanId) : null;
  if (!ref) {
    const snap = await ctx.db.collection(collection).limit(30).get();
    const qLower = cleanTitle.toLowerCase();
    const matches = snap.docs.filter((d) => {
      const t = (d.data().title || '').toLowerCase();
      return t.includes(qLower) || qLower.includes(t);
    });
    if (matches.length === 0) return { error: `No ${label} found for "${cleanTitle}"` };
    if (matches.length > 1) {
      const cands = matches.slice(0, 5).map((d) => ({ id: d.id, title: d.data().title || '' }));
      return { needsConfirmation: true, candidates: cands };
    }
    ref = matches[0].ref;
  }
  const snap = await ref.get();
  if (!snap.exists) return { error: `${label} ${cleanId} not found` };
  return { ref, snap };
}

async function exec_edit_bucket_item(ctx, args) {
  const found = await _lookupByIdOrTitle(ctx, 'bucket_list', args.id, args.title, 'Bucket item');
  if (found.error) return JSON.stringify({ error: found.error });
  if (found.needsConfirmation) {
    return JSON.stringify({ needs_confirmation: true, message: `Which item? Re-call edit_bucket_item with one of these ids: ${found.candidates.map((c) => c.title).join(', ')}.`, candidates: found.candidates });
  }
  const update = {};
  if (args.new_title !== undefined) {
    const t = String(args.new_title).trim();
    if (!t) return JSON.stringify({ error: 'new_title must not be empty' });
    update.title = t;
  }
  if (args.description !== undefined) update.description = String(args.description);
  if (args.category !== undefined) {
    const c = String(args.category);
    if (!['travel','experience','food','adventure','milestone','other'].includes(c)) {
      return JSON.stringify({ error: `Invalid category: ${c}` });
    }
    update.category = c;
  }
  if (args.priority !== undefined) {
    const p = String(args.priority);
    if (!['low','medium','high','urgent'].includes(p)) {
      return JSON.stringify({ error: `Invalid priority: ${p}` });
    }
    update.priority = p;
  }
  if (args.due_date !== undefined) {
    const d = new Date(String(args.due_date).trim());
    if (Number.isNaN(d.getTime())) return JSON.stringify({ error: `Invalid due_date: ${args.due_date}` });
    update.dueDate = ctx.admin.firestore.Timestamp.fromDate(d);
  }
  if (Object.keys(update).length === 0) return JSON.stringify({ error: 'Nothing to update — provide a field to change' });
  await found.ref.update(update);
  return JSON.stringify({ success: true, id: found.ref.id, title: update.title || found.snap.data()?.title || '' });
}

async function exec_edit_habit(ctx, args) {
  const found = await _lookupByIdOrTitle(ctx, 'habits', args.id, args.title, 'Habit');
  if (found.error) return JSON.stringify({ error: found.error });
  if (found.needsConfirmation) {
    return JSON.stringify({ needs_confirmation: true, message: `Which habit? Re-call edit_habit with one of these ids: ${found.candidates.map((c) => c.title).join(', ')}.`, candidates: found.candidates });
  }
  const update = {};
  if (args.new_title !== undefined) {
    const t = String(args.new_title).trim();
    if (!t) return JSON.stringify({ error: 'new_title must not be empty' });
    update.title = t;
  }
  if (args.description !== undefined) update.description = String(args.description);
  if (args.category !== undefined) {
    const c = String(args.category);
    if (!['health','fitness','mindfulness','learning','social','other'].includes(c)) {
      return JSON.stringify({ error: `Invalid category: ${c}` });
    }
    update.category = c;
  }
  if (args.frequency !== undefined) {
    const f = String(args.frequency);
    if (!['daily','weekly','custom'].includes(f)) {
      return JSON.stringify({ error: `Invalid frequency: ${f}` });
    }
    update.frequency = f;
  }
  if (Object.keys(update).length === 0) return JSON.stringify({ error: 'Nothing to update — provide a field to change' });
  await found.ref.update(update);
  return JSON.stringify({ success: true, id: found.ref.id, title: update.title || found.snap.data()?.title || '' });
}

async function exec_edit_reminder(ctx, args) {
  const found = await _lookupByIdOrTitle(ctx, 'reminders', args.id, args.title, 'Reminder');
  if (found.error) return JSON.stringify({ error: found.error });
  if (found.needsConfirmation) {
    return JSON.stringify({ needs_confirmation: true, message: `Which reminder? Re-call edit_reminder with one of these ids: ${found.candidates.map((c) => c.title).join(', ')}.`, candidates: found.candidates });
  }
  const update = {};
  if (args.new_title !== undefined) {
    const t = String(args.new_title).trim();
    if (!t) return JSON.stringify({ error: 'new_title must not be empty' });
    update.title = t;
  }
  if (args.note !== undefined) update.note = String(args.note) || null;
  if (args.remind_at !== undefined) {
    const parsed = parseReminderDate(String(args.remind_at));
    if (!parsed) return JSON.stringify({ error: `Could not understand time: ${args.remind_at}` });
    update.remindAt = String(args.remind_at);
    update.remindAtTs = ctx.admin.firestore.Timestamp.fromDate(parsed);
    update.fired = false;
  }
  if (Object.keys(update).length === 0) return JSON.stringify({ error: 'Nothing to update — provide a field to change' });
  await found.ref.update(update);
  return JSON.stringify({ success: true, id: found.ref.id, title: update.title || found.snap.data()?.title || '' });
}

async function exec_edit_trip(ctx, args) {
  const found = await _lookupByIdOrTitle(ctx, 'travel_trips', args.id, args.title, 'Trip');
  if (found.error) return JSON.stringify({ error: found.error });
  if (found.needsConfirmation) {
    return JSON.stringify({ needs_confirmation: true, message: `Which trip? Re-call edit_trip with one of these ids: ${found.candidates.map((c) => c.title).join(', ')}.`, candidates: found.candidates });
  }
  const update = {};
  if (args.new_title !== undefined) {
    const t = String(args.new_title).trim();
    if (!t) return JSON.stringify({ error: 'new_title must not be empty' });
    update.title = t;
  }
  if (args.description !== undefined) update.description = String(args.description);
  if (args.start_date !== undefined) {
    const d = new Date(String(args.start_date).trim());
    if (Number.isNaN(d.getTime())) return JSON.stringify({ error: `Invalid start_date: ${args.start_date}` });
    update.startDate = ctx.admin.firestore.Timestamp.fromDate(d);
  }
  if (args.end_date !== undefined) {
    const d = new Date(String(args.end_date).trim());
    if (Number.isNaN(d.getTime())) return JSON.stringify({ error: `Invalid end_date: ${args.end_date}` });
    update.endDate = ctx.admin.firestore.Timestamp.fromDate(d);
  }
  if (args.budget !== undefined) update.budgetEstimate = Number(args.budget) || 0;
  if (Object.keys(update).length === 0) return JSON.stringify({ error: 'Nothing to update — provide a field to change' });
  if (update.title !== undefined || update.description !== undefined) {
    const data = found.snap.data() || {};
    const title = update.title !== undefined ? update.title : (data.title || '');
    const desc = update.description !== undefined ? update.description : (data.description || '');
    update.searchKey = `${title.toLowerCase()} ${desc.toLowerCase()}`;
  }
  await found.ref.update(update);
  return JSON.stringify({ success: true, id: found.ref.id, title: update.title || found.snap.data()?.title || '' });
}

module.exports = {
  exec_create_reminder,
  exec_list_reminders,
  exec_cancel_reminder,
  exec_add_calendar_event,
  exec_get_calendar_events,
  exec_update_calendar_event,
  exec_delete_calendar_event,
  exec_add_bucket_item,
  exec_get_bucket_list,
  exec_complete_bucket_item,
  exec_delete_bucket_item,
  exec_edit_bucket_item,
  exec_edit_habit,
  exec_edit_reminder,
  exec_edit_trip,
  exec_add_trip,
  exec_add_trip_pin,
  exec_get_trips,
  exec_log_habit,
  exec_complete_habit,
  exec_plan_date_night,
  exec_get_date_ideas,
  exec_get_weather,
};
