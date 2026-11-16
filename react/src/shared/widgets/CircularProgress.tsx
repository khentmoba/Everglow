// Flutter's indeterminate CircularProgressIndicator (Material 3, 2023 look),
// drawn with the same head/tail/rotation math as the Flutter painter.
import { useEffect, useRef } from 'react';
import { cubic } from '../../core/theme/motion';

const fastOutSlowIn = cubic(0.4, 0.0, 0.2, 1.0);
const interval = (t: number, a: number, b: number) => fastOutSlowIn(Math.min(1, Math.max(0, (t - a) / (b - a))));

export function CircularProgress({ size, strokeWidth, color }: { size: number; strokeWidth: number; color: string }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current!;
    const dpr = window.devicePixelRatio || 1;
    const pad = strokeWidth;
    canvas.width = (size + pad * 2) * dpr;
    canvas.height = (size + pad * 2) * dpr;
    const ctx = canvas.getContext('2d')!;
    let frame = 0;
    const start = performance.now();
    const draw = (now: number) => {
      const ms = now - start;
      const p = (ms % 1333) / 1333;
      const head = interval(p, 0, 0.5);
      const tail = interval(p, 0.5, 1);
      const rotation = (ms % 2222) / 2222;
      const arcStart = -Math.PI / 2 + tail * 1.5 * Math.PI + rotation * 2 * Math.PI + p * 0.5 * Math.PI;
      const sweep = Math.max(head * 1.5 * Math.PI - tail * 1.5 * Math.PI, 0.001);
      ctx.setTransform(dpr, 0, 0, dpr, pad * dpr, pad * dpr);
      ctx.clearRect(-pad, -pad, size + pad * 2, size + pad * 2);
      ctx.strokeStyle = color;
      ctx.lineWidth = strokeWidth;
      ctx.lineCap = 'square';
      ctx.beginPath();
      ctx.arc(size / 2, size / 2, size / 2, arcStart, arcStart + sweep);
      ctx.stroke();
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, [size, strokeWidth, color]);
  return (
    <canvas
      ref={ref}
      aria-hidden
      style={{ width: size + strokeWidth * 2, height: size + strokeWidth * 2, margin: -strokeWidth, display: 'block' }}
    />
  );
}
