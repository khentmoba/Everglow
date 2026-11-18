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

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  checkFirebaseHosting();
  checkReleaseSync();
  checkDemoPrivacy();
  checkNoAds();
  checkFirestoreCollectionsAndLimits();
  checkBuiltDistIfPresent();
}
