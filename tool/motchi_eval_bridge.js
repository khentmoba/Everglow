'use strict';
const { selectToolNames, TOOL_NAMES } = require('../functions/motchi_tools.js');
const evalCases = require('../functions/test/motchi_eval_cases.json');

const out = evalCases.map((c) => ({
  id: c.id,
  message: c.message,
  expectedTools: c.expectedTools || [],
  selected: selectToolNames(c.message || ''),
}));
console.log(JSON.stringify({ tools: TOOL_NAMES.length, cases: out }));
