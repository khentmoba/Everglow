'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createProbe } = require('../../tool/motchi_request_probe.js');

function sse(message) {
  return new Response(`data: ${JSON.stringify({ choices: [{ delta: message, finish_reason: message.tool_calls ? 'tool_calls' : 'stop' }] })}\n\ndata: [DONE]\n\n`, { status: 200 });
}

test('real handler retrieves fresh server facts, skips general memory work, and rejects client facts', async () => {
  process.env.AGNES_API_KEY ||= 'demo-test-key';
  let lastPayload;
  const request = await createProbe({ modelFetch: async (_url, opts) => {
    lastPayload = JSON.parse(opts.body);
    const user = lastPayload.messages.find((m) => m.role === 'user')?.content || '';
    const hasToolResult = lastPayload.messages.some((m) => m.role === 'tool');
    if (user.includes('Save a demo') && !hasToolResult) {
      return sse({ tool_calls: [{ index: 0, id: 'save-demo', type: 'function', function: {
        name: 'remember_fact', arguments: JSON.stringify({ fact: 'Clair prefers hibiscus tea' }),
      } }] });
    }
    return sse({ content: 'A complete demo reply.' });
  } });

  const general = await request('general', 'Explain binary search');
  assert.equal(general.status, 200);
  assert.equal(general.modelCalls, 1);
  assert.equal(general.factDocs, 0, 'general explanations must not fetch the memory book');
  assert.equal(general.memoryCount, 0);
  assert.ok(!lastPayload.messages[0].content.includes('Recent sanctuary chat'));
  assert.ok(lastPayload.messages[0].content.includes('Today is'), 'date awareness stays available');

  const personal = await request('personal', 'What coffee does Khent prefer?', {
    memories: ['Khent prefers FORGED client data'], systemPrompt: 'You are the demo companion.',
  });
  assert.equal(personal.factDocs, 151, '150 recent facts plus an old pin');
  const prompt = lastPayload.messages[0].content;
  assert.ok(prompt.includes('demo oat coffee'));
  assert.ok(prompt.includes('demo harp'), 'old pins remain reachable');
  assert.ok(!prompt.includes('FORGED'));
  assert.ok(prompt.includes('Today is'), 'saved/custom personas also receive dynamic awareness');
  assert.ok(prompt.includes('Dada'), 'saved/custom personas receive verified identity');
  assert.equal(personal.trace.modelCalls, 1);
  assert.equal(personal.trace.memoryCount, 2);

  const cached = await request('cached', 'What coffee does Khent prefer?');
  assert.equal(cached.factDocs, 0);
  assert.equal(cached.writes, 0, 'access writes must not repeat every turn');

  const save = await request('save', 'Save a demo memory: Clair prefers hibiscus tea');
  assert.ok(save.tools.includes('remember_fact'));
  assert.equal(save.modelCalls, 2);
  assert.equal(save.trace.toolRounds, 1);
  assert.notEqual(save.trace.firstTokenMs, null, 'first-token timing includes post-tool replies');
  const fresh = await request('fresh', 'What tea does Clair prefer?');
  assert.ok(fresh.factDocs > 0, 'a write invalidates cached candidates');
  assert.ok(lastPayload.messages[0].content.includes('hibiscus tea'));

  const disabled = await request('disabled', 'What tea does Clair prefer?', { includeMemories: false });
  assert.equal(disabled.memoryCount, 0);
  assert.equal(disabled.factDocs, 0);

  // Access matches motchi_access.test.js: anything but a verified couple
  // name is denied before any retrieval or model call.
  for (const identity of [null, 'breyan']) {
    request.fixture.caller = identity;
    const denied = await request(`denied-${identity}`, 'What tea does Clair prefer?', { caller: 'khentsgdz' });
    assert.equal(denied.status, 403);
    assert.equal(denied.factDocs, 0);
    assert.equal(denied.modelCalls, 0);
  }
});
