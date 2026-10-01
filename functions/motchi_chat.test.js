'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const chat = require('./motchi_chat');
const indexExports = require('./index');

test('motchi chat group exposes the chat handler', () => {
  assert.equal(typeof chat.handleProxyAI, 'function');
});

test('index wraps the chat handler as proxyAI + proxyAIv2', () => {
  assert.equal(typeof indexExports.proxyAI, 'function');
  assert.equal(typeof indexExports.proxyAIv2, 'function');
});

test('every persona renders its tool list from attached tools', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Fallback placeholder plus a runtime section for custom/Firestore
  // personas — all receive the actual capabilities of this turn.
  assert.ok(src.includes('## Tools available this turn'));
  // The prompt must never advertise tools that routing removed.
  assert.equal(src.split('%%MOTCHI_TOOL_LIST%%').length - 1, 3);
  // nimMessages is built before routing, so the rendered prompt must be
  // pushed back into it (otherwise the model sees the placeholder).
  assert.match(src, /nimMessages\[0\]\.content = systemPrompt/);
  // The old static 50-tool list must stay out of the fallback persona.
  assert.ok(!src.includes('- get_trips — Read trips'));
});

test('fallback persona forbids dangling preambles after tool calls', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Motchi once left "Let me save the standouts:" hanging with no
  // post-tool list — the persona must demand the finished summary.
  assert.ok(src.includes('never leave one hanging'));
});

test('non-streaming answers run the agent loop (Undo restores)', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Both answer paths must execute tools — dropping non-streaming tool
  // calls silently broke Motchi's Undo restores and one-shot callers.
  const executions = src.split('await executeToolCall(').length - 1;
  assert.ok(executions >= 2, `expected streaming + non-streaming executors, saw ${executions}`);
  assert.match(src, /for \(let round = 0; round < MAX_TOOL_ROUNDS; round\+\+\)/);
  assert.match(src, /Non-streaming mode: bounded agent loop/);
});

test('chess asks route to the Play Zone instead of an HTML copy', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // The model must send chess/scribble/table-tennis to the real games
  // via an everglow-link block — a rushed HTML clone can never match
  // Couple Chess, and long generations lose their closing fence.
  assert.ok(src.includes('everglow-link'));
  assert.ok(src.includes('/play-zone/chess'));
  assert.ok(src.includes('/play-zone/scribble'));
  assert.ok(src.includes('/play-zone/tt'));
});

test('artifact stripping hides everglow-link blocks from text checks', () => {
  const reply = 'Couple Chess is waiting! ♟️\n```everglow-link\n{"route": "/play-zone/chess"}\n```';
  assert.equal(chat.stripArtifactsForChecks(reply), 'Couple Chess is waiting! ♟️');
});

test('hasCompleteArtifact spots complete vs missing blocks', () => {
  assert.equal(chat.hasCompleteArtifact('Made you checkers!\n```html-artifact\n<html></html>\n```'), true);
  assert.equal(chat.hasCompleteArtifact('```quiz-json\n[]\n```'), true);
  assert.equal(chat.hasCompleteArtifact('```everglow-link\n{}\n```'), true);
  assert.equal(chat.hasCompleteArtifact('Made you a game!'), false);
  assert.equal(chat.hasCompleteArtifact('Making it!\n```html-artifact\n<html>'), false);
  assert.equal(chat.hasCompleteArtifact(''), false);
});

test('endsWithDanglingColon spots a promised list that never arrived', () => {
  assert.equal(chat.endsWithDanglingColon('Let me save the standout details I found:'), true);
  assert.equal(chat.endsWithDanglingColon('Let me save the standout details I found:\n  \n'), true);
  assert.equal(chat.endsWithDanglingColon('Saved: morning walks, lilies, ramen nights.'), false);
  assert.equal(chat.endsWithDanglingColon('Here are your 3: 1. one'), false);
  assert.equal(chat.endsWithDanglingColon(''), false);
  assert.equal(chat.endsWithDanglingColon(null), false);
});

test('dangling-list repair is wired on both answer paths', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Nudge const + streaming in-loop + streaming post-loop + non-streaming.
  const uses = src.split('DANGLING_REPLY_NUDGE').length - 1;
  assert.ok(uses >= 4, `expected nudge const + 3 uses, saw ${uses}`);
  assert.match(src, /didDanglingRepair/);
  assert.match(src, /endsWithDanglingColon/);
});

test('streaming dangling repair covers loop exits (repeat guard + round cap)', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // The in-loop nudge only runs when a round ends with no tool calls —
  // the repeat-guard break and the 8-round cap used to skip it and ship
  // "Let me save the standouts:" with no list after it.
  assert.match(src, /Post-loop repair/);
  assert.match(src, /needsPostLoopRepair/);
  // The post-loop call streams its text after the preamble as one reply.
  assert.ok(src.includes('sendEvent({ content: repairText })'));
  // Bounded by the same per-message spend brake as the loop.
  assert.ok(src.includes('llmCalls < MAX_LLM_CALLS_PER_MESSAGE'));
});

test('repair rounds detach tools so the model must answer in text', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // A repair nudge that still carries tools can be disobeyed with another
  // tool call — both paths must send the nudge with no tools attached.
  assert.match(src, /forceTextNextRound/);
  assert.ok(src.includes('!noToolsThisRound ? { tools, tool_choice: \'auto\' } : {}'));
  assert.match(src, /callLlmOnce\(msgs, withoutTools = false\)/);
  const textOnlyRepairs = src.split('callLlmOnce(nsMessages, true)').length - 1;
  assert.equal(textOnlyRepairs, 2);
});

