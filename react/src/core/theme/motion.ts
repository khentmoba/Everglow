// Same values as lib/core/theme/app_motion.dart, plus the Flutter `Curves`
// this app uses, so every animation moves on the identical curve.

export type Curve = (t: number) => number;

/** Flutter's `Cubic(a, b, c, d)`, solved the same way Flutter does. */
export function cubic(a: number, b: number, c: number, d: number): Curve {
  const evaluate = (p1: number, p2: number, m: number) =>
    3 * p1 * (1 - m) * (1 - m) * m + 3 * p2 * (1 - m) * m * m + m * m * m;
  return (t: number) => {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    let start = 0;
    let end = 1;
    for (;;) {
      const midpoint = (start + end) / 2;
      const estimate = evaluate(a, c, midpoint);
      if (Math.abs(t - estimate) < 0.001) return evaluate(b, d, midpoint);
      if (estimate < t) start = midpoint;
      else end = midpoint;
    }
  };
}

export const linear: Curve = (t) => t;

export const Curves = {
  linear,
  easeInOut: cubic(0.42, 0.0, 0.58, 1.0),
  easeInOutCubic: cubic(0.645, 0.045, 0.355, 1.0),
  easeInQuint: cubic(0.755, 0.05, 0.855, 0.06),
  easeOutCubic: cubic(0.215, 0.61, 0.355, 1.0),
  easeOut: cubic(0.25, 0.1, 0.25, 1.0),
  easeIn: cubic(0.42, 0.0, 1.0, 1.0),
  easeOutBack: cubic(0.175, 0.885, 0.32, 1.275),
  easeOutExpo: cubic(0.19, 1.0, 0.22, 1.0),
  bounceOut,
};

/** Flutter's `Curves.bounceOut`. */
function bounceOut(t: number): number {
  if (t < 1 / 2.75) return 7.5625 * t * t;
  if (t < 2 / 2.75) {
    t -= 1.5 / 2.75;
    return 7.5625 * t * t + 0.75;
  }
  if (t < 2.5 / 2.75) {
    t -= 2.25 / 2.75;
    return 7.5625 * t * t + 0.9375;
  }
  t -= 2.625 / 2.75;
  return 7.5625 * t * t + 0.984375;
}

/** Flutter's `Interval(begin, end, curve)`. */
export function interval(begin: number, end: number, curve: Curve = linear): Curve {
  return (t) => {
    if (t <= begin) return curve(0);
    if (t >= end) return curve(1);
    return curve((t - begin) / (end - begin));
  };
}

/** CSS spellings of the same curves, for CSS transitions. */
export const CssCurves = {
  linear: 'linear',
  easeOutStrong: 'cubic-bezier(0.23, 1, 0.32, 1)',
  easeInQuint: 'cubic-bezier(0.755, 0.05, 0.855, 0.06)',
};

export const AppMotion = {
  easeOutStrong: cubic(0.23, 1.0, 0.32, 1.0),
  easeOutExpo: cubic(0.16, 1.0, 0.3, 1.0),
  drawer: cubic(0.32, 0.72, 0.0, 1.0),
  easeOutQuint: cubic(0.22, 1.0, 0.36, 1.0),
  fast: 160,
  medium: 220,
  page: 320,
  reveal: 400,
};

const reduceQuery =
  typeof window !== 'undefined' ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;

/** `AppMotion.reduced`: the system "reduce motion" setting. */
export function motionReduced(): boolean {
  return reduceQuery?.matches ?? false;
}

export function reduceAmbientMotion(width: number, height: number): boolean {
  return motionReduced() || Math.min(width, height) < 600;
}

export function orZero(ms: number): number {
  return motionReduced() ? 0 : ms;
}

export function orLinear(curve: Curve): Curve {
  return motionReduced() ? linear : curve;
}
