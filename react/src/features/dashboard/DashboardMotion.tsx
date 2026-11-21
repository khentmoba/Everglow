// Port of lib/features/dashboard/presentation/widgets/dashboard_motion.dart.
import { useEffect, useRef, type ReactNode, type RefObject } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { motionReduced, reduceAmbientMotion } from '../../core/theme/motion';

export function BreathingEmblem({ children }: { children: ReactNode }) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);

  if (reduceAmbient) return <>{children}</>;

  return (
    <div style={{ position: 'relative', width: 132, height: 132, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 4,
          borderRadius: '50%',
          border: `1.1px solid ${withAlpha(AppColors.blushGold, 0.22)}`,
          background: `radial-gradient(circle, ${withAlpha(AppColors.deepRose, 0.07)} 0%, ${withAlpha(AppColors.deepRose, 0)} 88%)`,
          pointerEvents: 'none',
        }}
      />
      <div
        aria-hidden
        className="emblem-spin"
        style={{
          position: 'absolute',
          inset: 3,
          borderRadius: '50%',
          background: `conic-gradient(from 0deg, transparent 0%, ${AppColors.auroraRose} 18%, ${AppColors.blushGold} 42%, transparent 60%, transparent 100%)`,
          WebkitMaskImage: 'radial-gradient(farthest-side, transparent calc(100% - 2px), #000 calc(100% - 1.5px))',
          maskImage: 'radial-gradient(farthest-side, transparent calc(100% - 2px), #000 calc(100% - 1.5px))',
          pointerEvents: 'none',
        }}
      />
      <div className="emblem-breath">{children}</div>
    </div>
  );
}

export function ShimmerTitle({ children }: { children: ReactNode }) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);

  if (reduceAmbient) return <>{children}</>;
  return (
    <div
      className="title-shimmer"
      style={{
        backgroundImage: `linear-gradient(90deg, ${AppColors.petalWhite} 25%, ${AppColors.blushGold} 50%, ${AppColors.petalWhite} 75%)`,
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

  if (reduceAmbient) return <>{children}</>;

  return (
    <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
      <div
        className="heart-glow"
        style={{
          position: 'absolute',
          width: 15,
          height: 15,
          borderRadius: '50%',
          boxShadow: `0 0 9.7px 2px ${withAlpha(AppColors.auroraRose, 0.45)}`,
          pointerEvents: 'none',
        }}
        aria-hidden
      />
      <div className="heart-pulse">{children}</div>
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

export function DashboardAmbience({ scrollRef }: { scrollRef: RefObject<HTMLDivElement | null> }) {
  const { width, height } = useViewport();
  const reduced = motionReduced();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (reduced || reduceAmbient) return;
    let raf = 0;
    let scrollSettleTimer = 0;
    let pausedByScroll = (scrollRef.current?.scrollTop ?? 0) > 850;
    let activelyScrolling = false;
    const start = performance.now();
    let lastDraw = 0;
    let cachedW = 0;
    let bandGrads: CanvasGradient[] = [];
    const sparkleSprites = SPARKLES.map((s) => {
      const sprite = document.createElement('canvas');
      const size = 64;
      const half = size / 2;
      sprite.width = size;
      sprite.height = size;
      const sctx = sprite.getContext('2d');
      if (sctx) {
        const g = sctx.createRadialGradient(half, half, 0, half, half, half);
        g.addColorStop(0, withAlpha(s.color, s.peak));
        g.addColorStop(0.4, withAlpha(s.color, s.peak * 0.35));
        g.addColorStop(1, withAlpha(s.color, 0));
        sctx.fillStyle = g;
        sctx.beginPath();
        sctx.arc(half, half, half / 1.6, 0, Math.PI * 2);
        sctx.fill();
      }
      return sprite;
    });

    const draw = (now: number) => {
      if (pausedByScroll || activelyScrolling || document.hidden) {
        raf = 0;
        return;
      }
      raf = requestAnimationFrame(draw);
      if (now - lastDraw < 42) return;
      lastDraw = now;
      const canvas = canvasRef.current;
      if (!canvas) return;
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      if (w <= 0 || h <= 0) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      const pw = Math.round(w * dpr);
      const ph = Math.round(h * dpr);
      if (canvas.width !== pw || canvas.height !== ph) {
        canvas.width = pw;
        canvas.height = ph;
        cachedW = 0;
      }
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      if (cachedW !== w) {
        cachedW = w;
        bandGrads = BANDS.map((band) => {
          const grad = ctx.createLinearGradient(0, 0, w, 0);
          grad.addColorStop(0, withAlpha(band.color, 0));
          grad.addColorStop(0.5, withAlpha(band.color, band.alpha));
          grad.addColorStop(1, withAlpha(band.color, 0));
          return grad;
        });
      }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);

      const t = ((now - start) % 24000) / 24000;

      for (let bi = 0; bi < BANDS.length; bi++) {
        const band = BANDS[bi];
        ctx.strokeStyle = bandGrads[bi];
        ctx.lineWidth = band.width * h;
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
      for (let si = 0; si < SPARKLES.length; si++) {
        const s = SPARKLES[si];
        const p = frac(t * s.speed + s.phase);
        const y = h * (1 - p) - 40;
        const x = s.baseX * w + Math.sin(t * Math.PI * 2 * s.swayFreq + s.phase * 7) * s.swayAmp * w;
        const twinkle = 0.72 + 0.28 * Math.sin(t * Math.PI * 2 * s.twinkle);
        const fade = p < 0.06 ? p / 0.06 : p > 0.94 ? (1 - p) / 0.06 : 1;
        const k = twinkle * fade;
        if (k <= 0.02) continue;
        const r = s.radius * scale * k;
        const halfDraw = r * 1.6;
        ctx.drawImage(sparkleSprites[si], x - halfDraw, y - halfDraw, halfDraw * 2, halfDraw * 2);
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

    const ensureRunning = () => {
      if (!raf && !pausedByScroll && !activelyScrolling && !document.hidden) {
        raf = requestAnimationFrame(draw);
      }
    };

    const onScroll = () => {
      const top = scrollRef.current?.scrollTop ?? 0;
      pausedByScroll = top > 850;
      activelyScrolling = true;
      window.clearTimeout(scrollSettleTimer);
      scrollSettleTimer = window.setTimeout(() => {
        activelyScrolling = false;
        ensureRunning();
      }, 140);
    };

    const onVis = () => ensureRunning();
    const scroller = scrollRef.current;
    scroller?.addEventListener('scroll', onScroll, { passive: true });
    document.addEventListener('visibilitychange', onVis);
    ensureRunning();

    return () => {
      cancelAnimationFrame(raf);
      window.clearTimeout(scrollSettleTimer);
      scroller?.removeEventListener('scroll', onScroll);
      document.removeEventListener('visibilitychange', onVis);
    };
  }, [reduced, reduceAmbient, scrollRef]);

  if (reduced || reduceAmbient) return null;
  return (
    <canvas
      ref={canvasRef}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
      aria-hidden
    />
  );
}
