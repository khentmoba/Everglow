'use strict';
// Bridge: live Motchi routing as JSON for the Dart eval gate.
// The Dart keyword rules were a strawman that drifted from the real
// router; this keeps one source of truth (selectToolNames) and lets
// `dart tool/motchi_prompt_eval.dart` score the code that actually ships.
// Run: node tool/motchi_eval_bridge.js
const { selectToolNames, TOOL_NAMES } = require('../functions/motchi_tools.js');
const evalCases = require('../functions/test/motchi_eval_cases.json');

const out = evalCases.map((c) => ({
  id: c.id,
  message: c.message,
  expectedTools: c.expectedTools || [],
  selected: selectToolNames(c.message || ''),
}));
console.log(JSON.stringify({ tools: TOOL_NAMES.length, cases: out }));
