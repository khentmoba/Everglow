'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const tools = require('../motchi_tools.js');

test('tool loop constants are single-sourced in motchi_tools.js', () => {
  const chat = fs.readFileSync(path.join(__dirname, '..', 'motchi_chat.js'), 'utf8');
  const dispatch = fs.readFileSync(path.join(__dirname, '..', 'motchi_exec_tools.js'), 'utf8');
  assert.equal(tools.TOOL_TIMEOUT_MS, 25000);
  assert.equal(tools.MAX_TOOL_ROUNDS, 8);
  // Nobody redefines them; chat + dispatcher import them.
  assert.ok(!/const TOOL_TIMEOUT_MS = \d+;/.test(chat));
  assert.ok(!/const MAX_TOOL_ROUNDS = \d+;/.test(chat));
  assert.ok(dispatch.includes("require('./motchi_tools.js')"));
  assert.ok(dispatch.includes('TOOL_TIMEOUT_MS'));
});

test('TOOL_NAMES covers every tool declared in motchi_tool_schemas.js', () => {
  const schemas = fs.readFileSync(path.join(__dirname, '..', 'motchi_tool_schemas.js'), 'utf8');
  const declared = [...schemas.matchAll(/name: '([a-z_]+)',/g)].map((m) => m[1]);
  assert.ok(declared.length >= 48, `expected >=48 tools, saw ${declared.length}`);
  for (const name of declared) {
    assert.ok(tools.TOOL_NAMES.includes(name), `missing tool: ${name}`);
  }
});

