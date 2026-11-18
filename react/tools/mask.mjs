// node tools/mask.mjs flutter.png react.png "x,y,w,h;..." — the compare diff, but
// skipping CSS-pixel rectangles (DPR 2) such as a live video box that never matches.
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';
const [, , fa, fb, rects = ''] = process.argv;
const a = PNG.sync.read(readFileSync(fa));
const b = PNG.sync.read(readFileSync(fb));
const boxes = rects
  .split(';')
  .filter(Boolean)
  .map((r) => r.split(',').map((n) => Number(n) * 2));
let masked = 0;
for (const [bx, by, bw, bh] of boxes)
  for (let y = by; y < Math.min(by + bh, a.height); y++)
    for (let x = bx; x < Math.min(bx + bw, a.width); x++) {
      const i = (y * a.width + x) * 4;
      for (let k = 0; k < 4; k++) b.data[i + k] = a.data[i + k];
      masked++;
    }
const changed = pixelmatch(a.data, b.data, null, a.width, a.height, { threshold: 0.1, includeAA: false });
const total = a.width * a.height - masked;
console.log(`${changed} of ${total} pixels differ outside the masked boxes (${((changed / total) * 100).toFixed(2)}%)`);
