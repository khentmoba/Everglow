'use strict';
// Motchi agent baseline probe — offline, zero LLM cost.
// Measures live routing (selectToolsForRequest) + context pre-select +
// fast-path over functions/test/motchi_eval_cases.json.
// Run: node tool/motchi_baseline.js
const { selectToolsForRequest, MOTCHI_TOOLS } = require('../functions/motchi_tool_schemas.js');
const { matchFastPath, CORE_TOOLS } = require('../functions/motchi_tools.js');
const { estimateTokens, selectBlockKeys } = require('../functions/motchi_core.js');
const evalCases = require('../functions/test/motchi_eval_cases.json');

const fullSchemaTokens = estimateTokens(JSON.stringify(MOTCHI_TOOLS));
let recallHits = 0, recallTotal = 0, noToolCorrect = 0, noToolTotal = 0;
let attachedSum = 0, schemaTokSum = 0, blocksSum = 0, fastHits = 0;
const misses = [];
const oversize = [];

for (const c of evalCases) {
  const msg = c.message || '';
  const want = c.expectedTools || [];
  const selected = selectToolsForRequest('assistant', msg);
  const names = selected.map((t) => t.function.name);
  attachedSum += names.length;
  schemaTokSum += estimateTokens(JSON.stringify(selected));
  blocksSum += selectBlockKeys(msg).length;
  if (matchFastPath(msg)) fastHits++;
  recallTotal++;
  const hit = want.every((t) => names.includes(t));
  if (hit) recallHits++; else misses.push(`${c.id}: want=[${want}] got ${names.length} tools`);
  if (want.length === 0) {
    noToolTotal++;
    // plain chat should attach few tools (smalltalk/greeting path or awareness set)
    if (names.length <= 11) noToolCorrect++;
  }
  if (names.length > 20) oversize.push(`${c.id}: ${names.length}`);
}

const n = evalCases.length;
const avgAttached = attachedSum / n;
const avgSchemaTok = schemaTokSum / n;
const avgBlocks = blocksSum / n;
const recall = recallHits / recallTotal;
console.log(JSON.stringify({
  cases: n,
  routing_recall: +(recall * 100).toFixed(1),
  misses,
  avg_attached_tools: +avgAttached.toFixed(2),
  full_tools: MOTCHI_TOOLS.length,
  avg_schema_tokens: Math.round(avgSchemaTok),
  full_schema_tokens: fullSchemaTokens,
  schema_token_share: +(avgSchemaTok / fullSchemaTokens * 100).toFixed(1),
  avg_context_blocks: +avgBlocks.toFixed(2),
  fastpath_hits: fastHits,
  plain_chat_lean: `${noToolCorrect}/${noToolTotal}`,
  oversize_cases: oversize,
}, null, 2));
