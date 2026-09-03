'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const tools = require('../mochi_tools.js');

test('tool loop constants match index.js', () => {
  const index = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');
  assert.equal(tools.TOOL_TIMEOUT_MS, 25000);
  assert.equal(tools.MAX_TOOL_ROUNDS, 8);
  assert.match(index, /const TOOL_TIMEOUT_MS = 25000;/);
  assert.match(index, /const MAX_TOOL_ROUNDS = 8;/);
});

test('TOOL_NAMES covers every tool declared in index.js MOCHI_TOOLS', () => {
  const index = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');
  const declared = [...index.matchAll(/name: '([a-z_]+)',/g)].map((m) => m[1]);
  assert.ok(declared.length >= 48, `expected >=48 tools, saw ${declared.length}`);
  for (const name of declared) {
    assert.ok(tools.TOOL_NAMES.includes(name), `missing tool: ${name}`);
  }
});

test('every executeTool case has a known tool name', () => {
  const index = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');
  const cases = [...index.matchAll(/case '([a-z_]+)': \{/g)].map((m) => m[1]);
  const nonTools = new Set(['assistant', 'guardian', 'recommendations', 'date_ideas']);
  for (const name of cases) {
    if (nonTools.has(name)) continue;
    assert.ok(tools.TOOL_NAMES.includes(name), `case without tool: ${name}`);
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

function validate(name, args) {
  return tools.validateToolArgs(name, args);
}
