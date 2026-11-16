// Port of lib/features/dashboard/presentation/widgets/dashboard_motion.dart.
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Curves, motionReduced, reduceAmbientMotion } from '../../core/theme/motion';

export function BreathingEmblem({ children }: { children: ReactNode }) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const [breath, setBreath] = useState(0);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (reduceAmbient) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const cycle = ((now - start) % 6800) / 3400;
      const b = cycle <= 1 ? cycle : 2 - cycle;
      setBreath(b);

      const canvas = canvasRef.current;
      if (canvas) {
        const dpr = window.devicePixelRatio || 1;
        const size = 132;
        if (canvas.width !== size * dpr) {
          canvas.width = size * dpr;
          canvas.height = size * dpr;
        }
        const ctx = canvas.getContext('2d');
        if (ctx) {
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
          ctx.clearRect(0, 0, size, size);
          const cx = size / 2;
          const cy = size / 2;
          const radius = size / 2 - 4;
          const rot = (((now - start) % 14000) / 14000) * Math.PI * 2;

          ctx.strokeStyle = withAlpha(AppColors.blushGold, 0.22);
          ctx.lineWidth = 1.1;
          ctx.beginPath();
          ctx.arc(cx, cy, radius, 0, Math.PI * 2);
          ctx.stroke();

          ctx.save();
          ctx.translate(cx, cy);
          ctx.rotate(rot);
          const sweep = ctx.createConicGradient(0, 0, 0);
          sweep.addColorStop(0, 'rgba(0,0,0,0)');
          sweep.addColorStop(0.18, AppColors.auroraRose);
          sweep.addColorStop(0.42, AppColors.blushGold);
          sweep.addColorStop(0.6, 'rgba(0,0,0,0)');
          sweep.addColorStop(1, 'rgba(0,0,0,0)');
          ctx.strokeStyle = sweep;
          ctx.lineWidth = 1.7;
          ctx.lineCap = 'round';
          ctx.beginPath();
          ctx.arc(0, 0, radius, 0, Math.PI * 2);
          ctx.stroke();
          ctx.restore();

          const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
          grad.addColorStop(0, withAlpha(AppColors.deepRose, 0.07));
          grad.addColorStop(1, withAlpha(AppColors.deepRose, 0));
          ctx.fillStyle = grad;
          ctx.beginPath();
          ctx.arc(cx, cy, radius * 0.88, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reduceAmbient]);

  if (reduceAmbient) return <>{children}</>;

  const scale = 1 + 0.032 * (breath * 2 - 1);
  return (
    <div style={{ position: 'relative', width: 132, height: 132, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <canvas ref={canvasRef} style={{ position: 'absolute', inset: 0, width: 132, height: 132, pointerEvents: 'none' }} aria-hidden />
      <div style={{ transform: `scale(${scale.toFixed(4)})` }}>{children}</div>
    </div>
  );
}

export function ShimmerTitle({ children }: { children: ReactNode }) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const [offset, setOffset] = useState(-1);

  useEffect(() => {
    if (reduceAmbient) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const t = ((now - start) % 4200) / 4200;
      setOffset(t * 2 - 1);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reduceAmbient]);

  if (reduceAmbient) return <>{children}</>;
  const pct = 50 + offset * 80;
  return (
    <div
      style={{
        backgroundImage: `linear-gradient(90deg, ${AppColors.petalWhite} ${pct - 50}%, ${AppColors.blushGold} ${pct}%, ${AppColors.petalWhite} ${pct + 50}%)`,
        WebkitBackgroundClip: 'text',
        backgroundClip: 'text',
        color: 'transparent',
      }}
    >
      {children}
    </div>
  );
}

export function PulseHeart({ children }: { children: ReactNode }) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const [p, setP] = useState(0);

  useEffect(() => {
    if (reduceAmbient) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      setP(((now - start) % 2600) / 2600);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reduceAmbient]);

  if (reduceAmbient) return <>{children}</>;

  const beat = p < 0.45 ? Curves.easeOutBack(p / 0.45) : 1;
  const glow = p < 0.45 ? (1 - p / 0.45) * 0.45 : 0;
  return (
    <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
      <div
        style={{
          position: 'absolute',
          width: 15,
          height: 15,
          borderRadius: '50%',
          boxShadow: `0 0 9.7px 2px ${withAlpha(AppColors.auroraRose, glow)}`,
          pointerEvents: 'none',
        }}
        aria-hidden
      />
      <div style={{ transform: `scale(${(1 + 0.22 * beat).toFixed(4)})` }}>{children}</div>
    </div>
  );
}

