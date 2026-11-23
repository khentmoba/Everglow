import assert from 'node:assert/strict';
import test from 'node:test';
import { normalizeShot, parseArgs, parseViewport } from './capture_proof.mjs';

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
