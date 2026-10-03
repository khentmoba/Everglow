'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const { calendarDatesBetween, getCalendarEvents } = require('./calendar_core');
const ph = (value) => new Date(`${value}+08:00`);

test('calendar repeats clamp month ends/leap days and preserve PHT midnight', () => {
  const dates = calendarDatesBetween(ph('2026-01-31T00:00:00'), 'monthly',
    ph('2026-02-01T00:00:00'), ph('2026-04-01T00:00:00'));
  assert.deepEqual(dates, [ph('2026-02-28T00:00:00'), ph('2026-03-31T00:00:00')]);
  const yearly = calendarDatesBetween(ph('2024-02-29T19:00:00'), 'yearly',
    ph('2025-01-01T00:00:00'), ph('2026-01-01T00:00:00'));
  assert.deepEqual(yearly, [ph('2025-02-28T19:00:00')]);
  assert.deepEqual(calendarDatesBetween(ph('2026-01-31T19:00:00'), 'monthly',
    ph('2025-01-01T00:00:00'), ph('2026-01-01T00:00:00')), []);
});

test('server calendar reads include recurring/all-day events, exclude past timed events, and deduplicate', async () => {
  const timestamp = { fromDate: (date) => date };
  const row = (id, date, extra = {}) => ({ id,
    data: () => ({ title: id, date: { toDate: () => date }, ...extra }) });
  const docs = [
    row('all-day', ph('2026-02-15T00:00:00'), { isAllDay: true }),
    row('expired', ph('2026-02-15T09:00:00')),
    row('monthly', ph('2026-01-15T19:00:00'), { recurring: 'monthly' }),
  ];
  const query = { where() { return this; }, orderBy() { return this; },
    limit() { return this; }, async get() { return { docs }; } };
  const events = await getCalendarEvents({ collection: () => query }, timestamp,
    ph('2026-02-15T12:00:00'), ph('2026-02-16T00:00:00'), 20);
  assert.deepEqual(events.map((event) => event.id), ['all-day', 'monthly']);
  assert.equal(events[1].date.toISOString(), ph('2026-02-15T19:00:00').toISOString());
});
