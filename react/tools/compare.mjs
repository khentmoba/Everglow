// Side-by-side check that the React build looks like the Flutter build.
//
//   node tools/compare.mjs [path] [--size phone|tablet] [--out dir] [--settle ms] [--motion] [--click x,y[;x,y...]] [--type text] [--seed]
//   --click taps a point (CSS px) halfway through the settle, e.g. to collapse the agent HUD.
//
// Serves ../build/web (Flutter, from `flutter build web`) and ./dist
// (React, from `npm run build`), opens both in headless Chrome at phone
// and tablet sizes, and saves flutter.png, react.png and diff.png per size.
// By default the system "reduce motion" setting is on, so ambient motion
// (petals, breathing glow) stops and both apps sit still for the shot.
// Prints how many pixels differ.
import { mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { SIZES, args, diff, flag, openPage, withApps } from './shared.mjs';

const route = args.find((a) => a.startsWith('/')) ?? '/';
const outDir = resolve(flag('--out', 'compare-out'));
const motion = args.includes('--motion');
const seed = args.includes('--seed');
const settle = Number(flag('--settle', '6000'));
const typed = flag('--type');
const clicks = flag('--click')
  ?.split(';')
  .map((c) => c.split(',').map(Number));
// `--wheel "x,y,dy"` scrolls with the mouse wheel at x,y after the clicks. Headless
// Flutter moves a quarter of a wheel's distance, so its gesture is 4x longer
// (`--flutter-wheel-scale` overrides) to land both apps on the same offset.
const wheel = flag('--wheel')?.split(',').map(Number);
const flutterWheelScale = Number(flag('--flutter-wheel-scale', '4'));
// `landscape` (a phone held sideways) is opt-in: the games only run that way.
const EXTRA = { landscape: { ...SIZES.phone, width: 844, height: 390 } };
const sizes = flag('--size') ? { [flag('--size')]: SIZES[flag('--size')] ?? EXTRA[flag('--size')] } : SIZES;
mkdirSync(outDir, { recursive: true });

async function shoot(browser, url, size, file, isFlutter) {
  const { page, context } = await openPage(browser, url, size, { motion, seed });
  if (clicks) {
    for (const [x, y] of clicks) {
      await page.waitForTimeout(settle / (clicks.length + 1));
      await page.mouse.click(x, y);
    }
    if (typed) await page.keyboard.type(typed, { delay: 40 });
    await page.waitForTimeout(settle / (clicks.length + 1));
  } else await page.waitForTimeout(settle);
  if (wheel) {
    const [x, y, dy] = wheel;
    const cdp = await context.newCDPSession(page);
    await cdp.send('Input.synthesizeScrollGesture', {
      x,
      y,
      yDistance: -dy * (isFlutter ? flutterWheelScale : 1),
      speed: 1200,
      gestureSourceType: 'mouse',
      preventFling: true,
    });
    await page.waitForTimeout(2500);
  }
  await page.evaluate(() => document.fonts?.ready);
  await page.screenshot({ path: file });
  await context.close();
  return file;
}

await withApps(async (browser, base) => {
  for (const [label, size] of Object.entries(sizes)) {
    const f = await shoot(browser, base.flutter + route, size, join(outDir, `${label}-flutter.png`), true);
    const r = await shoot(browser, base.react + route, size, join(outDir, `${label}-react.png`));
    const { changed, total, pct } = diff(f, r, f.replace('-flutter', '-diff'));
    console.log(`${label}: ${changed} of ${total} pixels differ (${pct}%)`);
  }
});
