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
  assert.ok(src.includes('## Tools available this turn'));
  assert.equal(src.split('%%MOTCHI_TOOL_LIST%%').length - 1, 3);
  assert.match(src, /nimMessages\[0\]\.content = systemPrompt/);
  assert.ok(!src.includes('- get_trips — Read trips'));
});

test('fallback persona forbids dangling preambles after tool calls', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.ok(src.includes('never leave one hanging'));
});

test('non-streaming answers run the agent loop (Undo restores)', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  const executions = src.split('await executeToolCall(').length - 1;
  assert.ok(executions >= 2, `expected streaming + non-streaming executors, saw ${executions}`);
  assert.match(src, /for \(let round = 0; round < MAX_TOOL_ROUNDS; round\+\+\)/);
  assert.match(src, /Non-streaming mode: bounded agent loop/);
});

test('chess asks route to the Play Zone instead of an HTML copy', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
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
  const uses = src.split('DANGLING_REPLY_NUDGE').length - 1;
  assert.ok(uses >= 4, `expected nudge const + 3 uses, saw ${uses}`);
  assert.match(src, /didDanglingRepair/);
  assert.match(src, /endsWithDanglingColon/);
});

test('streaming dangling repair covers loop exits (repeat guard + round cap)', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.match(src, /Post-loop repair/);
  assert.match(src, /needsPostLoopRepair/);
  assert.ok(src.includes('sendEvent({ content: repairText })'));
  assert.ok(src.includes('llmCalls < MAX_LLM_CALLS_PER_MESSAGE'));
});

test('exhausted tool rounds trigger final text synthesis so web searches finish', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.match(src, /if \(toolRound >= MAX_TOOL_ROUNDS\) \{\s*forceTextNextRound = true;\s*\}/);
  assert.match(src, /while \(toolRound < MAX_TOOL_ROUNDS \|\| forceTextNextRound \|\| repairNextRound\)/);
  assert.match(src, /_streamedFinalReply \+= repairText;\s*sendEvent\(\{ content: repairText \}\);\s*streamInterrupted = false;/);
  assert.match(src, /if \(nsInterrupted && nsMessages\[nsMessages\.length - 1\]\?\.role === 'tool'\)/);
});

test('circling on repeat tool calls forces text synthesis instead of dropping the turn', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.match(src, /collectedToolCalls = dropRepeatCalls\(seenToolCalls, collectedToolCalls\);\s*if \(collectedToolCalls\.length === 0\) \{\s*forceTextNextRound = true;\s*continue;\s*\}/);
});

test('repair rounds detach tools so the model must answer in text', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.match(src, /forceTextNextRound/);
  assert.ok(src.includes('!noToolsThisRound ? { tools, tool_choice: \'auto\' } : {}'));
  assert.match(src, /callLlmOnce\(msgs, withoutTools = false\)/);
  const textOnlyRepairs = src.split('callLlmOnce(nsMessages, true)').length - 1;
  assert.equal(textOnlyRepairs, 2);
});

test('missing-block repair is wired on both answer paths', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  const uses = src.split('ARTIFACT_REPAIR_NUDGE').length - 1;
  assert.ok(uses >= 3, `expected nudge const + 2 uses, saw ${uses}`);
  assert.match(src, /didArtifactRepair/);
});

test('streaming error catch preserves streamed content and isolates background tasks', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.match(src, /post-reply tasks error/);
  assert.match(src, /if \(!_streamedFinalReply\.trim\(\)\) \{\s*sendEvent\(\{ error:/);
});

test('Agnes retries wait for rate limits but keep transient retries fast', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
  assert.match(src, /lastWas429 = streamResp.status === 429/);
  assert.match(src, /lastWas429 = false/);
  assert.match(src, /const waitMs = lastWas429 \? 12000 \* \(attempt \+ 1\) : 1000 \* \(attempt \+ 1\)/);
});

test('all Motchi model calls and deployment use Agnes Flash', () => {
  for (const file of ['motchi_chat.js', 'motchi_memory.js', 'motchi_schedules.js', 'motchi_study.js']) {
    const src = fs.readFileSync(path.join(__dirname, file), 'utf8');
    assert.match(src, /process\.env\.AGNES_API_KEY/);
    assert.ok(src.includes("'agnes-3.0-flash'"));
    assert.ok(src.includes('https://apihub.agnes-ai.com/v1/chat/completions'));
    assert.match(src, /chat_template_kwargs: \{ enable_thinking:/);
    assert.doesNotMatch(src, /TOKENHARBOR|tokenharbor|glm-5/);
  }
  const deploy = fs.readFileSync(path.join(__dirname, '../.github/workflows/deploy.yml'), 'utf8');
  assert.ok(deploy.includes('secrets.AGNES_API_KEY'));
  assert.ok(deploy.includes('AGNES_API_KEY=${AGNES_API_KEY}'));
  assert.doesNotMatch(deploy, /TOKENHARBOR_API_KEY/);
});

test('game guide only rides artifact asks (prompt diet)', () => {
  const src = fs.readFileSync(path.join(__dirname, 'motchi_chat.js'), 'utf8');
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
  assert.match(src, /!context && !fastPath && !lightChat/);
  assert.match(src, /fastPath \|\| lightChat/);
  assert.match(src, /_cachedPersona \|\| lightChat/);
  assert.match(src, /feature === 'assistant' && !lightChat && \(canvasOn \|\| wantsArtifact\)/);
  assert.match(src, /LIGHT_CHAT_PROMPT/);
  assert.match(src, /hasOffer\(prevAssistantText\) && isBareYes/);
});
