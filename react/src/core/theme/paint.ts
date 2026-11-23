// Helpers that reproduce how Flutter paints, where CSS would differ.
//
// 1. Gradients: Flutter mixes colors without premultiplying alpha, so a fade
//    to `Colors.transparent` (transparent black) darkens on the way. CSS
//    premultiplies. `stops()` adds in-between stops computed Flutter's way.
// 2. Diagonal gradients: Flutter runs corner to corner; CSS `to bottom right`
//    does not on non-square boxes. `linear()` computes Flutter's line.
// 3. Shadows: Flutter's blur radius maps to a sigma of r * 0.57735 + 0.5,
//    and the blurred shape is drawn under the whole box, not only outside it.
import type { CSSProperties } from 'react';
import { css, parse, type Rgba } from './colors';

export type Alignment = [x: number, y: number];

export const Align = {
  topLeft: [-1, -1] as Alignment,
  topCenter: [0, -1] as Alignment,
  topRight: [1, -1] as Alignment,
  centerLeft: [-1, 0] as Alignment,
  center: [0, 0] as Alignment,
  centerRight: [1, 0] as Alignment,
  bottomLeft: [-1, 1] as Alignment,
  bottomCenter: [0, 1] as Alignment,
  bottomRight: [1, 1] as Alignment,
};

const SUBDIVISIONS = 8;

function mix(a: Rgba, b: Rgba, t: number): Rgba {
  return [
    Math.round(a[0] + (b[0] - a[0]) * t),
    Math.round(a[1] + (b[1] - a[1]) * t),
    Math.round(a[2] + (b[2] - a[2]) * t),
    a[3] + (b[3] - a[3]) * t,
  ];
}

/** CSS color stops (positions 0..1) matching Flutter's unpremultiplied mixing. */
export function stops(colors: string[], positions?: number[]): Array<[string, number]> {
  const at = positions ?? colors.map((_, i) => (colors.length === 1 ? 0 : i / (colors.length - 1)));
  if (colors.some((c) => c.startsWith('var(') || c.startsWith('color-mix('))) {
    return colors.map((c, i) => [c, at[i]]);
  }
  const parsed = colors.map(parse);
  const out: Array<[string, number]> = [];
  for (let i = 0; i < parsed.length; i++) {
    if (i > 0) {
      const a = parsed[i - 1];
      const b = parsed[i];
      const sameAlpha = Math.abs(a[3] - b[3]) < 1e-6;
      if (!sameAlpha) {
        for (let s = 1; s < SUBDIVISIONS; s++) {
          const t = s / SUBDIVISIONS;
          out.push([css(mix(a, b, t)), at[i - 1] + (at[i] - at[i - 1]) * t]);
        }
      }
    }
    out.push([css(parsed[i]), at[i]]);
  }
  return out;
}

function stopList(list: Array<[string, number]>, map: (p: number) => number = (p) => p): string {
  return list.map(([c, p]) => `${c} ${(map(p) * 100).toFixed(3)}%`).join(', ');
}

/**
 * Flutter `LinearGradient(begin, end, colors, stops)` on a box of size w x h.
 * Pass the box size whenever begin/end are diagonal.
 */
export function linear(
  colors: string[],
  opts: { begin?: Alignment; end?: Alignment; stops?: number[]; size?: [number, number] } = {},
): string {
  const begin = opts.begin ?? Align.centerLeft;
  const end = opts.end ?? Align.centerRight;
  const [w, h] = opts.size ?? [1, 1];
  const p0 = [((begin[0] + 1) / 2) * w, ((begin[1] + 1) / 2) * h];
  const p1 = [((end[0] + 1) / 2) * w, ((end[1] + 1) / 2) * h];
  const dx = p1[0] - p0[0];
  const dy = p1[1] - p0[1];
  const len = Math.hypot(dx, dy) || 1;
  const ux = dx / len;
  const uy = dy / len;
  // CSS angle: 0deg points up, turning clockwise.
  const angle = (Math.atan2(ux, -uy) * 180) / Math.PI;
  const cssLen = Math.abs(w * ux) + Math.abs(h * uy);
  const project = (p: number[]) => ((p[0] - w / 2) * ux + (p[1] - h / 2) * uy) / cssLen + 0.5;
  const t0 = project(p0);
  const t1 = project(p1);
  const list = stops(colors, opts.stops);
  return `linear-gradient(${angle.toFixed(4)}deg, ${stopList(list, (p) => t0 + p * (t1 - t0))})`;
}

