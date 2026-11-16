// node tools/col.mjs img x y0 y1 — prints y where the colour at column x changes (finds borders).
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';
const [, , f, x, y0, y1] = process.argv;
const img = PNG.sync.read(readFileSync(f));
let prev = '';
const out = [];
for (let y = +y0; y <= +y1; y++) {
  const i = (y * img.width + +x) * 4;
  const c = [img.data[i], img.data[i + 1], img.data[i + 2]].map((v) => v.toString(16).padStart(2, '0')).join('');
  if (c !== prev) out.push(`${y}:${c}`);
  prev = c;
}
console.log(out.join(' '));
