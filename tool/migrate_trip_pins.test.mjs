import test from 'node:test';
import assert from 'node:assert/strict';
import { migrateTripPins } from './migrate_trip_pins.mjs';

test('pin recovery is dry-run by default, preserves places and is safe to repeat', async () => {
  let data = { places: [{ id: 'existing', name: 'Existing place', done: true }] };
  let writes = 0;
  const sources = [{ id: 'demo', data: () => ({ tripId: 'trip', title: 'Demo cafe', lat: 10, lng: 12, category: 'eat' }) },
    { id: 'missing', data: () => ({ tripId: 'missing', title: 'Demo orphan' }) }];
  const db = { collection: (name) => name === 'travel_pins'
    ? { orderBy() { return this; }, limit() { return this; }, get: async () => ({ docs: sources }) }
    : { doc: (id) => ({ id }) },
  runTransaction: (fn) => fn({ get: async (ref) => ({ exists: ref.id === 'trip', data: () => data }),
    update: (_, patch) => { writes++; data = { ...data, ...patch }; } }),
  };
  assert.deepEqual(await migrateTripPins(db, { log() {} }), { recovered: 1, skipped: 0, missingTrips: 1 });
  assert.equal(writes, 0);
  await migrateTripPins(db, { apply: true, log() {} });
  assert.equal(writes, 1);
  assert.deepEqual(data.places[0], { id: 'existing', name: 'Existing place', done: true });
  assert.deepEqual(data.places[1], { id: 'legacy_pin_demo', name: 'Demo cafe', note: '', done: false,
    lat: 10, lng: 12, category: 'eat' });
  assert.deepEqual(await migrateTripPins(db, { apply: true, log() {} }), { recovered: 0, skipped: 1, missingTrips: 1 });
  assert.equal(writes, 1);
});