const PETAL_PALETTE = [
  AppColors.roseQuartz,
  AppColors.auroraRose,
  AppColors.blushGold,
  AppColors.softLavender,
  AppColors.moonlight,
];

const SPARKLE_PALETTE = [
  AppColors.auroraGold,
  AppColors.blushGold,
  AppColors.moonlight,
  AppColors.auroraRose,
  AppColors.softLavender,
];

const frac = (v: number) => v - Math.floor(v);
const rand = (seed: number) => frac(Math.sin(seed * 12.9898 + 78.233) * 43758.5453);

const PETALS = Array.from({ length: 14 }, (_, i) => ({
  phase: rand(i + 7),
  speed: 0.5 + rand(i + 11) * 0.4,
  drift: 0.02 + rand(i + 13) * 0.05,
  swayFreq: 1 + rand(i + 17) * 2,
  swayAmp: 0.02 + rand(i + 19) * 0.05,
  swayPhase: rand(i + 23) * Math.PI * 2,
  tilt: rand(i + 29) * Math.PI * 2,
  rotTurns: 0.5 + rand(i + 31) * 1.2,
  size: 9 + rand(i + 37) * 13,
  alpha: 0.11 + rand(i + 41) * 0.09,
  baseX: 0.04 + rand(i + 43) * 0.92,
  color: PETAL_PALETTE[i % PETAL_PALETTE.length],
}));

const SPARKLES = Array.from({ length: 8 }, (_, i) => ({
  phase: rand(i + 5),
  speed: 0.35 + rand(i + 9) * 0.3,
  baseX: 0.06 + rand(i + 15) * 0.88,
  swayFreq: 1.5 + rand(i + 21) * 2,
  swayAmp: 0.01 + rand(i + 25) * 0.04,
  twinkle: 6 + rand(i + 31) * 10,
  radius: 2.5 + rand(i + 33) * 3,
  peak: 0.1 + rand(i + 47) * 0.14,
  color: SPARKLE_PALETTE[i % SPARKLE_PALETTE.length],
}));

const BANDS = [
  { baseY: 0.24, amp: 0.1, wave: 0.55, speed: 0.16, drift: 0.05, width: 0.16, alpha: 0.05, color: AppColors.auroraRose },
  { baseY: 0.52, amp: 0.11, wave: 0.35, speed: 0.1, drift: 0.03, width: 0.2, alpha: 0.045, color: AppColors.softLavender },
  { baseY: 0.8, amp: 0.08, wave: 0.7, speed: 0.2, drift: 0.04, width: 0.13, alpha: 0.05, color: AppColors.auroraGold },
];

