'use strict';

const common = require('./common.js');

const MAX_TURNS_PER_SESSION = 50;
const MAX_SESSION_DOC_BYTES = 750 * 1024;
const MAX_TOOL_ARGS_BYTES = 4096;

function boundToolArgs(rawArgs) {
  if (!rawArgs || typeof rawArgs !== 'object' || Array.isArray(rawArgs)) return {};
  try {
    const json = JSON.stringify(rawArgs);
    if (Buffer.byteLength(json, 'utf8') <= MAX_TOOL_ARGS_BYTES) return rawArgs;
    return { _truncated: true, preview: json.slice(0, 1024) };
  } catch {
    return {};
  }
}

function trimTurnsToByteBudget(turns, maxBytes = MAX_SESSION_DOC_BYTES) {
  let trimmed = turns.length > MAX_TURNS_PER_SESSION
    ? turns.slice(-MAX_TURNS_PER_SESSION)
    : turns.slice();
  while (trimmed.length > 1) {
    let bytes;
    try {
      bytes = Buffer.byteLength(JSON.stringify(trimmed), 'utf8');
    } catch {
      break;
    }
    if (bytes <= maxBytes) break;
    trimmed = trimmed.slice(1);
  }
  return trimmed;
}

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
  requestTrace = null,
  temporary = false,
}) {
  if (temporary || (typeof sessionId === 'string' && (sessionId.startsWith('temp_') || sessionId === 'temporary'))) {
    return sessionId || null;
  }
  try {
    const db = common.getDb();
    const admin = common.getAdmin();
    const now = new Date();
    const nowIso = now.toISOString();

    const rawSessionId = typeof sessionId === 'string' ? sessionId.trim() : '';
    let targetId = rawSessionId.length >= 3 && common.isSafeDocId(rawSessionId)
      ? rawSessionId
      : null;

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

    const turnData = {
      timestamp: nowIso,
      userMessage: cleanUser.slice(0, 10000),
      assistantReply: cleanReply.slice(0, 15000),
      tools: (tools || []).map((t) => ({
        name: String(t.name || ''),
        args: boundToolArgs(t.args),
        resultSummary: typeof t.resultSummary === 'string' ? t.resultSummary.slice(0, 800) : '',
        elapsedMs: typeof t.elapsedMs === 'number' ? t.elapsedMs : 0,
      })),
      reasoning: cleanReasoning ? cleanReasoning.slice(0, 5000) : '',
      model: String(model || ''),
      durationMs: Number(durationMs) || 0,
      error: error ? String(error).slice(0, 500) : null,
      imageCount: Number(imageCount) || 0,
      requestTrace: requestTrace ? Object.fromEntries(
        ['modelCalls', 'retries', 'toolRounds', 'repairs', 'firstTokenMs', 'preparedMs', 'contextChars', 'memoryCount', 'memoryChars', 'promptChars', 'attachedTools', 'completedWrites', 'unfinishedWrites', 'unknownWrites', 'interrupted']
          .map((key) => [key, Number.isFinite(requestTrace[key]) ? requestTrace[key] : null]),
      ) : null,
    };

    const docRef = db.collection('motchi_sessions').doc(targetId);
    const applyTurn = async (reader, writer) => {
      const docSnap = await reader(docRef);

      if (!docSnap.exists) {
        const firstLine = cleanUser.split('\n')[0].trim();
        const title = firstLine.length > 60 ? firstLine.substring(0, 60) + '…' : (firstLine || 'New conversation');

        await writer.set(docRef, {
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
        const prevData = docSnap.data() || {};
        const prevTurns = Array.isArray(prevData.turns) ? prevData.turns : [];
        const updatedTurns = trimTurnsToByteBudget([...prevTurns, turnData]);

        await writer.update(docRef, {
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
    };

    await db.runTransaction((tx) =>
      applyTurn((ref) => tx.get(ref), {
        set: (ref, data) => tx.set(ref, data),
        update: (ref, data) => tx.update(ref, data),
      }),
    );

    return targetId;
  } catch (err) {
    console.warn('[motchi_sessions] Failed to record turn:', err.message);
    return sessionId || null;
  }
}

module.exports = {
  recordMotchiTurn,
  MAX_TURNS_PER_SESSION,
  MAX_SESSION_DOC_BYTES,
  boundToolArgs,
  trimTurnsToByteBudget,
};
