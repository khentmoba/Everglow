// node tools/rows.mjs img x0 x1 y0 y1 — prints the y-runs of rows holding bright pixels (finds text lines to compare).
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';
const [, , f, x0, x1, y0, y1] = process.argv;
const img = PNG.sync.read(readFileSync(f));
let runStart = null; const out = [];
for (let y = +y0; y <= +y1; y++) {
  let hit = false;
  for (let x = +x0; x < +x1; x++) { const i = (y * img.width + x) * 4; if (img.data[i] > 180 && img.data[i+1] > 180) { hit = true; break; } }
  if (hit && runStart == null) runStart = y;
  if (!hit && runStart != null) { out.push(`${runStart}-${y - 1}`); runStart = null; }
}
console.log(out.join(' '));
