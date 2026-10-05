'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { executeToolCall, clearIdempotencyCache } = require('../motchi_exec_tools.js');
const { exec_request_tools, exec_propose_choices } = require('../motchi_exec_insights.js');
const { resolveToolsForCapabilities, validateToolArgs } = require('../motchi_tools.js');
const { selectInitialToolsForTurn } = require('../motchi_tool_schemas.js');

test('zero-tool start: initial turn tools selection', () => {
  assert.equal(selectInitialToolsForTurn('assistant', 'hi').length, 0);
  assert.equal(selectInitialToolsForTurn('assistant', 'good morning motchi!').length, 0);
  const initial = selectInitialToolsForTurn('assistant', 'what should we eat for dinner?');
  assert.equal(initial.length, 1);
  assert.equal(initial[0].function.name, 'request_tools');
});

test('idempotency guard prevents duplicate creates within 5 min', async () => {
  clearIdempotencyCache();
  const mockCtx = {
    caller: 'khentsgdz',
    callerUid: 'khentsgdz',
    admin: { firestore: { FieldValue: { serverTimestamp: () => 'now' } } },
    db: {
      collection: () => ({
        add: async () => ({ id: 's1' }),
      }),
    },
  };

  const res1 = JSON.parse(await executeToolCall(mockCtx, 'save_to_starlight_jar', { note: 'Grateful for cozy movie nights' }));
  const res2 = JSON.parse(await executeToolCall(mockCtx, 'save_to_starlight_jar', { note: 'Grateful for cozy movie nights' }));

  assert.equal(res1.success, true);
  assert.equal(res1.already_done, undefined);
  assert.equal(res2.already_done, true);
  assert.equal(res2.note, 'Already completed earlier');
});

test('JIT memory bundling in request_tools', async () => {
  const mockDb = {
    collection: () => ({
      doc: () => ({
        collection: () => ({
          orderBy: () => ({
            limit: () => ({
              get: async () => ({
                docs: [
                  { id: 'f1', data: () => ({ fact: 'Clair loves Suzume and anime movies', pinned: true, category: 'fact' }) },
                ],
              }),
            }),
          }),
        }),
      }),
    }),
  };
  const ctx = { db: mockDb, userMessage: 'what was that anime movie?' };
  const res = JSON.parse(await exec_request_tools(ctx, { capabilities: ['anime'], reason: 'anime search' }));
  assert.equal(res.status, 'mounted');
  assert.ok(res.mounted_tools.includes('search_anime'));
  assert.ok(Array.isArray(res.relevant_notes));
});

test('propose_choices executor and validation', async () => {
  assert.equal(validateToolArgs('propose_choices', { prompt: 'Pick one', choices: ['A', 'B'] }).ok, true);
  assert.equal(validateToolArgs('propose_choices', { prompt: 'Pick one', choices: ['A'] }).ok, false);
  const out = JSON.parse(await exec_propose_choices({}, { prompt: 'Vibe?', choices: ['Cozy', 'Active'] }));
  assert.equal(out.success, true);
  assert.deepEqual(out.choices, ['Cozy', 'Active']);
  assert.ok(out.block.includes('choices-json'));
});

test('action hallucination guard spots unperformed action claims', () => {
  const { findActionClaimMismatch } = require('../motchi_chat.js');
  // Claim made, but no steps completed
  const mismatch1 = findActionClaimMismatch('I have added Dune to your watchlist!', []);
  assert.equal(mismatch1?.mismatched, true);
  assert.equal(mismatch1?.tool, 'add_to_watchlist');

  // Claim made, step was completed -> passes!
  const completed = [{ tool: 'add_to_watchlist', status: 'done' }];
  const match = findActionClaimMismatch('I have added Dune to your watchlist!', completed);
  assert.equal(match, null);

  // Hypothetical question -> not a claim
  const question = findActionClaimMismatch('Do you want me to add Dune to your watchlist?', []);
  assert.equal(question, null);
});
