// node tools/measure.mjs "<route>" "<js expr returning elements>" [--size phone|tablet] [--click "x,y;x,y"] — prints React DOM boxes.
import { SIZES, args, flag, openPage, withApps } from './shared.mjs';
const route = args.find((a) => a.startsWith('/')) ?? '/';
const expr = args.find((a) => !a.startsWith('/') && !a.startsWith('--') && a !== flag('--size') && a !== flag('--click'));
const size = SIZES[flag('--size', 'phone')];
await withApps(async (browser, base) => {
  const { page, context } = await openPage(browser, base.react + route, size);
  await page.waitForTimeout(Number(flag('--settle', '6000')));
  for (const pt of (flag('--click') ?? '').split(';').filter(Boolean)) {
    const [x, y] = pt.split(',').map(Number);
    await page.mouse.click(x, y);
    await page.waitForTimeout(1500);
  }
  const boxes = await page.evaluate((e) => {
    const els = [...eval(e)];
    return els.map((el) => {
      const r = el.getBoundingClientRect();
      return `${el.tagName.toLowerCase()} "${(el.textContent || '').trim().slice(0, 24)}" x=${r.x.toFixed(2)} y=${r.y.toFixed(2)} w=${r.width.toFixed(2)} h=${r.height.toFixed(2)}`;
    });
  }, expr);
  console.log(boxes.join('\n'));
  await context.close();
});
