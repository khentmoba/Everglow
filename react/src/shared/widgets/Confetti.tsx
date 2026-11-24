// The confetti package's ConfettiWidget (explosive blast), drawn on a canvas.
import { useEffect, useRef } from 'react';
import { motionReduced } from '../../core/theme/motion';

type Particle = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  w: number;
  h: number;
  color: string;
  rot: number;
  vr: number;
  flip: number;
  vf: number;
};

/**
 * The confetti package's explosive blast from the top centre (gravity 0.2, drag 0.05).
 * Plays on mount, or each time `play` goes up when it is given.
 */
export function Confetti({
  colors,
  frequency = 0.02,
  particles: count = 10,
  duration = 3000,
  play,
}: {
  colors: string[];
  /** emissionFrequency: the chance of a burst each frame. */ frequency?: number;
  /** numberOfParticles per burst. */ particles?: number;
  duration?: number;
  play?: number;
}) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    if (play === 0 || motionReduced()) return;
    const el = canvas.current;
    const ctx = el?.getContext('2d');
    if (!el || !ctx) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const particles: Particle[] = [];
    const start = performance.now();
    let frame = 0;
    let raf = 0;
    const emit = () => {
      for (let i = 0; i < count; i++) {
        const angle = Math.random() * Math.PI * 2;
        const force = 5 + Math.random() * 15;
        particles.push({
          x: el.clientWidth / 2,
          y: 0,
          vx: Math.cos(angle) * force,
          vy: Math.sin(angle) * force,
          w: 20 + Math.random() * 10,
          h: 10 + Math.random() * 5,
          color: colors[Math.floor(Math.random() * colors.length)],
          rot: Math.random() * Math.PI * 2,
          vr: (Math.random() - 0.5) * 0.2,
          flip: Math.random() * Math.PI * 2,
          vf: 0.05 + Math.random() * 0.15,
        });
      }
    };
    const tick = (now: number) => {
      const w = el.clientWidth;
      const h = el.clientHeight;
      if (el.width !== Math.round(w * dpr) || el.height !== Math.round(h * dpr)) {
        el.width = Math.round(w * dpr);
        el.height = Math.round(h * dpr);
      }
      const emitting = now - start < duration;
      if (emitting && (frame === 0 || Math.random() < frequency)) emit();
      frame++;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);
      for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.vx -= p.vx * 0.05;
        p.vy -= p.vy * 0.05;
        p.vy += 0.2 * 1.5;
        p.x += p.vx;
        p.y += p.vy;
        p.rot += p.vr;
        p.flip += p.vf;
        if (p.y > h + 40) {
          particles.splice(i, 1);
          continue;
        }
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.rot);
        ctx.scale(1, Math.cos(p.flip));
        ctx.fillStyle = p.color;
        ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
        ctx.restore();
      }
      if (emitting || particles.length > 0) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [colors, frequency, count, duration, play]);
  return (
    <canvas
      ref={canvas}
      aria-hidden
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
    />
  );
}
