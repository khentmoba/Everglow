'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const schedules = require('./mochi_schedules');
const indexExports = require('./index');

const NAMES = [
  'mochiDailyDigest',
  'mochiNightRecap',
  'mochiMoodCheckIn',
  'mochiSmartNudge',
  'mochiWeeklyRecap',
  'mochiSpecialDayNudge',
  'mochiReminderChecker',
  'mochiMemorySweep',
];

test('mochi schedules group exposes eight timers', () => {
  for (const name of NAMES) {
    assert.equal(typeof schedules[name], 'function', `missing: ${name}`);
  }
});

test('index re-exports the schedules group without renaming', () => {
  for (const name of NAMES) {
    assert.equal(indexExports[name], schedules[name], `mismatch: ${name}`);
  }
});
