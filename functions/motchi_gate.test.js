'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');

test('Motchi requires a couple claim before tool/context construction', () => {
  const gate = source.indexOf('await requireCouple(req, res)');
  const tools = source.indexOf('createToolCtx({');
  const context = source.indexOf('buildContextForFeature(feature');
  assert.ok(gate >= 0, 'couple gate missing');
  assert.ok(gate < tools, 'tool context is built before the couple gate');
  assert.ok(gate < context, 'private context is read before the couple gate');
  assert.ok(!source.includes('falling back to client caller'));
});
