import assert from 'node:assert/strict';
import test from 'node:test';
import {
  applyAgentParams,
  detectDuplicateShots,
  isPasscodeGate,
  normalizeShot,
  parseArgs,
  parseViewport,
} from './capture_proof.mjs';

test('parseViewport handles presets and custom WxH dimensions', () => {
  assert.deepEqual(parseViewport('phone'), { width: 430, height: 932, deviceScaleFactor: 2, mobile: true });
  assert.deepEqual(parseViewport('tablet'), { width: 820, height: 1180, deviceScaleFactor: 2, mobile: true });
  assert.deepEqual(parseViewport('desktop'), { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false });
  assert.deepEqual(parseViewport('390x844'), { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  assert.throws(() => parseViewport('banana'), /Invalid --viewport/);
});

test('parseArgs validates required flags and supports --help and --pack', () => {
  assert.equal(parseArgs(['--help']).help, true);
  assert.throws(() => parseArgs(['--route', '/books']), /Missing required --out/);
  assert.throws(() => parseArgs(['--out', 'a.png']), /Missing required --route/);
  const parsed = parseArgs(['--route', '/books?agent=1&hud=0', '--viewport', 'tablet', '--out', 'docs/pr-proof/pr-1/a.png', '--wait', '500']);
  assert.equal(parsed.route, '/books?agent=1&hud=0');
  assert.equal(parsed.viewport, 'tablet');
  assert.equal(parsed.out, 'docs/pr-proof/pr-1/a.png');
  assert.equal(parsed.wait, 500);
  const packParsed = parseArgs(['--pack', 'shots.json']);
  assert.equal(packParsed.pack, 'shots.json');
});

test('normalizeShot validates pack entries and normalizes routes', () => {
  const shot = normalizeShot({ route: 'manga?agent=1&hud=0', out: 'out/m.png' }, { viewport: 'tablet', wait: 800 });
  assert.equal(shot.route, '/manga?agent=1&hud=0');
  assert.equal(shot.viewport, 'tablet');
  assert.equal(shot.wait, 800);
  assert.throws(() => normalizeShot({ route: '/a', out: 'a.png', viewport: 'invalid' }), /Invalid --viewport/);
});

test('applyAgentParams auto-appends agent=1&hud=0 unless opted out or already specified', () => {
  assert.equal(applyAgentParams('/sanctuary'), '/sanctuary?agent=1&hud=0');
  assert.equal(applyAgentParams('books?tab=reading'), '/books?tab=reading&agent=1&hud=0');
  assert.equal(applyAgentParams('/?agent=cinema'), '/?agent=cinema&hud=0');
  assert.equal(applyAgentParams('/cinema?agent=1&hud=1'), '/cinema?agent=1&hud=1');
  assert.equal(applyAgentParams('/sanctuary', true), '/sanctuary');
});

test('normalizeShot and parseArgs propagate --no-agent and --allow-duplicates', () => {
  const opts = parseArgs(['--route', '/sanctuary', '--out', 'docs/pr-proof/pr-1/a.png', '--no-agent', '--allow-duplicates']);
  assert.equal(opts.noAgent, true);
  assert.equal(opts.allowDuplicates, true);
  const shot = normalizeShot({ route: '/sanctuary', out: 'docs/pr-proof/pr-1/a.png' }, opts);
  assert.equal(shot.route, '/sanctuary');
  assert.equal(shot.noAgent, true);

  const defaultShot = normalizeShot({ route: '/sanctuary', out: 'docs/pr-proof/pr-1/a.png' });
  assert.equal(defaultShot.route, '/sanctuary?agent=1&hud=0');
  assert.equal(defaultShot.noAgent, false);
});

test('isPasscodeGate detects passcode selector or sign-in copy', () => {
  assert.equal(isPasscodeGate({ hasPasscodeSelector: true, bodyText: '' }), true);
  assert.equal(isPasscodeGate({ hasPasscodeSelector: false, bodyText: 'Please go back and sign in with your passcode.' }), true);
  assert.equal(isPasscodeGate({ hasPasscodeSelector: false, bodyText: 'Welcome to Cinema' }), false);
});

test('detectDuplicateShots flags byte-identical frames in a pack', () => {
  const ok = detectDuplicateShots([
    { out: 'a.png', sha256: '1111111111111111' },
    { out: 'b.png', sha256: '2222222222222222' },
  ]);
  assert.deepEqual(ok, []);

  const dupes = detectDuplicateShots([
    { out: 'home-top.png', sha256: 'abcdef1234567890' },
    { out: 'home-mid.png', sha256: 'abcdef1234567890' },
  ]);
  assert.equal(dupes.length, 1);
  assert.match(dupes[0], /home-top\.png.*home-mid\.png/);
});
