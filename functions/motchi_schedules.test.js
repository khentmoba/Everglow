'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const schedules = require('./motchi_schedules');
const indexExports = require('./index');

const NAMES = [
  'motchiDailyDigest',
  'motchiNightRecap',
  'motchiMoodCheckIn',
  'motchiSmartNudge',
  'motchiWeeklyRecap',
  'motchiSpecialDayNudge',
  'motchiReminderChecker',
  'motchiMemorySweep',
];

test('motchi schedules group exposes eight timers', () => {
  for (const name of NAMES) {
    assert.equal(typeof schedules[name], 'function', `missing: ${name}`);
  }
});

test('index re-exports the schedules group without renaming', () => {
  for (const name of NAMES) {
    assert.equal(indexExports[name], schedules[name], `mismatch: ${name}`);
  }
});
