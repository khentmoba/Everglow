// node tools/crop.mjs in.png out.png x y w h [scale] — crops (and enlarges) a region.
import { readFileSync, writeFileSync } from 'node:fs';
import { PNG } from 'pngjs';
const [, , src, dst, x, y, w, h, s = '1'] = process.argv;
const img = PNG.sync.read(readFileSync(src));
const [X, Y, W, H, S] = [x, y, w, h, s].map(Number);
const out = new PNG({ width: W * S, height: H * S });
for (let j = 0; j < H * S; j++)
  for (let i = 0; i < W * S; i++) {
    const si = ((Y + Math.floor(j / S)) * img.width + X + Math.floor(i / S)) * 4;
    const di = (j * W * S + i) * 4;
    for (let k = 0; k < 4; k++) out.data[di + k] = img.data[si + k];
  }
writeFileSync(dst, PNG.sync.write(out));
