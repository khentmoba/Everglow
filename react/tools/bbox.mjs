// node tools/bbox.mjs a.png b.png x y w h mode — bounding box of ink in a region
// (mode "light": pixels brighter than the region's median by 60; "dark": darker).
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';
const [, , a, b, x, y, w, h, mode = 'light'] = process.argv;
for (const f of [a, b]) {
  const img = PNG.sync.read(readFileSync(f));
  const lum = (i, j) => { const k = (j * img.width + i) * 4; return 0.3 * img.data[k] + 0.59 * img.data[k + 1] + 0.11 * img.data[k + 2]; };
  const vals = [];
  for (let j = +y; j < +y + +h; j++) for (let i = +x; i < +x + +w; i++) vals.push(lum(i, j));
  const med = vals.sort((p, q) => p - q)[vals.length >> 1];
  let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1;
  for (let j = +y; j < +y + +h; j++) for (let i = +x; i < +x + +w; i++) {
    const d = lum(i, j) - med;
    if (mode === 'light' ? d > 60 : d < -60) { x0 = Math.min(x0, i); y0 = Math.min(y0, j); x1 = Math.max(x1, i); y1 = Math.max(y1, j); }
  }
  console.log(f.padEnd(18), `x ${x0}-${x1}  y ${y0}-${y1}  (${(x1 - x0 + 1) / 2} x ${(y1 - y0 + 1) / 2} css px)`);
}