/**
 * Flutter `RadialGradient(center, radius, colors, stops)` on a box of size
 * w x h. Flutter's radius is a fraction of the shortest side.
 */
export function radial(
  colors: string[],
  opts: { center?: Alignment; radius?: number; stops?: number[]; size: [number, number] },
): string {
  const center = opts.center ?? Align.center;
  const [w, h] = opts.size;
  const r = (opts.radius ?? 0.5) * Math.min(w, h);
  const cx = ((center[0] + 1) / 2) * w;
  const cy = ((center[1] + 1) / 2) * h;
  return `radial-gradient(circle ${r.toFixed(3)}px at ${cx.toFixed(3)}px ${cy.toFixed(3)}px, ${stopList(
    stops(colors, opts.stops),
  )})`;
}

export type BoxShadow = {
  color: string;
  blur?: number;
  spread?: number;
  offset?: [number, number];
};

export function sigma(blurRadius: number): number {
  return blurRadius > 0 ? blurRadius * 0.57735 + 0.5 : 0;
}

/** CSS `box-shadow` for Flutter shadows on an opaque box. */
export function boxShadow(shadows: BoxShadow[]): string {
  if (shadows.length === 0) return 'none';
  return shadows
    .map((s) => {
      const [x, y] = s.offset ?? [0, 0];
      return `${x}px ${y}px ${(2 * sigma(s.blur ?? 0)).toFixed(3)}px ${s.spread ?? 0}px ${s.color}`;
    })
    .join(', ');
}

/**
 * Styles for one Flutter shadow drawn as its own blurred layer, for boxes
 * that are see-through (Flutter shows the shadow under them).
 * Place it absolutely inside the box's positioned parent.
 */
export function shadowLayer(
  s: BoxShadow,
  shape: { radius?: string | number; circle?: boolean } = {},
): CSSProperties {
  const spread = s.spread ?? 0;
  const [x, y] = s.offset ?? [0, 0];
  return {
    position: 'absolute',
    left: x - spread,
    top: y - spread,
    right: -x - spread,
    bottom: -y - spread,
    background: s.color,
    borderRadius: shape.circle ? '50%' : shape.radius,
    filter: s.blur ? `blur(${sigma(s.blur).toFixed(3)}px)` : undefined,
    pointerEvents: 'none',
  };
}

/**
 * Flutter letter spacing: Flutter puts half the spacing before each letter,
 * the browser puts it all after. Same width, letters shifted by half.
 */
export function letterSpacing(px: number): CSSProperties {
  return { letterSpacing: px, position: 'relative', left: px / 2 };
}

/**
 * Flutter rounds each text line to whole logical pixels, so a 14px line at
 * height 1.55 is 22px tall, not 21.7px. `height` defaults to the 20/14 that
 * Text inherits from Material's bodyMedium.
 */
export function lineHeight(size: number, height = 20 / 14): string {
  return `${Math.round(size * height)}px`;
}

/**
 * A line whose text falls back to another font (₱ is missing from Outfit, and
 * emoji): Flutter takes the tallest ascent and descent across the fonts, so
 * the line measures about 1px taller than `lineHeight`. Measured on Money
 * (₱ at 17px) and Subs (emoji at 10px).
 */
export function mixedLineHeight(size: number, height = 20 / 14): string {
  return `${Math.ceil(size * height)}px`;
}

/**
 * A border drawn inside the box the way Flutter's Container draws one.
 * Chrome snaps CSS border widths to whole pixels (1.5px renders as 1px), so
 * fractional widths are painted as an inset shadow instead. Pad the child by
 * the width yourself when the content is not centred.
 */
export function insetBorder(color: string, width: number): CSSProperties {
  return { boxShadow: `inset 0 0 0 ${width}px ${color}` };
}
