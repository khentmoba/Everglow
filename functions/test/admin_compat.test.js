'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

// Keep the Admin SDK fully offline during tests: pin a project id and point
// every service at emulator ports. These tests never perform I/O, but this
// makes accidental network access impossible (including in CI).
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-everglow';
process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_STORAGE_EMULATOR_HOST =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';

const { getAdminCompat } = require('../admin_compat.js');

test('legacy namespace API is restored on firebase-admin v14+', () => {
  const admin = getAdminCompat();
  for (const fn of ['auth', 'firestore', 'messaging', 'storage']) {
    assert.equal(typeof admin[fn], 'function', `admin.${fn} should be callable`);
  }
});

test('admin.auth() returns a usable Auth instance', () => {
  // Regression guard for the production failure
  // "getAdmin(...).auth is not a function" (firebase-admin v14).
  const auth = getAdminCompat().auth();
  assert.equal(typeof auth.createCustomToken, 'function');
  assert.equal(typeof auth.getUserByEmail, 'function');
  assert.equal(typeof auth.verifyIdToken, 'function');
});

test('admin.firestore() works with FieldValue/Timestamp statics', () => {
  const admin = getAdminCompat();
  const db = admin.firestore();
  assert.equal(typeof db.collection, 'function');
  assert.equal(typeof admin.firestore.FieldValue.serverTimestamp, 'function');
  assert.ok(admin.firestore.FieldValue.increment(1));
  assert.equal(typeof admin.firestore.Timestamp.now, 'function');
});

test('all legacy services bind to the same default app', () => {
  const admin = getAdminCompat();
  const app = admin.auth().app;
  assert.equal(admin.firestore().app, app);
  assert.equal(admin.messaging().app, app);
  assert.equal(admin.storage().app, app);
});
