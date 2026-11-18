// Port of drawOrigamiStar (star_widget.dart), web branch: flat glow and core
// circles, ten lit facets, five creases and an optional four-point sparkle.
import { AppColors } from '../../core/theme/colors';

type Rgb = [number, number, number];

const rgb = (hex: string): Rgb => {
  const n = parseInt(hex.slice(1, 7), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};
const css = ([r, g, b]: Rgb, a: number) => `rgba(${r},${g},${b},${Math.min(1, Math.max(0, a))})`;
const lerp = (a: Rgb, b: Rgb, t: number): Rgb => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

const WHITE = rgb(AppColors.petalWhite);
const INK = rgb(AppColors.inkDeep);

/** Draws a star centred on the context's origin. */
export function drawOrigamiStar(
  ctx: CanvasRenderingContext2D,
  {
    color,
    size,
    opacity = 1,
    glowIntensity = 1,
    sparkle = 0,
  }: { color: string; size: number; opacity?: number; glowIntensity?: number; sparkle?: number },
) {
  const o = clamp(opacity, 0, 1);
  if (o <= 0.001) return;
  const c = rgb(color);
  const outer = size * 0.5;
  const inner = size * 0.26;
  const glow = size * 1.25;
  const circle = (r: number, fill: string) => {
    ctx.fillStyle = fill;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
  };

  if (glowIntensity > 0.05) {
    circle(glow, css(c, 0.12 * glowIntensity * o));
    circle(glow * 0.68, css(c, 0.24 * glowIntensity * o));
  }

  const points = 5;
  const tips = Array.from({ length: points }, (_, i) => {
    const a = -Math.PI / 2 + (i * 2 * Math.PI) / points;
    return [Math.cos(a) * outer, Math.sin(a) * outer];
  });
  const valleys = Array.from({ length: points }, (_, i) => {
    const a = -Math.PI / 2 + (i * 2 * Math.PI) / points + Math.PI / points;
    return [Math.cos(a) * inner, Math.sin(a) * inner];
  });
  const facet = (factor: number, a: number[], b: number[]) => {
    const shade = factor >= 0 ? lerp(c, WHITE, factor) : lerp(c, INK, -factor * 0.45);
    ctx.fillStyle = css(shade, o);
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(a[0], a[1]);
    ctx.lineTo(b[0], b[1]);
    ctx.closePath();
    ctx.fill();
  };
  for (let i = 0; i < points; i++) {
    const angle = -Math.PI / 2 + (i * 2 * Math.PI) / points;
    const light = -0.5 * Math.cos(angle) - 0.7 * Math.sin(angle);
    facet(clamp(0.15 + light * 0.18 - 0.1, -0.2, 0.35), tips[i], valleys[i]);
    facet(clamp(0.28 + light * 0.2 + 0.12, -0.12, 0.45), valleys[(i - 1 + points) % points], tips[i]);
  }

  ctx.strokeStyle = css(WHITE, 0.32 * o);
  ctx.lineWidth = 0.65;
  for (const [x, y] of tips) {
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(x, y);
    ctx.stroke();
  }

  const core = size * 0.16;
  circle(core, css(c, 0.45 * o));
  circle(core * 0.55, css(WHITE, 0.75 * o));
  circle(size * 0.05, css(WHITE, 0.9 * o));

  if (sparkle > 0.05) {
    const len = size * 0.55 * sparkle;
    const width = size * 0.11 * sparkle;
    ctx.fillStyle = css(WHITE, 0.85 * sparkle * o);
    ctx.beginPath();
    ctx.moveTo(0, -len);
    ctx.quadraticCurveTo(0, 0, width, 0);
    ctx.quadraticCurveTo(0, 0, 0, len);
    ctx.quadraticCurveTo(0, 0, -width, 0);
    ctx.quadraticCurveTo(0, 0, 0, -len);
    ctx.closePath();
    ctx.fill();
  }
}
