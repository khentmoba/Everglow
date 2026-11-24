// Port of lib/features/entry/presentation/widgets/petal_shower.dart.
import { useEffect, useRef, useState } from 'react';
import { reduceAmbientMotion } from '../../core/system/device';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';

type Petal = { x: number; y: number; size: number; speed: number; angle: number; drift: number };

const PETAL_COUNT = 30;
const SHAPE = 15;

function makePetals(): Petal[] {
  return Array.from({ length: PETAL_COUNT }, () => ({
    x: Math.random(),
    y: Math.random() * -1,
    size: Math.random() * 15 + 10,
    speed: Math.random() * 0.5 + 0.5,
    angle: Math.random() * Math.PI * 2,
    drift: (Math.random() - 0.5) * 0.2,
  }));
}

/** Dart's `%` never returns a negative number. */
const mod = (a: number, n: number) => ((a % n) + n) % n;

export function PetalShower({ isVisible }: { isVisible: boolean }) {
  const viewport = useViewport();
  const ref = useRef<HTMLCanvasElement>(null);
  const [petals] = useState(makePetals);
  const show = isVisible && !reduceAmbientMotion(viewport);

  useEffect(() => {
    if (!show) return;
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const shape = new Path2D(`M0 0 Q${SHAPE / 2} ${-SHAPE} ${SHAPE} 0 Q${SHAPE / 2} ${SHAPE} 0 0`);
    const color = withAlpha(AppColors.roseQuartz, 0.6);
    let frame = 0;
    let start = -1;
    const draw = (now: number) => {
      if (document.hidden) {
        frame = 0;
        return;
      }
      if (start < 0) start = now;
      const progress = ((now - start) % 4000) / 4000;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
        canvas.width = Math.round(w * dpr);
        canvas.height = Math.round(h * dpr);
      }
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = color;
      for (const p of petals) {
        const y = mod(p.y + progress * p.speed, 1.5) - 0.2;
        const x = mod(p.x + Math.sin(progress * Math.PI * 2 + p.angle) * p.drift, 1.0);
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.translate(x * w, y * h);
        ctx.rotate(progress * Math.PI * 2 + p.angle);
        ctx.scale(p.size / SHAPE, p.size / SHAPE);
        ctx.fill(shape);
      }
      frame = requestAnimationFrame(draw);
    };
    const onVisibility = () => {
      if (document.hidden) {
        if (frame) {
          cancelAnimationFrame(frame);
          frame = 0;
        }
      } else if (!frame) {
        frame = requestAnimationFrame(draw);
      }
    };
    if (!document.hidden) frame = requestAnimationFrame(draw);
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      cancelAnimationFrame(frame);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [show, petals]);

  if (!show) return null;
  return <canvas ref={ref} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }} />;
}
