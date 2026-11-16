// Flutter's implicit animations (AnimatedContainer, AnimatedOpacity): when a
// target changes, the value travels from where it is now to the new target,
// lerped the way Flutter lerps colors, numbers and shadow lists.
import { useEffect, useRef } from 'react';
import { css, parse, type Rgba } from '../theme/colors';
import { type Curve } from '../theme/motion';
import { useController } from './controller';

export type Shadow = { color: string; blur: number; spread: number; dx: number; dy: number };

export function lerpNum(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/** Flutter `Color.lerp`: straight channel mix, alpha included. */
export function lerpColor(a: string, b: string, t: number): string {
  const x = parse(a);
  const y = parse(b);
  const out: Rgba = [
    Math.round(lerpNum(x[0], y[0], t)),
    Math.round(lerpNum(x[1], y[1], t)),
    Math.round(lerpNum(x[2], y[2], t)),
    lerpNum(x[3], y[3], t),
  ];
  return css(out);
}

function scaleShadow(s: Shadow, t: number): Shadow {
  return { color: s.color, blur: s.blur * t, spread: s.spread * t, dx: s.dx * t, dy: s.dy * t };
}

/** Flutter `BoxShadow.lerpList`: pairs by index; extras grow from or shrink to nothing. */
export function lerpShadows(a: Shadow[], b: Shadow[], t: number): Shadow[] {
  const out: Shadow[] = [];
  const common = Math.min(a.length, b.length);
  for (let i = 0; i < common; i++) {
    out.push({
      color: lerpColor(a[i].color, b[i].color, t),
      blur: lerpNum(a[i].blur, b[i].blur, t),
      spread: lerpNum(a[i].spread, b[i].spread, t),
      dx: lerpNum(a[i].dx, b[i].dx, t),
      dy: lerpNum(a[i].dy, b[i].dy, t),
    });
  }
  for (let i = common; i < a.length; i++) out.push(scaleShadow(a[i], 1 - t));
  for (let i = common; i < b.length; i++) out.push(scaleShadow(b[i], t));
  return out;
}

/**
 * Animates `target` with `lerp` over `duration` ms on `curve` each time its
 * `key` changes, starting from the value currently shown.
 */
export function useImplicit<T>(
  target: T,
  key: string,
  lerp: (a: T, b: T, t: number) => T,
  duration: number,
  curve: Curve,
): T {
  const controller = useController(duration);
  const state = useRef({ from: target, to: target, key });
  const s = state.current;
  const shown = controller.isAnimating ? lerp(s.from, s.to, curve(controller.value)) : s.to;
  useEffect(() => {
    if (s.key === key) return;
    state.current = { from: shown, to: target, key };
    controller.duration = duration;
    if (duration <= 0) {
      controller.value = 1;
      return;
    }
    void controller.forward(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return shown;
}
