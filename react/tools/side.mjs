// node tools/side.mjs flutter.png react.png out.png — halves both and puts them side by side (Flutter left, React right).
import { PNG } from 'pngjs';
import fs from 'fs';
const [a, b, out] = process.argv.slice(2);
const half = (p) => {
  const I = PNG.sync.read(fs.readFileSync(p));
  const w = I.width >> 1, h = I.height >> 1, O = new PNG({ width: w, height: h });
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 4; c++) {
    let s = 0;
    for (const [dx, dy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) s += I.data[((2 * y + dy) * I.width + 2 * x + dx) * 4 + c];
    O.data[(y * w + x) * 4 + c] = s >> 2;
  }
  return O;
};
const A = half(a), B = half(b), gap = 12;
const O = new PNG({ width: A.width + gap + B.width, height: Math.max(A.height, B.height) });
O.data.fill(255);
PNG.bitblt(A, O, 0, 0, A.width, A.height, 0, 0);
PNG.bitblt(B, O, 0, 0, B.width, B.height, A.width + gap, 0);
fs.writeFileSync(out, PNG.sync.write(O, { colorType: 2 }));
