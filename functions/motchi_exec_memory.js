'use strict';

/* Motchi memory tool executors — moved verbatim from
 * motchi_chat.js executeTool() (mechanical split, no behavior change).
 * Each executor is (ctx, args) => JSON string. Shared services
 * ride on ctx (see motchi_exec_tools.js createToolCtx).
 */

async function exec_remember_fact(ctx, args) {
    const fact = (args.fact || '').trim();
    if (!fact) return JSON.stringify({ error: 'No fact provided' });
    const parsed = parseFactStructure(fact);
    const emb = await getEmbedding(fact).catch(() => null);
    await ctx.db.collection('ai_memories').doc('shared').collection('facts').add({
      fact,
      category: args.category || 'fact',
      subject: args.subject || parsed.subject || null,
      relation: args.relation || parsed.relation || null,
      object: args.object || parsed.object || null,
      occurredAt: args.occurred_at || args.occurredAt || null,
      addedBy: ctx.callerUid || 'motchi',
      createdAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
      confidence: 1.0,
      accessCount: 0,
      lastAccessed: null,
      pinned: false,
      source: ctx.callerUid || 'motchi',
      embedding: emb, // W4-C9 scaffold
    });
    return JSON.stringify({
      success: true,
      fact,
      subject: args.subject || parsed.subject,
      relation: args.relation || parsed.relation,
      object: args.object || parsed.object,
    });
}

async function exec_read_memories(ctx, args) {
    const limit = Math.min(args.limit || 20, 50);
    let query = ctx.db.collection('ai_memories').doc('shared').collection('facts')
      .orderBy('createdAt', 'desc')
      .limit(150);
    const snapshot = await query.get();
    let facts = snapshot.docs.map(d => {
      const data = d.data();
      return {
        id: d.id,
        fact: data.fact || '',
        category: data.category || 'fact',
        subject: data.subject || null,
        relation: data.relation || null,
        object: data.object || null,
        occurredAt: data.occurredAt?.toDate?.()?.toISOString() || null,
        pinned: data.pinned === true,
      };
    }).filter(f => f.fact);
    if (args.category) {
      facts = facts.filter(f => f.category === args.category);
    }
    if (args.query) {
      const queryLower = String(args.query).toLowerCase();
      facts = rankMemories(facts, queryLower, limit);
    } else {
      facts = facts.slice(0, limit);
    }
    return JSON.stringify({ memories: facts, count: facts.length });
}

async function exec_pin_memory(ctx, args) {
    const mid = String(args.memory_id || '').trim();
    if (!mid) return JSON.stringify({ error: 'memory_id required' });
    const pinned = !!args.pinned;
    const ref = ctx.db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
    const snap = await ref.get();
    if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
    await ref.update({ pinned, lastAccessed: ctx.admin.firestore.FieldValue.serverTimestamp() });
    return JSON.stringify({ success: true, memory_id: mid, pinned });
}

async function exec_delete_memory(ctx, args) {
    const mid = String(args.memory_id || '').trim();
    if (!mid) return JSON.stringify({ error: 'memory_id required' });
    const ref = ctx.db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
    const snap = await ref.get();
    if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
    const factText = snap.data()?.fact || '';
    if (!args.confirm) {
      return JSON.stringify({ needs_confirmation: true, message: `Delete this memory? "${factText.slice(0,180)}" — re-call delete_memory with confirm:true to proceed.`, memory_id: mid, fact: factText });
    }
    // Soft-delete to trash for undo (retain 7 days)
    try {
      await ctx.db.collection('ai_memories_trash').add({
        originalId: mid,
        fact: factText,
        category: snap.data()?.category || 'fact',
        deletedBy: ctx.callerUid,
        deletedAt: ctx.admin.firestore.FieldValue.serverTimestamp(),
        originalData: snap.data(),
      });
    } catch (_) {}
    await ref.delete();
    return JSON.stringify({ success: true, memory_id: mid, fact: factText, undo_hint: 'Use undo if needed within 7 days' });
}