export function DashboardAmbience({ scrollTop }: { scrollTop: number }) {
  const { width, height } = useViewport();
  const reduced = motionReduced();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (reduced || reduceAmbient || scrollTop > 850) return;
    let raf = 0;
    const start = performance.now();
    let lastDraw = 0;
    const tick = (now: number) => {
      raf = requestAnimationFrame(tick);
      if (now - lastDraw < 33) return;
      lastDraw = now;
      const canvas = canvasRef.current;
      if (!canvas) return;
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      if (w <= 0 || h <= 0) return;
      const dpr = window.devicePixelRatio || 1;
      if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
        canvas.width = Math.round(w * dpr);
        canvas.height = Math.round(h * dpr);
      }
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);

      const t = ((now - start) % 24000) / 24000;

      for (const band of BANDS) {
        const sw = band.width * h;
        const grad = ctx.createLinearGradient(0, 0, w, 0);
        grad.addColorStop(0, withAlpha(band.color, 0));
        grad.addColorStop(0.5, withAlpha(band.color, band.alpha));
        grad.addColorStop(1, withAlpha(band.color, 0));
        ctx.strokeStyle = grad;
        ctx.lineWidth = sw;
        ctx.lineCap = 'round';
        ctx.beginPath();
        const step = w / 28;
        const driftX = t * w * band.drift;
        for (let i = 0; i <= 28; i++) {
          const x = i * step + driftX;
          const nx = x / w;
          const y =
            band.baseY * h +
            Math.sin(nx * Math.PI * 2 * band.wave + t * Math.PI * 2 * band.speed) * band.amp * h +
            Math.sin(nx * Math.PI * 4 * band.wave + t * Math.PI * 2 * band.speed * 1.7) * band.amp * h * 0.45;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
      }

      const scale = Math.max(0.6, Math.min(1.6, Math.min(w, h) / 900));
      for (const s of SPARKLES) {
        const p = frac(t * s.speed + s.phase);
        const y = h * (1 - p) - 40;
        const x = s.baseX * w + Math.sin(t * Math.PI * 2 * s.swayFreq + s.phase * 7) * s.swayAmp * w;
        const twinkle = 0.72 + 0.28 * Math.sin(t * Math.PI * 2 * s.twinkle);
        const fade = p < 0.06 ? p / 0.06 : p > 0.94 ? (1 - p) / 0.06 : 1;
        const k = twinkle * fade;
        if (k <= 0.02) continue;
        const r = s.radius * scale * k;
        const g = ctx.createRadialGradient(x, y, 0, x, y, r * 1.6);
        g.addColorStop(0, withAlpha(s.color, s.peak));
        g.addColorStop(0.4, withAlpha(s.color, s.peak * 0.35));
        g.addColorStop(1, withAlpha(s.color, 0));
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.fill();
      }

      const maxTrails = w < 600 ? 1 : 3;
      for (const petal of PETALS) {
        for (let g = 0; g < maxTrails; g++) {
          const dt = g === 0 ? 0 : g === 1 ? 0.006 : 0.013;
          const p = frac(t * petal.speed + petal.phase - dt);
          const y = h * (1 - p) - petal.size;
          const x =
            frac(petal.baseX + t * petal.drift) * w +
            Math.sin(t * Math.PI * 2 * petal.swayFreq + petal.swayPhase) * petal.swayAmp * w;
          const angle = petal.tilt + p * petal.rotTurns * Math.PI * 2;
          const ps = petal.size * (g === 0 ? 1 : 1 - g * 0.22);
          let alpha = petal.alpha * (g === 0 ? 1 : Math.pow(0.45, g));
          const edgeFade = p < 0.05 ? p / 0.05 : p > 0.95 ? (1 - p) / 0.05 : 1;
          alpha *= edgeFade;
          if (alpha <= 0.01) continue;
          ctx.save();
          ctx.translate(x, y);
          ctx.rotate(angle);
          ctx.scale(ps, ps);
          ctx.fillStyle = withAlpha(petal.color, alpha);
          ctx.beginPath();
          ctx.moveTo(0, -1);
          ctx.bezierCurveTo(0.42, -0.52, 0.36, 0.02, 0, 0.6);
          ctx.bezierCurveTo(-0.36, 0.02, -0.42, -0.52, 0, -1);
          ctx.closePath();
          ctx.fill();
          if (g === 0) {
            ctx.strokeStyle = withAlpha(AppColors.petalWhite, alpha * 0.45);
            ctx.lineWidth = 0.14;
            ctx.lineCap = 'round';
            ctx.beginPath();
            ctx.moveTo(0, -0.9);
            ctx.lineTo(0, 0.3);
            ctx.stroke();
          }
          ctx.restore();
        }
      }
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reduced, reduceAmbient, scrollTop]);

  if (reduced || reduceAmbient) return null;
  return (
    <canvas
      ref={canvasRef}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
      aria-hidden
    />
  );
}
