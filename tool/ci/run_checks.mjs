import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

function walk(dir, exts, out = []) {
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules' || name === 'dist') continue;
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) walk(full, exts, out);
    else if (exts.some((e) => name.endsWith(e))) out.push(full);
  }
  return out;
}

function checkFirebaseHosting() {
  const cfg = JSON.parse(readFileSync('firebase.json', 'utf8'));
  const hosting = cfg.hosting;
  assert.equal(hosting.public, 'react/dist', 'firebase.json hosting.public must be "react/dist"');
  const headers = hosting.headers ?? [];
  const hasCache = (source, pred) =>
    headers.some((h) => h.source === source && (h.headers ?? []).some((kv) => kv.key === 'Cache-Control' && pred(kv.value)));
  assert.ok(hasCache('/assets/**', (v) => v.includes('immutable') && /max-age=\d+/.test(v)), '/assets/** must be immutable');
  for (const src of ['/', '/index.html', '/sw.js', '/firebase-messaging-sw.js', '/version.json', '/manifest{,_screen}.json']) {
    assert.ok(hasCache(src, (v) => v.includes('no-cache')), `${src} must have Cache-Control: no-cache`);
  }
  console.log('[hosting] OK: firebase.json points to react/dist with proper cache rules.');
}

/** `functions/common.js` APP_VERSION ('X.Y.Z+N') must carry the app version. */
export function functionsVersionMatches(commonJs, ver) {
  const appVersion = /APP_VERSION\s*=\s*['"]([^'"]+)['"]/.exec(commonJs)?.[1];
  return appVersion?.split('+')[0] === ver;
}