async function exec_edit_memory(ctx, args) {
    const mid = String(args.memory_id || '').trim();
    const fact = String(args.fact || '').trim();
    if (!mid || !fact) return JSON.stringify({ error: 'memory_id and fact required' });
    if (fact.length > 500) return JSON.stringify({ error: 'Fact too long (max 500)' });
    const ref = ctx.db.collection('ai_memories').doc('shared').collection('facts').doc(mid);
    const snap = await ref.get();
    if (!snap.exists) return JSON.stringify({ error: `Memory ${mid} not found` });
    const parsed = parseFactStructure(fact);
    const update = {
      fact,
      subject: parsed.subject || null,
      relation: parsed.relation || null,
      object: parsed.object || null,
      lastAccessed: ctx.admin.firestore.FieldValue.serverTimestamp(),
    };
    if (args.category) update.category = String(args.category).trim().toLowerCase();
    await ref.update(update);
    return JSON.stringify({ success: true, memory_id: mid, fact, category: update.category || snap.data()?.category || 'fact' });
}

async function exec_save_to_starlight_jar(ctx, args) {
    await ctx.db.collection('starlight_jar').add({
      content: args.note,
      author: ctx.callerUid,
      timestamp: ctx.admin.firestore.FieldValue.serverTimestamp(),
      writtenBy: 'Motchi 🍡',
    });
    return JSON.stringify({ success: true });
}

async function exec_read_starlight_jar(ctx, args) {
    const limit = Math.min(args.limit || 10, 25);
    const snapshot = await ctx.db.collection('starlight_jar')
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();
    const notes = snapshot.docs.map(d => {
      const data = d.data();
      return {
        content: (data.content || '').slice(0, 300),
        author: data.author || 'motchi',
        time: data.timestamp?.toDate?.()?.toISOString() || null,
      };
    });
    return JSON.stringify({ notes, count: notes.length });
}

async function exec_create_journal_entry(ctx, args) {
    const title = String(args.title||'').trim();
    const content = String(args.content||'').trim();
    if (!title || !content) return JSON.stringify({ error: 'title and content required' });
    if (content.length > 5000) return JSON.stringify({ error: 'content too long (max 5000)' });
    const cat = ['daily','gratitude','memory','letter','dream','idea'].includes(String(args.category||'')) ? String(args.category) : 'daily';
    const moodVal = String(args.mood||'').trim().toLowerCase();
    const validMoods = ['happy','calm','loved','excited','tired','sad','stressed','neutral'];
    const now = new Date();
    const entry = {
      title,
      content,
      author: ctx.callerUid.toLowerCase(),
      createdAt: ctx.admin.firestore.Timestamp.fromDate(now),
      updatedAt: ctx.admin.firestore.Timestamp.fromDate(now),
      category: cat,
      tags: Array.isArray(args.tags) ? args.tags.map(String).slice(0,10) : [],
      isPinned: false,
      isLocked: false,
      wordCount: content.trim().split(/\s+/).filter(Boolean).length,
      monthDay: `${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`,
      searchKey: `${title.toLowerCase()} ${content.toLowerCase().slice(0,500)}`,
    };
    if (validMoods.includes(moodVal)) entry.mood = moodVal;
    const ref = await ctx.db.collection('journal_entries').add(entry);
    return JSON.stringify({ success: true, id: ref.id, title });
}

async function exec_get_journal_entries(ctx, args) {
    const limit = Math.min(Math.max(Number(args.limit)||5,1),10);
    const cat = String(args.category||'all').toLowerCase();
    let q = ctx.db.collection('journal_entries').orderBy('createdAt','desc').limit(limit);
    if (['daily','gratitude','memory','letter','dream','idea'].includes(cat)) q = ctx.db.collection('journal_entries').where('category','==',cat).orderBy('createdAt','desc').limit(limit);
    const snap = await q.get();
    if (snap.empty) return JSON.stringify({ entries: [], count: 0 });
    const entries = snap.docs.map(d => {
      const v=d.data();
      return { id: d.id, title: v.title||'', category: v.category||'daily', preview: (v.content||'').slice(0,150), author: v.author||'' };
    });
    return JSON.stringify({ entries, count: entries.length, note: 'Call read_journal_entry with entry id to read the full unabridged content.' });
}

