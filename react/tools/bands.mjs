// node tools/bands.mjs diff.png [band=50] — counts red diff pixels per horizontal band (where the diff lives).
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';
const [, , f, b = 50] = process.argv;
const img = PNG.sync.read(readFileSync(f));
const out = [];
for (let y0 = 0; y0 < img.height; y0 += +b) {
  let n = 0;
  for (let y = y0; y < Math.min(img.height, y0 + +b); y++)
    for (let x = 0; x < img.width; x++) {
      const i = (y * img.width + x) * 4;
      if (img.data[i] === 255 && img.data[i + 1] === 0 && img.data[i + 2] === 0) n++;
    }
  if (n > 200) out.push(`${y0}:${n}`);
}
console.log(out.join(' '));
