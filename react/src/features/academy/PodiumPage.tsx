// Port of lib/features/academy/presentation/screens/podium_screen.dart.
import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { ErrorPage } from '../../core/router/ErrorPage';
import { useAuth } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { motionReduced } from '../../core/theme/motion';
import { Align, linear, shadowLayer, sigma } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { Icon } from '../../shared/widgets/Icon';
import { displayNameFor, type GameMatch } from './academyService';
import { useRoseGold } from './SoloStudyPage';

const CONFETTI_COLORS = [AppColors.auroraRose, AppColors.auroraGold, AppColors.auroraLilac, AppColors.petalWhite];
const glow = (color: string, blur: number) => `0 0 ${2 * sigma(blur)}px ${color}`;

export function PodiumPage() {
  const match = (useLocation().state as { match?: GameMatch } | null)?.match;
  if (!match) return <ErrorPage />;
  return <Podium match={match} />;
}

function Podium({ match }: { match: GameMatch }) {
  const auth = useAuth();
  const navigate = useNavigate();
  const isWinner = match.winnerId === auth.currentUser;
  const isDraw = match.winnerId === 'draw';
  const title = isDraw ? "It's a Draw!" : isWinner ? 'Victory!' : 'Good Effort!';
  const subtitle = isDraw ? 'Both of you are amazing!' : isWinner ? 'You dominated the match!' : 'Better luck next time!';

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.auroraGold, alignment: [0, -0.7], size: 1.0, opacity: 0.16 },
          { color: AppColors.deepRose, alignment: [-0.8, 0.9], size: 0.8, opacity: 0.14 },
        ]}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <PodiumIcon icon={isDraw ? 'handshake' : isWinner ? 'emoji_events' : 'sentiment_satisfied'} />
        <div style={{ height: 30 }} />
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 42,
            fontWeight: 900,
            color: AppColors.auroraRose,
            textShadow: glow(withAlpha(AppColors.auroraGold, 0.6), 24),
          }}
        >
          {title}
        </span>
        <span style={{ ...AppTypography.outfitWhite, fontSize: 18, color: withAlpha(AppColors.roseQuartz, 0.85) }}>
          {subtitle}
        </span>
        <div style={{ height: 50 }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <ScoreDisplay name={displayNameFor(match.hostUsername)} score={match.hostScore} />
          <span style={{ padding: '0 30px', fontSize: 32, fontWeight: 700, color: '#FFF5F566' }}>-</span>
          <ScoreDisplay name={displayNameFor(match.participantUsername)} score={match.guestScore} />
        </div>
        <div style={{ height: 60 }} />
        <ReturnButton onPressed={() => navigate(-1)} />
      </div>
      <Confetti colors={CONFETTI_COLORS} />
    </div>
  );
}

function PodiumIcon({ icon }: { icon: string }) {
  const [ref, size] = useBoxSize<HTMLDivElement>();
  return (
    <div style={{ position: 'relative', width: 150, height: 150 }}>
      <div
        aria-hidden
        style={shadowLayer({ color: withAlpha(AppColors.auroraGold, 0.35), blur: 34, spread: -4 }, { circle: true })}
      />
      <div
        ref={ref}
        style={{
          position: 'relative',
          width: 150,
          height: 150,
          borderRadius: '50%',
          background: linear([withAlpha(AppColors.velvet, 0.9), withAlpha(AppColors.inkDeep, 0.95)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            size,
          }),
          boxShadow: `inset 0 0 0 1.5px ${withAlpha(AppColors.auroraGold, 0.55)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <span style={{ display: 'flex', filter: `drop-shadow(${glow(withAlpha(AppColors.auroraGold, 0.6), 18)})` }}>
          <Icon name={icon} size={80} color={AppColors.auroraGold} />
        </span>
      </div>
    </div>
  );
}

function ScoreDisplay({ name, score }: { name: string; score: number }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <span style={{ ...AppTypography.outfitWhite, fontSize: 18, fontWeight: 700, color: withAlpha(AppColors.petalWhite, 0.7) }}>
        {name}
      </span>
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 48,
          fontWeight: 900,
          color: AppColors.auroraGold,
          textShadow: glow(withAlpha(AppColors.auroraGold, 0.5), 14),
        }}
      >
        {score}
      </span>
    </div>
  );
}

function ReturnButton({ onPressed }: { onPressed: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [ref, gradient] = useRoseGold<HTMLButtonElement>();
  return (
    <div style={{ position: 'relative', transform: `scale(${hovered ? 1.04 : 1})`, transition: 'transform 200ms linear' }}>
      <div aria-hidden style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.4), blur: 20 }, { radius: AppRadius.full })} />
      <button
        ref={ref}
        type="button"
        className="bare-button"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          position: 'relative',
          padding: '17px 37px',
          background: gradient,
          borderRadius: AppRadius.full,
          boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.petalWhite, 0.4)}`,
          cursor: 'pointer',
        }}
      >
        <span style={{ ...AppTypography.outfitWhite, fontSize: 16, fontWeight: 700, color: AppColors.petalWhite }}>
          Return to Hub
        </span>
      </button>
    </div>
  );
}

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

/** The confetti package's explosive blast from the top centre: 3s of bursts, gravity 0.2, drag 0.05. */
function Confetti({ colors }: { colors: string[] }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    if (motionReduced()) return;
    const el = canvas.current;
    const ctx = el?.getContext('2d');
    if (!el || !ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const particles: Particle[] = [];
    const start = performance.now();
    let frame = 0;
    let raf = 0;
    const emit = () => {
      for (let i = 0; i < 10; i++) {
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
      const emitting = now - start < 3000;
      if (emitting && (frame === 0 || Math.random() < 0.02)) emit();
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
  }, [colors]);
  return (
    <canvas
      ref={canvas}
      aria-hidden
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
    />
  );
}