test('missing-block repair is wired on both answer paths', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Nudge const + streaming use + non-streaming use.
  const uses = src.split('ARTIFACT_REPAIR_NUDGE').length - 1;
  assert.ok(uses >= 3, `expected nudge const + 2 uses, saw ${uses}`);
  assert.match(src, /didArtifactRepair/);
});

test('streaming error catch preserves streamed content and isolates background tasks', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Background memory extraction & hallucination checks must be guarded
  // so post-stream errors don't trigger the outer streaming error handler.
  assert.match(src, /post-reply tasks error/);
  // Outer streaming catch must NOT send error event if content was already streamed.
  assert.match(src, /if \(!_streamedFinalReply\.trim\(\)\) \{\s*sendEvent\(\{ error:/);
});

test('retries use the fast 1s step (TokenHarbor has no RPM window)', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // TokenHarbor is pay-as-you-go — the Sep 2026 Agnes 5/min RPM window
  // (12s 429 backoff) is gone. Every retry keeps the fast 1s step.
  assert.doesNotMatch(src, /lastWas429/);
  assert.doesNotMatch(src, /12000 \* \(attempt \+ 1\)/);
  assert.match(src, /const waitMs = 1000 \* \(attempt \+ 1\)/);
});

test('chat uses the fast TokenHarbor provider', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.match(src, /process\.env\.TOKENHARBOR_API_KEY/);
  assert.match(src, /const model = 'glm-5\.3-flash'/);
  assert.match(src, /tokenharbor\.ai\/v1\/chat\/completions/);
  assert.doesNotMatch(src, /AGNES_API_KEY|agnes-3\.0-flash|apihub\.agnes-ai\.com\/v1\/chat\/completions/);
});

test('game guide only rides artifact asks (prompt diet)', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // The ~2.5KB phone-first game guide used to ride every chat through
  // the canvas section. Study mode keeps its ternary gate; the assistant
  // section splits into CANVAS_FULL (artifact turns, guide inside) vs
  // CANVAS_QUICK (plain chat pointer) — the guide must never leak into
  // the slim pointer. Artifact follow-ups ("make it pink") keep it via
  // the previous reply's block, and a bare yes to an offered quiz/game
  // upgrades the build turn to the full guide.
  const gated = src.split("wantsArtifact ? HTML_GAME_GUIDE : ''").length - 1;
  assert.equal(gated, 1);
  assert.match(src, /wantsArtifact \? CANVAS_FULL : CANVAS_QUICK/);
  const quickBlock = src.slice(
    src.indexOf('const CANVAS_QUICK'),
    src.indexOf('wantsArtifact ? CANVAS_FULL : CANVAS_QUICK'),
  );
  assert.ok(!quickBlock.includes('HTML_GAME_GUIDE'), 'slim pointer must not carry the game guide');
  assert.match(src, /hasCompleteArtifact\(prevAssistantText\)/);
  assert.match(src, /isBareYes\(_artifactMsg\)/);
});

test('deploy surface still includes chat + schedules + catalog', () => {
  for (const name of [
    'proxyAI',
    'proxyAIv2',
    'motchiStats',
    'motchiDailyDigest',
    'motchiMemorySweep',
    'proxyTmdb',
    'proxyLastfm',
  ]) {
    assert.ok(indexExports[name], `missing export: ${name}`);
  }
});

test('stripStaleArtifacts keeps only the newest artifact turn', () => {
  const game1 = 'Made you checkers!\n```html-artifact\n<html>old game</html>\n```';
  const game2 = 'Made you snake!\n```html-artifact\n<html>new game</html>\n```';
  const msgs = [
    { role: 'user', content: 'make checkers' },
    { role: 'assistant', content: game1 },
    { role: 'user', content: 'make snake' },
    { role: 'assistant', content: game2 },
  ];
  assert.equal(chat.stripStaleArtifacts(msgs), 1);
  assert.ok(!msgs[1].content.includes('old game'), 'old block must go');
  assert.ok(msgs[1].content.includes('Made you checkers'), 'warm text stays');
  assert.ok(msgs[3].content.includes('new game'), 'newest block stays for follow-ups');
});

test('stripStaleArtifacts leaves plain history and photo parts alone', () => {
  const msgs = [
    { role: 'user', content: [{ type: 'text', text: 'look' }, { type: 'image_url', image_url: { url: 'data:x' } }] },
    { role: 'assistant', content: 'cute pic! 🍡' },
  ];
  assert.equal(chat.stripStaleArtifacts(msgs), 0);
  assert.equal(msgs[1].content, 'cute pic! 🍡');
});

test('light chat skips context reads and the canvas section', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Greetings/smalltalk must not pay for Firestore context, memory rank,
  // persona fetch, or the canvas guide — that prefill is TTFT.
  assert.match(src, /!context && !fastPath && !lightChat/);
  assert.match(src, /fastPath \|\| lightChat/);
  assert.match(src, /_cachedPersona \|\| lightChat/);
  assert.match(src, /feature === 'assistant' && !lightChat && \(canvasOn \|\| wantsArtifact\)/);
  assert.match(src, /LIGHT_CHAT_PROMPT/);
  // Follow-through "ok" keeps full awareness (it executes an offered plan).
  assert.match(src, /hasOffer\(prevAssistantText\) && isBareYes/);
});
