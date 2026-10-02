'use strict';

// Small, verified receipts — never ask the model to invent execution status.
const WRITE_TOOL_RE = /^(add_|save_|set_|create_|edit_|update_|delete_|remove_|cancel_|complete_|mark_|log_|pin_|send_|remember_)/;
const isWriteTool = (name) => WRITE_TOOL_RE.test(String(name));

const REPLY_DETAILS_PROMPT = `
## Trust and follow-through
- A plan is not a saved action. Say what actually happened using tool results, not what you intended to do. Never say "all done" if a step failed, needs a choice/confirmation, is unscheduled, or has an unknown outcome.
- If only ideas were found, say nothing has been saved yet. Name successful steps separately from unfinished ones. On partial failure offer to finish only unfinished work, never repeat successful writes.
- outcome_unknown means a write may have happened: check the existing record before trying again. Never retry it blindly.
- When a saved fact genuinely shapes your answer, briefly explain why in ordinary words and append [[memory:ID]] using the supplied fact's exact id. Cite only facts you actually used, including facts from read_memories. Never invent ids.
- A fact about Clair is not Khent's preference, and vice versa. Treat something as a shared preference only when the fact explicitly names both. If the owner is unclear, ask rather than assume.
- Core profile notes can change too; offer a correction instead of treating them as immutable truths.
`;

function memoryReference(m) {
  const fact = String(m.fact || '').slice(0, 500);
  const subject = m.subject || fact.match(/^(Khent and Clair|Clair and Khent|Clair|Khent)\b/i)?.[1] || '';
  return { id: String(m.id || ''), fact, subject: String(subject) };
}

function citedMemories(reply, available) {
  const byId = new Map(available.filter((m) => m && m.id && m.fact).map((m) => [String(m.id), m]));
  const ids = [...String(reply || '').matchAll(/\[\[memory:([^\]\r\n]+)\]\]/g)].map((m) => m[1]);
  return [...new Set(ids)].filter((id) => byId.has(id)).slice(0, 10).map((id) => memoryReference(byId.get(id)));
}

function stripMemoryCitations(reply) {
  return String(reply || '').replace(/\[\[memory:[^\]\r\n]*\]\]/g, '');
}

function toolReceipt(tool, args, raw) {
  let result;
  try { result = typeof raw === 'string' ? JSON.parse(raw) : raw; } catch (_) { result = null; }
  const write = isWriteTool(tool);
  let status = 'done';
  if (!result || typeof result !== 'object' || result.outcome_unknown) status = 'unknown';
  else if (result.needs_confirmation) status = 'waiting';
  else if (result.error || result.success === false) status = 'failed';
  else if (result.scheduled === false) status = 'unscheduled';
  else if (write && result.success !== true) status = 'unknown';
  // Don't expose raw provider errors or entire personal records in receipts.
  const title = String(
    result?.title || result?.fact || args?.title || args?.name || args?.query || '',
  ).slice(0, 120);
  const target = String(
    result?.id || result?.memory_id || args?.id || args?.memory_id || args?.title || args?.name || '',
  );
  return { tool, status, write, title, target };
}

module.exports = {
  isWriteTool, REPLY_DETAILS_PROMPT, memoryReference,
  citedMemories, stripMemoryCitations, toolReceipt,
};