/** A live collection stream must call limit(), an aliased import of it, or limitToLast(). */
export function hasStreamLimit(src) {
  return /\b(?:\w*Limit|limit|limitToLast)\(/.test(src);
}

function checkReleaseSync() {
  const pkg = JSON.parse(readFileSync('react/package.json', 'utf8'));
  const ver = String(pkg.version ?? '').trim();
  assert.match(ver, /^\d+\.\d+\.\d+$/, `react/package.json version "${ver}" must be X.Y.Z`);
  const changelog = readFileSync('CHANGELOG.md', 'utf8');
  const firstEntry = /^## \[([^\]]+)\]/m.exec(changelog)?.[1];
  assert.equal(firstEntry, ver, `CHANGELOG.md newest entry [${firstEntry}] != react/package.json (${ver})`);
  const readme = readFileSync('README.md', 'utf8');
  assert.ok(readme.includes(`v${ver}`), `README.md must mention v${ver}`);
  assert.ok(
    functionsVersionMatches(readFileSync('functions/common.js', 'utf8'), ver),
    `functions/common.js APP_VERSION must start with ${ver}`,
  );
  console.log(`[release] OK: react/package.json, CHANGELOG.md, README.md, and functions/common.js synced at v${ver}.`);
}

function checkDemoPrivacy() {
  try {
    const tracked = execFileSync('git', ['ls-files', 'assets/env.txt'], { encoding: 'utf8' }).trim();
    assert.equal(tracked, '', 'assets/env.txt must never be git-tracked');
  } catch {
    // ignore outside git
  }
  const forbidden = /(?:CLAIR|KHENT|BREYAN|OCTAGRAM)_(?:PASSCODE|PASSWORD|EMAIL)/;
  for (const file of [...walk('react/src', ['.ts', '.tsx']), 'react/vite.config.ts', 'react/package.json']) {
    const src = readFileSync(file, 'utf8');
    assert.ok(!forbidden.test(src), `${file}: forbidden secret identifier detected`);
  }
  console.log('[privacy] OK: no tracked env.txt or credential literals in React app.');
}

function checkNoAds() {
  const banned = ['googlesyndication', 'doubleclick', 'admob', 'unityads', 'applovin', 'ironsource'];
  const files = [...walk('react/src', ['.ts', '.tsx']), 'react/package.json'];
  for (const f of files) {
    const lower = readFileSync(f, 'utf8').toLowerCase();
    for (const b of banned) {
      assert.ok(!lower.includes(b), `${f}: banned ad dependency/domain "${b}"`);
    }
  }
  console.log(`[no-ads] OK: ${files.length} files clean.`);
}

function checkFirestoreCollectionsAndLimits() {
  const rules = readFileSync('firestore.rules', 'utf8');
  const ruleCollections = new Set(
    [...rules.matchAll(/match \/([^/{\s]+)/g)].map((m) => m[1]),
  );
  const srcFiles = walk('react/src', ['.ts', '.tsx']);
  let collRefs = 0;
  let streamFiles = 0;

  for (const file of srcFiles) {
    const src = readFileSync(file, 'utf8');
    for (const m of src.matchAll(/(?:collection|doc)\(\s*db\s*,\s*['"`]([^'"`${}]+)['"`]/g)) {
      collRefs++;
      assert.ok(ruleCollections.has(m[1]), `${file}: collection "${m[1]}" missing from firestore.rules`);
    }
    if (src.includes('onSnapshot(') && src.includes('collection(')) {
      streamFiles++;
      const waived = src.includes('ci:unbounded-stream');
      assert.ok(waived || hasStreamLimit(src), `${file}: live collection onSnapshot() without limit()`);
    }
  }
  console.log(`[firestore] OK: ${collRefs} collection refs match rules; ${streamFiles} live collection stream files bounded.`);
}

function checkBuiltDistIfPresent() {
  const dist = resolve('react/dist');
  if (!existsSync(dist)) {
    console.log('[dist] skipped (react/dist not yet built).');
    return;
  }
  for (const name of ['index.html', 'version.json', 'sw.js', 'manifest.json', 'firebase-messaging-sw.js', 'embed.html']) {
    assert.ok(existsSync(join(dist, name)), `react/dist/${name} missing`);
  }
  console.log('[dist] OK: react/dist contains required SPA, PWA, SW, and embed outputs.');
}

const OUTLINE_NONE_BASELINE_MAX = 44;

/** Pure mechanical-guard scanner (exported for unit tests). */
export function findMechanicalViolations({
  rules = '',
  mediaProxyFiles = [],
  functionsFiles = [],
  reactFiles = [],
  testToolFiles = [],
  cinemaAnimeJs = '',
  cinemaPlayerTsx = '',
  outlineNoneMax = OUTLINE_NONE_BASELINE_MAX,
} = {}) {
  const errors = [];
  if (/\.data\.size\(\)/.test(rules)) {
    errors.push('firestore.rules: banned .data.size() (counts map keys, not bytes).');
  }
  for (const { path, content } of mediaProxyFiles) {
    if (/Access-Control-Allow-Origin['"\s:,]+\*/i.test(content)) {
      errors.push(`${path}: banned wildcard Access-Control-Allow-Origin (*).`);
    }
    if (/\bfetch\s*\(/.test(content) && !content.includes('ci:raw-fetch-allow')) {
      errors.push(`${path}: raw fetch() in media_proxy_*.js (use fetchPublicUrl or add // ci:raw-fetch-allow).`);
    }
  }
  for (const { path, content } of functionsFiles) {
    if (!content.includes('ci:skip-revocation-check')) {
      for (const m of content.matchAll(/\.verifyIdToken\s*\(([^)]*)\)/g)) {
        if (!/,\s*true\s*$/.test(m[1])) {
          errors.push(`${path}: verifyIdToken() without checkRevoked=true (pass literal true as 2nd arg or // ci:skip-revocation-check).`);
          break;
        }
      }
    }
    if (
      path !== 'functions/common.js' &&
      /\b(?:requireAuth|requireCoupleAuth)\s*\(/.test(content) &&
      !/private,\s*no-store/i.test(content) &&
      !content.includes('ci:public-cache-ok')
    ) {
      errors.push(`${path}: auth-gated Cloud Function without Cache-Control: private, no-store (set private, no-store or // ci:public-cache-ok).`);
    }
  }
  const outlineNoneFiles = [];
  for (const { path, content } of reactFiles) {
    if (/postMessage\([^)]*['"]\*['"]/.test(content) && !content.includes('ci:postmessage-wildcard')) {
      errors.push(`${path}: banned postMessage(..., '*') (use explicit origin or // ci:postmessage-wildcard).`);
    }
    if (/\bAbortSignal\.any\b/.test(content)) {
      errors.push(`${path}: banned AbortSignal.any() (unsupported on older iOS Safari).`);
    }
    if (/\boutline\s*:\s*['"]?none\b/.test(content) && !content.includes('ci:outline-none')) {
      outlineNoneFiles.push(path);
    }
    if (
      path.startsWith('react/src/features/') &&
      /^const\s+\w*Cache\s*=\s*new\s+Map\b/m.test(content)
    ) {
      if (!content.includes('setBoundedCache') && !content.includes('ci:unbounded-cache')) {
        errors.push(`${path}: module-level *Cache Map without setBoundedCache() (use react/src/core/utils/boundedCache.ts or // ci:unbounded-cache).`);
      }
      if (
        !content.includes('clearOnLogout') &&
        !content.includes('everglow:logout') &&
        !content.includes('ci:logout-safe-cache')
      ) {
        errors.push(`${path}: module-level *Cache Map without clearOnLogout()/everglow:logout cleanup (use react/src/core/utils/boundedCache.ts or // ci:logout-safe-cache).`);
      }
    }
  }
  if (outlineNoneFiles.length > outlineNoneMax) {
    errors.push(
      `react/src: outline: 'none' file count (${outlineNoneFiles.length}) exceeded baseline (${outlineNoneMax}); use :focus-visible or add // ci:outline-none.`,
    );
  }
  for (const { path, content } of testToolFiles) {
    if (/\bwaitForFunction\s*\([^,]+,\s*\{\s*timeout\b/.test(content)) {
      errors.push(`${path}: 2-arg waitForFunction(fn, { timeout }) ignores timeout; pass null as 2nd arg.`);
    }
  }
  if (cinemaAnimeJs && cinemaPlayerTsx) {
    const parseMs = (src, name) => {
      const m = new RegExp(`const\\s+${name}\\s*=\\s*(\\d[\\d_]*)\\s*;`).exec(src);
      return m ? Number(m[1].replace(/_/g, '')) : NaN;
    };
    const loadTimeout = parseMs(cinemaPlayerTsx, 'LOAD_TIMEOUT');
    if (!Number.isFinite(loadTimeout)) {
      errors.push('react/src/features/cinema/VideoPlayerPage.tsx: LOAD_TIMEOUT constant not found or not a plain ms literal.');
    }
    for (const name of ['CINEMA_BUDGET_MS', 'CINEMA_PICK_BUDGET_MS']) {
      const budget = parseMs(cinemaAnimeJs, name);
      if (!Number.isFinite(budget)) {
        errors.push(`cloudflare/src/anime.js: ${name} constant not found or not a plain ms literal.`);
      } else if (Number.isFinite(loadTimeout) && budget >= loadTimeout) {
        errors.push(`cloudflare/src/anime.js: ${name} (${budget}ms) must stay below VideoPlayerPage.tsx LOAD_TIMEOUT (${loadTimeout}ms).`);
      }
    }
  }
  return errors;
}

function checkMechanicalGuards() {
  const rules = readFileSync('firestore.rules', 'utf8');
  const functionsFiles = existsSync('functions')
    ? readdirSync('functions')
        .filter((n) => n.endsWith('.js') && !n.endsWith('.test.js'))
        .map((n) => ({ path: `functions/${n}`, content: readFileSync(join('functions', n), 'utf8') }))
    : [];
  const mediaProxyFiles = functionsFiles.filter((f) => /^functions\/media_proxy_.*\.js$/.test(f.path));
  const reactFiles = walk('react/src', ['.ts', '.tsx']).map((p) => ({
    path: p.replace(/\\/g, '/'),
    content: readFileSync(p, 'utf8'),
  }));
  const testToolFiles = [...walk('react/tools', ['.mjs']), ...walk('tool', ['.mjs'])]
    .map((p) => p.replace(/\\/g, '/'))
    .filter((p) => p !== 'tool/ci/run_checks.mjs' && p !== 'tool/ci/run_checks.test.mjs')
    .map((p) => ({ path: p, content: readFileSync(p, 'utf8') }));
  const cinemaAnimeJs = existsSync('cloudflare/src/anime.js') ? readFileSync('cloudflare/src/anime.js', 'utf8') : '';
  const cinemaPlayerTsx = existsSync('react/src/features/cinema/VideoPlayerPage.tsx')
    ? readFileSync('react/src/features/cinema/VideoPlayerPage.tsx', 'utf8')
    : '';
  const errors = findMechanicalViolations({
    rules,
    mediaProxyFiles,
    functionsFiles,
    reactFiles,
    testToolFiles,
    cinemaAnimeJs,
    cinemaPlayerTsx,
  });
  assert.equal(errors.length, 0, errors.join('\n'));
  console.log(
    `[mechanical] OK: firestore.rules, ${functionsFiles.length} functions files, ${reactFiles.length} React files, and ${testToolFiles.length} tool scripts clean.`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  checkFirebaseHosting();
  checkReleaseSync();
  checkDemoPrivacy();
  checkNoAds();
  checkFirestoreCollectionsAndLimits();
  checkMechanicalGuards();
  checkBuiltDistIfPresent();
}