async function exec_search_journal_entries(ctx, args) {
    const query = String(args.query || '').trim().toLowerCase();
    const cat = String(args.category || 'all').toLowerCase();
    const author = String(args.author || '').trim().toLowerCase();
    const tag = String(args.tag || '').trim().toLowerCase();
    const limit = Math.min(Math.max(Number(args.limit) || 5, 1), 20);

    let q = ctx.db.collection('journal_entries');
    const validCategories = ['daily', 'gratitude', 'memory', 'letter', 'dream', 'idea'];
    if (validCategories.includes(cat)) {
      q = q.where('category', '==', cat);
    }
    q = q.orderBy('createdAt', 'desc').limit(100);
    const snap = await q.get();
    if (snap.empty) return JSON.stringify({ entries: [], count: 0, query });

    const queryTokens = query ? query.split(/\s+/).filter(Boolean) : [];

    const matched = snap.docs.map((d) => {
      const v = d.data();
      const title = String(v.title || '');
      const content = String(v.content || '');
      const entryAuthor = String(v.author || '').toLowerCase();
      const tags = Array.isArray(v.tags) ? v.tags.map((t) => String(t).toLowerCase()) : [];
      const category = String(v.category || 'daily');
      const mood = v.mood || null;
      const createdAt = v.createdAt?.toDate?.()?.toISOString()?.slice(0, 10) || null;

      if (author && !entryAuthor.includes(author)) return null;
      if (tag && !tags.some((t) => t.includes(tag))) return null;

      let score = 0;
      let snippet = '';

      if (queryTokens.length > 0) {
        const lowerTitle = title.toLowerCase();
        const lowerContent = content.toLowerCase();

        if (lowerTitle.includes(query)) score += 10;
        if (lowerContent.includes(query)) {
          score += 5;
          const idx = lowerContent.indexOf(query);
          const start = Math.max(0, idx - 40);
          const end = Math.min(content.length, idx + query.length + 80);
          snippet = (start > 0 ? '...' : '') + content.slice(start, end).replace(/\n/g, ' ') + (end < content.length ? '...' : '');
        }
        if (tags.some((t) => t.includes(query))) score += 7;

        for (const tok of queryTokens) {
          if (lowerTitle.includes(tok)) score += 3;
          if (tags.some((t) => t.includes(tok))) score += 2;
          if (lowerContent.includes(tok)) score += 1;
        }

        if (score === 0) return null;
      } else {
        score = 1;
      }

      if (!snippet) {
        snippet = content.slice(0, 150).replace(/\n/g, ' ') + (content.length > 150 ? '...' : '');
      }

      return {
        id: d.id,
        title: title || 'Untitled',
        date: createdAt,
        author: v.author || '',
        category,
        mood,
        tags: v.tags || [],
        wordCount: v.wordCount || content.split(/\s+/).filter(Boolean).length,
        snippet,
        score,
      };
    }).filter(Boolean);

    matched.sort((a, b) => b.score - a.score);
    const results = matched.slice(0, limit);

    return JSON.stringify({
      entries: results,
      count: results.length,
      totalMatches: matched.length,
      note: 'To read the complete unabridged text of any entry, call read_journal_entry with its id.'
    });
}

async function exec_read_journal_entry(ctx, args) {
    const id = String(args.id || args.entry_id || args.entryId || '').trim();
    const title = String(args.title || '').trim();

    let doc = null;
    if (id) {
      const docSnap = await ctx.db.collection('journal_entries').doc(id).get();
      if (docSnap.exists) {
        doc = docSnap;
      }
    }

    if (!doc && title) {
      const titleLower = title.toLowerCase();
      const snap = await ctx.db.collection('journal_entries').orderBy('createdAt', 'desc').limit(50).get();
      doc = snap.docs.find((d) => String(d.data().title || '').trim().toLowerCase() === titleLower)
         || snap.docs.find((d) => String(d.data().title || '').toLowerCase().includes(titleLower));
    }

    if (!doc) {
      return JSON.stringify({
        error: `Journal entry not found with ${id ? `id "${id}"` : ''}${id && title ? ' or ' : ''}${title ? `title "${title}"` : ''}. Use search_journal_entries to find the correct entry id.`
      });
    }

    const v = doc.data();
    const content = String(v.content || '');
    return JSON.stringify({
      success: true,
      id: doc.id,
      title: v.title || 'Untitled',
      content: content,
      author: v.author || '',
      category: v.category || 'daily',
      mood: v.mood || null,
      tags: Array.isArray(v.tags) ? v.tags : [],
      createdAt: v.createdAt?.toDate?.()?.toISOString() || null,
      updatedAt: v.updatedAt?.toDate?.()?.toISOString() || null,
      wordCount: v.wordCount || content.split(/\s+/).filter(Boolean).length,
      isPinned: Boolean(v.isPinned),
      isLocked: Boolean(v.isLocked),
    });
}

module.exports = {
  exec_remember_fact,
  exec_read_memories,
  exec_pin_memory,
  exec_delete_memory,
  exec_edit_memory,
  exec_save_to_starlight_jar,
  exec_read_starlight_jar,
  exec_create_journal_entry,
  exec_get_journal_entries,
  exec_search_journal_entries,
  exec_read_journal_entry,
};
