'use strict';

/* Motchi regression gate — offline, zero LLM cost.
 *
 * Fails closed (exit 1) when the live contract drifts from the pinned
 * helpers, prompt snapshot, or eval cases:
 *   1. TOOL_TIMEOUT_MS / MAX_TOOL_ROUNDS single-sourced in `motchi_tools.js`
 *   2. MOTCHI_TOOLS declarations match TOOL_NAMES (both directions)
 *   3. every tool has an executor and every executor names a known tool
 *   4. every eval case references known tools only
 *   5. prompt snapshot version + tool inventory match TOOL_NAMES
 *
 * Layout (post split): schemas in `motchi_tool_schemas.js`, executors in
 * `motchi_exec_{media,memory,social,planning,insights}.js`, dispatcher in
 * `motchi_exec_tools.js`. The gate scans those files, not motchi_chat.js.
 *
 * Usage: `node eval_gate.js` (from `functions/`) or
 *        `node functions/eval_gate.js` (from repo root).
 * Prints one JSON report to stdout; diagnostics go to stderr.
 */

const fs = require('node:fs');
const path = require('node:path');

const EXPECTED_PROMPT_VERSION = 5;
const MIN_EVAL_CASES = 20;

const root = __dirname;
const chatSrc = fs.readFileSync(path.join(root, 'motchi_chat.js'), 'utf8');
const schemaSrc = fs.readFileSync(path.join(root, 'motchi_tool_schemas.js'), 'utf8');
const dispatchSrc = fs.readFileSync(path.join(root, 'motchi_exec_tools.js'), 'utf8');
const execSrc = ['media', 'memory', 'social', 'planning', 'insights']
  .map((d) => fs.readFileSync(path.join(root, `motchi_exec_${d}.js`), 'utf8'))
  .join('\n');
const tools = require('./motchi_tools.js');
const evalCases = require('./test/motchi_eval_cases.json');
const promptSnap = fs.readFileSync(path.join(root, 'motchi_prompt_v5.md'), 'utf8');

const failures = [];
const checks = {};

function check(name, ok, detail = '') {
  checks[name] = ok ? 'pass' : `FAIL${detail ? `: ${detail}` : ''}`;
  if (!ok) failures.push(name);
}

// Single-source constants: tools.js defines, chat/exec import, nobody redefines.
check('constants.timeout',
  !/const TOOL_TIMEOUT_MS = \d+;/.test(chatSrc) &&
  /TOOL_TIMEOUT_MS/.test(dispatchSrc) &&
  dispatchSrc.includes("require('./motchi_tools.js')"));
check('constants.rounds',
  !/const MAX_TOOL_ROUNDS = \d+;/.test(chatSrc) &&
  /MAX_TOOL_ROUNDS/.test(chatSrc) &&
  chatSrc.includes("require('./motchi_tools.js')"));

const declared = [...schemaSrc.matchAll(/name: '([a-z_]+)',/g)].map((m) => m[1]);
const declaredSet = new Set(declared);
// Self-check against path drift (PR #106 class): a scan that finds zero
// tools means the gate is looking at the wrong file, not that the
// contract is empty.
check('tools.scanned-file-live', declared.length > 0,
  'motchi_tool_schemas.js yielded 0 tools; gate path drifted?');
check('tools.count', declared.length === tools.TOOL_NAMES.length,
  `index=${declared.length} pinned=${tools.TOOL_NAMES.length}`);
check('tools.declared-in-pinned', declared.every((n) => tools.TOOL_NAMES.includes(n)));
check('tools.pinned-in-declared', tools.TOOL_NAMES.every((n) => declaredSet.has(n)),
  tools.TOOL_NAMES.filter((n) => !declaredSet.has(n)).join(','));

const nonTools = new Set(['assistant', 'guardian', 'recommendations', 'date_ideas']);
const execFns = [...execSrc.matchAll(/async function exec_([a-z_]+)\(ctx/g)].map((m) => m[1]);
const mapped = [...dispatchSrc.matchAll(/^  ([a-z_]+): exec_/gm)].map((m) => m[1]);
const orphanExecs = execFns.filter((n) => !nonTools.has(n) && !tools.TOOL_NAMES.includes(n));
check('tools.cases-covered', orphanExecs.length === 0, orphanExecs.join(','));
check('tools.executors-complete',
  tools.TOOL_NAMES.every((n) => execFns.includes(n)),
  tools.TOOL_NAMES.filter((n) => !execFns.includes(n)).join(','));
check('tools.dispatcher-complete',
  tools.TOOL_NAMES.every((n) => mapped.includes(n)),
  tools.TOOL_NAMES.filter((n) => !mapped.includes(n)).join(','));

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
