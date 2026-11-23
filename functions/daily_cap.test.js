'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const adminCompat = require('./admin_compat.js');
const { checkDailyCap, phtDayKey } = require('./common.js');

function dailyCapAdmin() {
  const docs = new Map();
  let transactionTail = Promise.resolve();
  const db = {
    collection(name) {
      return {
        doc(userId) {
          return {
            collection(subcollection) {
              return {
                doc(day) {
                  return { path: `${name}/${userId}/${subcollection}/${day}` };
                },
              };
            },
          };
        },
      };
    },
    runTransaction(callback) {
      const result = transactionTail.then(() => callback({
        get: async (ref) => ({ data: () => docs.get(ref.path) ?? {} }),
        set: (ref, value, options) => {
          const previous = options?.merge ? (docs.get(ref.path) ?? {}) : {};
          docs.set(ref.path, { ...previous, ...value });
        },
      }));
      transactionTail = result.then(() => {}, () => {});
      return result;
    },
  };
  function firestore() {
    return db;
  }
  firestore.FieldValue = { serverTimestamp: () => 'server timestamp' };
  return { admin: { firestore }, docs };
}

test('daily AI cap counts concurrent calls atomically across workers', async (t) => {
  const { admin, docs } = dailyCapAdmin();
  t.mock.method(adminCompat, 'getAdminCompat', () => admin);

  const limit = 7;
  const results = await Promise.all(
    Array.from({ length: 25 }, () => checkDailyCap('user-1', 'proxyAI', limit)),
  );

  assert.equal(results.filter((result) => result.allowed).length, limit);
  assert.equal(results.filter((result) => !result.allowed).length, 25 - limit);
  assert.deepEqual(results.map((result) => result.count).sort((a, b) => a - b),
    Array.from({ length: 25 }, (_, index) => index + 1));

  const day = phtDayKey();
  const usage = docs.get(`api_usage/user-1/days/${day}`);
  assert.equal(usage.proxyAI, 25);
  assert.equal(usage.updatedAt, 'server timestamp');

  assert.deepEqual(await checkDailyCap('user-1', 'proxyAI', 25), { allowed: false, count: 26 });
  assert.deepEqual(await checkDailyCap('user-2', 'proxyAI', 1), { allowed: true, count: 1 });
  assert.deepEqual(await checkDailyCap('user-1', 'proxyCatalog', 1), { allowed: true, count: 1 });

  assert.equal(docs.get(`api_usage/user-1/days/${day}`).proxyAI, 26);
  assert.equal(docs.get(`api_usage/user-1/days/${day}`).proxyCatalog, 1);
  assert.equal(docs.get(`api_usage/user-2/days/${day}`).proxyAI, 1);
});

test('the daily counter changes over at midnight in Manila, not UTC', () => {
  // 2026-11-23T16:30Z is 00:30 on the 24th in Manila.
  assert.equal(phtDayKey(new Date('2026-11-23T16:30:00Z')), '2026-11-24');
  // 07:59 Manila is still the 24th even though UTC is still 23:59 on the 23rd.
  assert.equal(phtDayKey(new Date('2026-11-23T23:59:00Z')), '2026-11-24');
  // 08:00 Manila is the start of the next UTC day but the same Manila day.
  assert.equal(phtDayKey(new Date('2026-11-24T00:00:00Z')), '2026-11-24');
  assert.equal(phtDayKey(new Date('2026-11-24T15:59:00Z')), '2026-11-24');
  assert.equal(phtDayKey(new Date('2026-11-24T16:00:00Z')), '2026-11-25');
});
