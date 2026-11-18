// Dart runtime pieces some screens rely on for their look: dart2js's
// String.hashCode and dart:math's seeded Random, bit for bit.

/** Dart's `String.hashCode` as dart2js computes it. */
export function dartStringHash(s: string): number {
  let hash = 0;
  for (let i = 0; i < s.length; i++) {
    hash = 0x1fffffff & (hash + s.charCodeAt(i));
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash = hash ^ (hash >> 6);
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}

const MASK64 = (1n << 64n) - 1n;
const MASK32 = 0xffffffffn;

/** Thomas Wang's 64-bit mix, as Random(seed) runs it. */
function mix64(key: bigint): bigint {
  key = (~key + (key << 21n)) & MASK64;
  key ^= key >> 24n;
  key = (key * 265n) & MASK64;
  key ^= key >> 14n;
  key = (key * 21n) & MASK64;
  key ^= key >> 28n;
  key = (key + (key << 31n)) & MASK64;
  return key;
}

/** `Random(seed)` from dart:math (same sequence on the VM and dart2js), for non-negative seeds below 2^32. */
export class DartRandom {
  private state: bigint;

  constructor(seed: number) {
    let state = (0n * 1037n) ^ mix64(BigInt(seed >>> 0));
    if (state === 0n) state = 0x5a17n;
    this.state = state;
    for (let i = 0; i < 4; i++) this.next();
  }

  private next() {
    const lo = this.state & MASK32;
    const hi = this.state >> 32n;
    this.state = (0xffffda61n * lo + hi) & MASK64;
  }

  private get lo(): number {
    return Number(this.state & MASK32);
  }

  nextDouble(): number {
    this.next();
    const bits26 = this.lo & ((1 << 26) - 1);
    this.next();
    const bits27 = this.lo & ((1 << 27) - 1);
    return (bits26 * 2 ** 27 + bits27) / 2 ** 53;
  }

  nextInt(max: number): number {
    if ((max & (max - 1)) === 0) {
      this.next();
      return this.lo & (max - 1);
    }
    for (;;) {
      this.next();
      const rnd32 = this.lo;
      const result = rnd32 % max;
      if (rnd32 - result + max < 2 ** 32) return result;
    }
  }
}
