'use strict';

const common = require('./common.js');

/** Maximum number of turns kept inline in a single session doc. */
const MAX_TURNS_PER_SESSION = 50;

/**
 * Persists a completed chat turn to Firestore under `motchi_sessions/{sessionId}`.
 * Completely fire-and-forget: failure must never break or delay the chat response.
 *
 * @param {Object} params
 * @param {string} [params.sessionId] - Client-provided session ID or null
 * @param {string} params.caller - 'khentsgdz' or 'clairjassen' or username
 * @param {string} [params.feature] - 'assistant', 'guardian', 'study', etc.
 * @param {string} params.userMessage - User's prompt text
 * @param {string} params.assistantReply - Motchi's reply text
 * @param {Array<Object>} [params.tools] - Tools executed: [{ name, args, resultSummary, elapsedMs }]
 * @param {string} [params.reasoning] - Model thinking / reasoning text
 * @param {string} [params.model] - Model name (e.g. agnes-3.8-flash)
 * @param {number} [params.durationMs] - Total turn duration in ms
 * @param {string} [params.error] - Error message if turn failed
 * @param {number} [params.imageCount] - Number of images attached
 * @returns {Promise<string>} The sessionId used
 */
async function recordMotchiTurn({
  sessionId,
  caller = 'unknown',
  feature = 'assistant',
  userMessage = '',
  assistantReply = '',
  tools = [],
  reasoning = '',
  model = '',
  durationMs = 0,
  error = null,
  imageCount = 0,
}) {
  try {
    const db = common.getDb();
    const admin = common.getAdmin();
    const now = new Date();
    const nowIso = now.toISOString();

    let targetId = typeof sessionId === 'string' && sessionId.trim().length >= 3
      ? sessionId.trim()
      : null;

    // If client did not provide a sessionId, look for a recent active session
    // for this caller updated within the last 30 minutes.
    if (!targetId) {
      try {
        const thirtyMinAgo = new Date(now.getTime() - 30 * 60 * 1000);
        const recents = await db.collection('motchi_sessions')
          .where('caller', '==', caller)
          .where('feature', '==', feature)
          .where('updatedAt', '>=', thirtyMinAgo)
          .orderBy('updatedAt', 'desc')
          .limit(1)
          .get();

        if (!recents.empty) {
          targetId = recents.docs[0].id;
        }
      } catch (_) {
        // Query fallback (e.g. if index is warming up): generate new id below
      }
    }

    if (!targetId) {
      const stamp = Date.now();
      const rand = Math.random().toString(36).substring(2, 8);
      targetId = `sess_${stamp}_${caller}_${rand}`;
    }

    const cleanUser = String(userMessage || '').trim();
    const cleanReply = String(assistantReply || '').trim();
    const cleanReasoning = typeof reasoning === 'string' ? reasoning.trim() : '';

    // Turn object representation
    const turnData = {
      timestamp: nowIso,
      userMessage: cleanUser.slice(0, 10000),
      assistantReply: cleanReply.slice(0, 15000),
      tools: (tools || []).map((t) => ({
        name: String(t.name || ''),
        args: t.args && typeof t.args === 'object' ? t.args : {},
        resultSummary: typeof t.resultSummary === 'string' ? t.resultSummary.slice(0, 800) : '',
        elapsedMs: typeof t.elapsedMs === 'number' ? t.elapsedMs : 0,
      })),
      reasoning: cleanReasoning ? cleanReasoning.slice(0, 5000) : '',
      model: String(model || ''),
      durationMs: Number(durationMs) || 0,
      error: error ? String(error).slice(0, 500) : null,
      imageCount: Number(imageCount) || 0,
    };

    const docRef = db.collection('motchi_sessions').doc(targetId);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      // First turn of this session
      const firstLine = cleanUser.split('\n')[0].trim();
      const title = firstLine.length > 60 ? firstLine.substring(0, 60) + '…' : (firstLine || 'New conversation');

      await docRef.set({
        id: targetId,
        caller,
        feature,
        title,
        turnCount: 1,
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        startedAtIso: nowIso,
        updatedAtIso: nowIso,
        lastUserMessage: cleanUser.slice(0, 200),
        lastAssistantReply: cleanReply.slice(0, 200),
        hasError: !!error,
        toolsUsedTotal: turnData.tools.length,
        turns: [turnData],
      });
    } else {
      // Subsequent turn
      const prevData = docSnap.data() || {};
      const prevTurns = Array.isArray(prevData.turns) ? prevData.turns : [];
      let updatedTurns = [...prevTurns, turnData];
      if (updatedTurns.length > MAX_TURNS_PER_SESSION) {
        updatedTurns = updatedTurns.slice(-MAX_TURNS_PER_SESSION);
      }

      await docRef.update({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAtIso: nowIso,
        turnCount: (prevData.turnCount || prevTurns.length) + 1,
        lastUserMessage: cleanUser.slice(0, 200),
        lastAssistantReply: cleanReply.slice(0, 200),
        hasError: prevData.hasError || !!error,
        toolsUsedTotal: (prevData.toolsUsedTotal || 0) + turnData.tools.length,
        turns: updatedTurns,
      });
    }

    return targetId;
  } catch (err) {
    console.warn('[motchi_sessions] Failed to record turn:', err.message);
    return sessionId || null;
  }
}

module.exports = {
  recordMotchiTurn,
  MAX_TURNS_PER_SESSION,
};
