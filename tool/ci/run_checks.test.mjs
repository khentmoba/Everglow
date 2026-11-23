import assert from 'node:assert/strict';
import test from 'node:test';
import { findMechanicalViolations, functionsVersionMatches, hasStreamLimit } from './run_checks.mjs';

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

test('mechanical guards flag banned rules, proxy, React, and Playwright patterns', () => {
  assert.equal(findMechanicalViolations({ rules: 'allow create: if request.resource.data.size() < 200;' }).length, 1);
  assert.equal(
    findMechanicalViolations({
      mediaProxyFiles: [{ path: 'functions/media_proxy_x.js', content: "res.set('Access-Control-Allow-Origin', '*'); fetch(u);" }],
    }).length,
    2,
  );
  assert.equal(
    findMechanicalViolations({
      mediaProxyFiles: [{ path: 'functions/media_proxy_gallery.js', content: '// ci:raw-fetch-allow\nfetch(u);' }],
    }).length,
    0,
  );
  assert.equal(
    findMechanicalViolations({
      reactFiles: [{ path: 'react/src/a.ts', content: "parent.postMessage('hi', '*'); AbortSignal.any([a, b]);" }],
    }).length,
    2,
  );
  assert.equal(
    findMechanicalViolations({
      reactFiles: [
        { path: 'react/src/a.tsx', content: "style={{ outline: 'none' }}" },
        { path: 'react/src/b.tsx', content: "style={{ outline: 'none' }}" },
      ],
      outlineNoneMax: 1,
    }).length,
    1,
  );
  assert.equal(
    findMechanicalViolations({
      testToolFiles: [{ path: 'react/tools/a.test.mjs', content: 'await page.waitForFunction(() => true, { timeout: 5000 });' }],
    }).length,
    1,
  );
  assert.equal(
    findMechanicalViolations({
      testToolFiles: [{ path: 'react/tools/a.test.mjs', content: 'await page.waitForFunction(() => true, null, { timeout: 5000 });' }],
    }).length,
    0,
  );
});
