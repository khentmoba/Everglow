import assert from 'node:assert/strict';
import test from 'node:test';
import { functionsVersionMatches, hasStreamLimit } from './run_checks.mjs';

test('functions APP_VERSION must carry the app version', () => {
  assert.equal(functionsVersionMatches("const APP_VERSION = '6.3.0+1';", '6.3.0'), true);
  assert.equal(functionsVersionMatches("const APP_VERSION = '6.2.9+1';", '6.3.0'), false);
  assert.equal(functionsVersionMatches('const OTHER = 1;', '6.3.0'), false);
});

test('stream limit check accepts plain, aliased, and limitToLast calls', () => {
  assert.equal(hasStreamLimit('query(col, orderBy("t"), limit(50))'), true);
  assert.equal(hasStreamLimit("import { limit as fbLimit } from 'firebase/firestore';\nquery(col, fbLimit(50))"), true);
  assert.equal(hasStreamLimit('query(col, limitToLast(20))'), true);
  assert.equal(hasStreamLimit('query(col, orderBy("t"))'), false);
});