test('every executor names a known tool, and every tool has an executor', () => {
  const execSrc = ['media', 'memory', 'social', 'planning', 'insights']
    .map((d) => fs.readFileSync(path.join(__dirname, '..', `motchi_exec_${d}.js`), 'utf8'))
    .join('\n');
  const dispatch = fs.readFileSync(path.join(__dirname, '..', 'motchi_exec_tools.js'), 'utf8');
  const fns = [...execSrc.matchAll(/async function exec_([a-z_]+)\(ctx/g)].map((m) => m[1]);
  const mapped = [...dispatch.matchAll(/^  ([a-z_]+): exec_/gm)].map((m) => m[1]);
  for (const name of fns) {
    assert.ok(tools.TOOL_NAMES.includes(name), `executor without tool: ${name}`);
  }
  for (const name of tools.TOOL_NAMES) {
    assert.ok(fns.includes(name), `tool without executor: ${name}`);
    assert.ok(mapped.includes(name), `tool not dispatched: ${name}`);
  }
});

test('validateToolArgs rejects unknown tools', () => {
  assert.deepEqual(validate('nope_tool', {}).ok, false);
  assert.match(validate('nope_tool', {}).error, /Unknown tool/);
});

test('validateToolArgs enforces required fields', () => {
  assert.equal(validate('add_to_watchlist', {}).ok, false);
  assert.equal(validate('add_to_watchlist', { title: 'Dune' }).ok, true);
  assert.equal(validate('add_to_watchlist', { tmdb_id: 438631 }).ok, true);
  assert.equal(validate('remove_from_watchlist', {}).ok, false);
  assert.equal(validate('remove_from_watchlist', { title: 'Dune' }).ok, true);
  assert.equal(validate('remember_fact', { fact: '' }).ok, false);
  assert.equal(validate('remember_fact', { fact: 'Khent prefers black coffee' }).ok, true);
  assert.equal(validate('send_note_to_partner', { note: '  ' }).ok, false);
  assert.equal(validate('add_book_to_our_books', { query: '' }).ok, false);
  assert.equal(validate('mark_watchlist_item_watched', {}).ok, false);
  assert.equal(validate('update_book_progress', { title: 'Dune', progress: 50 }).ok, true);
  assert.equal(validate('log_habit', {}).ok, false);
  assert.equal(validate('log_habit', { title: 'Read' }).ok, true);
  assert.equal(validate('add_bucket_item', {}).ok, false);
  assert.equal(validate('add_trip_pin', { title: 'Cafe' }).ok, true);
  assert.equal(validate('search_everglow', { query: '' }).ok, false);
  assert.equal(validate('web_search', { query: 'Ethel Cain tour' }).ok, true);
  assert.equal(validate('search_spotify', {}).ok, false);
  assert.equal(validate('search_spotify', { artist: 'Ethel Cain', track: 'Crush' }).ok, true);
});

test('validateToolArgs enforces length limits', () => {
  assert.equal(validate('send_sanctuary_message', { text: '' }).ok, false);
  assert.equal(validate('send_sanctuary_message', { text: 'hi' }).ok, true);
  assert.match(
    validate('send_sanctuary_message', { text: 'x'.repeat(2001) }).error,
    /max 2000/,
  );
  assert.equal(validate('edit_memory', { memory_id: 'a', fact: 'x'.repeat(501) }).ok, false);
  assert.equal(validate('edit_memory', { memory_id: 'a', fact: 'Khent likes tea' }).ok, true);
  assert.equal(
    validate('create_journal_entry', { title: 'T', content: 'x'.repeat(5001) }).ok,
    false,
  );
  assert.equal(
    validate('create_journal_entry', { title: 'T', content: 'dear diary' }).ok,
    true,
  );
});

test('validateToolArgs checks memory, calendar, trip, and page args', () => {
  assert.equal(validate('pin_memory', {}).ok, false);
  assert.equal(validate('delete_memory', { memory_id: 'm1' }).ok, true);
  assert.equal(validate('edit_memory', { memory_id: 'm1' }).ok, false);
  assert.equal(validate('add_calendar_event', { title: 'Date' }).ok, false);
  assert.equal(validate('add_calendar_event', { title: 'Date', date: 'not-a-date' }).ok, false);
  assert.equal(
    validate('add_calendar_event', { title: 'Date', date: '2026-02-14' }).ok,
    true,
  );
  assert.equal(
    validate('add_trip', { title: 'Siargao', start_date: '2026-01-01', end_date: 'bad' }).ok,
    false,
  );
  assert.equal(
    validate('add_trip', {
      title: 'Siargao',
      start_date: '2026-01-01',
      end_date: '2026-01-05',
    }).ok,
    true,
  );
  assert.equal(validate('read_web_page', { urls: ['notaurl'] }).ok, false);
  const pages = validate('read_web_page', {
    urls: ['https://example.com/a', 'ftp://x', 'https://example.com/b'],
  });
  assert.equal(pages.ok, true);
  assert.deepEqual(pages.urls, ['https://example.com/a', 'https://example.com/b']);
  assert.equal(validate('read_journal_entry', {}).ok, false);
  assert.equal(validate('read_journal_entry', { id: 'entry-123' }).ok, true);
  assert.equal(validate('read_journal_entry', { title: 'First Date' }).ok, true);
  assert.equal(validate('search_journal_entries', { query: 'beach' }).ok, true);
  assert.equal(validate('search_journal_entries', {}).ok, true);
});

test('validateToolArgs passes tools with server-side defaults', () => {
  for (const name of [
    'set_mood',
    'save_to_starlight_jar',
    'search_movies',
    'get_weather',
    'create_reminder',
    'get_watchlist',
    'get_xp_stats',
    'get_today_recap',
  ]) {
    assert.equal(validate(name, {}).ok, true, name);
  }
});

test('limit and count clamps mirror index.js', () => {
  assert.equal(tools.clampStarlightLimit(99), 25);
  assert.equal(tools.clampStarlightLimit(undefined), 10);
  assert.equal(tools.clampWatchlistLimit(99), 40);
  assert.equal(tools.clampWatchlistLimit(undefined), 15);
  assert.equal(tools.clampChatLimit(99), 50);
  assert.equal(tools.clampChatLimit(undefined), 20);
  assert.equal(tools.clampMemoriesLimit(500), 50);
  assert.equal(tools.clampDateIdeasCount(99), 10);
  assert.equal(tools.clampDateIdeasCount(undefined), 3);
  assert.equal(tools.clampTriviaCount(99), 10);
  assert.equal(tools.clampPlanDateCount(99), 5);
  assert.equal(tools.clampGalleryLimit(99), 20);
  assert.equal(tools.clampGalleryLimit(0), 10);
  assert.equal(tools.clampCalendarDays(999), 60);
  assert.equal(tools.clampJournalLimit(999), 10);
  assert.equal(tools.clampTripsLimit(999), 10);
  assert.equal(tools.clampBucketLimit(undefined), 10);
  assert.equal(tools.clampSearchJournalLimit(999), 20);
  assert.equal(tools.clampSearchJournalLimit(undefined), 5);
  assert.equal(tools.clampSearchJournalLimit(0), 5);
});

test('progress and XP clamps mirror index.js', () => {
  assert.equal(tools.clampBookProgress(150), 100);
  assert.equal(tools.clampBookProgress(-5), 0);
  assert.equal(tools.clampBookProgress('oops'), 0);
  assert.equal(tools.clampXpAmount(500), 100);
  assert.equal(tools.clampXpAmount(0), 10);
  assert.equal(tools.clampXpAmount(undefined), 10);
});

test('enum fallbacks mirror index.js defaults', () => {
  assert.equal(tools.normalizeHabitCategory('bogus'), 'health');
  assert.equal(tools.normalizeHabitFrequency('bogus'), 'daily');
  assert.equal(tools.normalizeCalendarType('bogus'), 'custom');
  assert.equal(tools.normalizeJournalCategory('bogus'), 'daily');
  assert.equal(tools.normalizeBucketCategory('bogus'), 'other');
  assert.equal(tools.normalizeBucketPriority('bogus'), 'medium');
  assert.equal(tools.normalizeTripPinCategory('bogus'), 'sight');
  assert.equal(tools.normalizeActivityCategory('bogus'), 'other');
  assert.equal(tools.normalizeActivityCategory('movie'), 'movie');
});

test('titlesMatch mirrors the watchlist lookup rule', () => {
  assert.equal(tools.titlesMatch('Dune: Part Two', 'dune'), true);
  assert.equal(tools.titlesMatch('Dune', 'Dune: Part Two'), true);
  assert.equal(tools.titlesMatch('Dune', 'Interstellar'), false);
  assert.equal(tools.titlesMatch('', 'Dune'), false);
});

test('needsConfirmation mirrors the disambiguation rule', () => {
  assert.equal(
    tools.needsConfirmation('dun', ['Dune', 'Dune: Part Two', 'Interstellar']),
    true,
  );
  assert.equal(tools.needsConfirmation('dune', ['Dune', 'Interstellar']), false);
  assert.equal(
    tools.needsConfirmation('interstellar', ['Interstellar', 'Dune']),
    false,
  );
  assert.equal(tools.needsConfirmation('', ['Dune', 'Dune 2']), false);
});

test('isReminderSchedulable mirrors remindAtTs parsing', () => {
  assert.equal(tools.isReminderSchedulable('2026-02-14T15:00:00'), true);
  assert.equal(tools.isReminderSchedulable('tomorrow at 3pm'), true);
  assert.equal(tools.isReminderSchedulable('someday maybe'), false);
  assert.equal(tools.isReminderSchedulable(''), false);
});

test('tool routing covers every eval case intent', () => {
  const evalCases = require('./motchi_eval_cases.json');
  assert.ok(evalCases.length >= 20, 'need eval cases to guard routing');
  for (const c of evalCases) {
    const selected = tools.selectToolNames(c.message);
    for (const t of c.expectedTools || []) {
      assert.ok(
        selected.includes(t),
        `${c.id} ("${c.message}") missing ${t}; selected ${selected.length}`,
      );
    }
  }
});

test('tool routing stays small', () => {
  const plain = tools.selectToolNames('today was a long day, just wanted to say hi');
  assert.ok(plain.length <= 20, `plain chat selected ${plain.length}`);
  const single = tools.selectToolNames('add Dune to our watchlist');
  assert.ok(single.length <= 20, `single intent selected ${single.length}`);
  const multi = tools.selectToolNames('plan our anniversary trip with movies, books and dinner');
  assert.ok(multi.length <= 32, `multi intent selected ${multi.length}`);
  assert.ok(multi.length < tools.TOOL_NAMES.length, 'routing must beat all-tools');
});

test('routing lists only known tools and reaches all of them', () => {
  const reachable = new Set([
    ...tools.CORE_TOOLS,
    ...tools.AWARENESS_TOOLS,
    ...tools.TOOL_GROUPS.flatMap((g) => g.tools),
  ]);
  for (const name of reachable) {
    assert.ok(tools.TOOL_NAMES.includes(name), `unknown routed tool: ${name}`);
  }
  for (const name of tools.TOOL_NAMES) {
    assert.ok(reachable.has(name), `unreachable tool: ${name}`);
  }
});

test('toolListSection names only the attached tools', () => {
  const section = tools.toolListSection(['search_movies', 'add_to_watchlist']);
  assert.ok(section.includes('- search_movies'));
  assert.ok(section.includes('- add_to_watchlist'));
  assert.ok(!section.includes('remember_fact'));
  assert.ok(section.includes('(and no others)'));
});

test('toolListSection covers all tools and the empty case', () => {
  const full = tools.toolListSection(tools.TOOL_NAMES);
  for (const name of tools.TOOL_NAMES) {
    assert.ok(full.includes(`- ${name}`), `missing ${name}`);
  }
  const empty = tools.toolListSection([]);
  assert.ok(empty.includes('No tools are attached'));
  const deduped = tools.toolListSection(['set_mood', 'set_mood', null, '']);
  assert.equal(deduped.match(/- set_mood/g).length, 1);
});

function validate(name, args) {
  return tools.validateToolArgs(name, args);
}
