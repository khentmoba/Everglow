// Port of lib/features/academy/presentation/screens/podium_screen.dart.
import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { ErrorPage } from '../../core/router/ErrorPage';
import { useAuth } from '../../core/services/auth';
import { useBoxSize } from '../../core/system/useBoxSize';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Align, linear, shadowLayer, sigma } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { Confetti } from '../../shared/widgets/Confetti';
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
