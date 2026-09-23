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

test('fallback persona renders its tool list from attached tools', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Placeholder in the fallback persona + includes/replace wiring — the
  // prompt must never advertise tools that routing removed.
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
  assert.ok(src.includes('agnesCalls < MAX_AGNES_CALLS_PER_MESSAGE'));
});

test('repair rounds detach tools so the model must answer in text', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // A repair nudge that still carries tools can be disobeyed with another
  // tool call — both paths must send the nudge with no tools attached.
  assert.match(src, /forceTextNextRound/);
  assert.ok(src.includes('!noToolsThisRound ? { tools, tool_choice: \'auto\' } : {}'));
  assert.match(src, /callAgnesOnce\(msgs, withoutTools = false\)/);
  const textOnlyRepairs = src.split('callAgnesOnce(nsMessages, true)').length - 1;
  assert.equal(textOnlyRepairs, 2);
});

test('missing-block repair is wired on both answer paths', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  // Nudge const + streaming use + non-streaming use.
  const uses = src.split('ARTIFACT_REPAIR_NUDGE').length - 1;
  assert.ok(uses >= 3, `expected nudge const + 2 uses, saw ${uses}`);
  assert.match(src, /didArtifactRepair/);
});

test('deploy surface still includes chat + schedules + catalog', () => {
  for (const name of [
    'proxyAI',
    'proxyAIv2',
    'agnesImage',
    'motchiStats',
    'motchiDailyDigest',
    'motchiMemorySweep',
    'proxyTmdb',
    'proxyLastfm',
  ]) {
    assert.ok(indexExports[name], `missing export: ${name}`);
  }
});
