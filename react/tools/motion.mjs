// Checks that touch motion lands in the same place in both builds: holds a
// keypad key down (shrink), then lets go (dot fills in). Phone size, motion on.
//
//   node tools/motion.mjs [--out dir] [--settle ms]
//
// Saves <step>-flutter.png, <step>-react.png and <step>-diff.png per step.
// The "mid" steps are taken partway through an animation; screenshot timing
// jitters by tens of ms, so treat their numbers as a rough guide only.
import { mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { SIZES, diff, flag, openPage, withApps } from './shared.mjs';

const outDir = resolve(flag('--out', 'compare-out/motion'));
const settle = Number(flag('--settle', '6000'));
mkdirSync(outDir, { recursive: true });

const KEY_5 = { x: 185, y: 431 };
const STEPS = [
  { name: 'press-mid', touch: 'touchStart', wait: 60 },
  { name: 'press-held', wait: 400 },
  { name: 'release-mid', touch: 'touchEnd', wait: 100 },
  { name: 'release-done', wait: 600 },
];

async function run(browser, url, app) {
  const { page, context } = await openPage(browser, url, SIZES.phone, { motion: true });
  await page.waitForTimeout(settle);
  await page.evaluate(() => document.fonts?.ready);
  const cdp = await context.newCDPSession(page);
  for (const step of STEPS) {
    if (step.touch) {
      await cdp.send('Input.dispatchTouchEvent', {
        type: step.touch,
        touchPoints: step.touch === 'touchEnd' ? [] : [KEY_5],
      });
    }
    await page.waitForTimeout(step.wait);
    await page.screenshot({ path: join(outDir, `${step.name}-${app}.png`) });
  }
  await context.close();
}

await withApps(async (browser, base) => {
  await run(browser, base.flutter + '/', 'flutter');
  await run(browser, base.react + '/', 'react');
  for (const { name } of STEPS) {
    const f = join(outDir, `${name}-flutter.png`);
    const { pct } = diff(f, join(outDir, `${name}-react.png`), join(outDir, `${name}-diff.png`));
    console.log(`${name}: ${pct}% differ`);
  }
});
