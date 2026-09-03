'use strict';

/* Mochi regression gate — offline, zero LLM cost.
 *
 * Fails closed (exit 1) when the live contract in `index.js` drifts from
 * the pinned helpers, prompt snapshot, or eval cases:
 *   1. TOOL_TIMEOUT_MS / MAX_TOOL_ROUNDS match `mochi_tools.js`
 *   2. MOCHI_TOOLS declarations match TOOL_NAMES (both directions)
 *   3. every `executeTool` case names a known tool
 *   4. every eval case references known tools only
 *   5. prompt snapshot version + tool inventory match TOOL_NAMES
 *
 * Usage: `node eval_gate.js` (from `functions/`) or
 *        `node functions/eval_gate.js` (from repo root).
 * Prints one JSON report to stdout; diagnostics go to stderr.
 */

const fs = require('node:fs');
const path = require('node:path');

const EXPECTED_PROMPT_VERSION = 1;
const MIN_EVAL_CASES = 20;

const root = __dirname;
const indexSrc = fs.readFileSync(path.join(root, 'index.js'), 'utf8');
const tools = require('./mochi_tools.js');
const evalCases = require('./test/mochi_eval_cases.json');
const promptSnap = fs.readFileSync(path.join(root, 'mochi_prompt_v1.md'), 'utf8');

const failures = [];
const checks = {};

function check(name, ok, detail = '') {
  checks[name] = ok ? 'pass' : `FAIL${detail ? `: ${detail}` : ''}`;
  if (!ok) failures.push(name);
}

const timeout = indexSrc.match(/const TOOL_TIMEOUT_MS = (\d+);/);
const rounds = indexSrc.match(/const MAX_TOOL_ROUNDS = (\d+);/);
check('constants.timeout', timeout !== null && Number(timeout[1]) === tools.TOOL_TIMEOUT_MS);
check('constants.rounds', rounds !== null && Number(rounds[1]) === tools.MAX_TOOL_ROUNDS);

const declared = [...indexSrc.matchAll(/name: '([a-z_]+)',/g)].map((m) => m[1]);
const declaredSet = new Set(declared);
check('tools.count', declared.length === tools.TOOL_NAMES.length,
  `index=${declared.length} pinned=${tools.TOOL_NAMES.length}`);
check('tools.declared-in-pinned', declared.every((n) => tools.TOOL_NAMES.includes(n)));
check('tools.pinned-in-declared', tools.TOOL_NAMES.every((n) => declaredSet.has(n)),
  tools.TOOL_NAMES.filter((n) => !declaredSet.has(n)).join(','));

const nonTools = new Set(['assistant', 'guardian', 'recommendations', 'date_ideas']);
const cases = [...indexSrc.matchAll(/case '([a-z_]+)': \{/g)].map((m) => m[1]);
const orphanCases = cases.filter((n) => !nonTools.has(n) && !tools.TOOL_NAMES.includes(n));
check('tools.cases-covered', orphanCases.length === 0, orphanCases.join(','));

check('eval.min-cases', Array.isArray(evalCases) && evalCases.length >= MIN_EVAL_CASES,
  `saw ${Array.isArray(evalCases) ? evalCases.length : 'non-array'}`);
const badRefs = [];
for (const c of evalCases) {
  for (const t of c.expectedTools || []) {
    if (!tools.TOOL_NAMES.includes(t)) badRefs.push(`${c.id}->${t}`);
  }
}
check('eval.tools-known', badRefs.length === 0, badRefs.join(','));
const plainChat = evalCases.filter((c) => (c.expectedTools || []).length === 0);
check('eval.has-no-tool-cases', plainChat.length >= 2, 'need >=2 plain-chat cases');

check('prompt.version', promptSnap.includes(`version: ${EXPECTED_PROMPT_VERSION}`));
const missingFromPrompt = tools.TOOL_NAMES.filter((n) => !promptSnap.includes(n));
check('prompt.inventory', missingFromPrompt.length === 0, missingFromPrompt.join(','));

const report = {
  pass: failures.length === 0,
  failures,
  checks,
  stats: {
    tools: tools.TOOL_NAMES.length,
    evalCases: evalCases.length,
    promptVersion: EXPECTED_PROMPT_VERSION,
  },
};
console.log(JSON.stringify(report, null, 2));
if (failures.length > 0) {
  console.error(`eval gate FAILED: ${failures.join(', ')}`);
  process.exit(1);
} else {
  console.error('eval gate passed.');
}
