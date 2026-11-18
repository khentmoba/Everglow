// Port of lib/features/{academy,play_zone}/presentation/widgets/{academy,play_zone}_portal_card.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, boxShadow, linear, insetBorder } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

export function AcademyPortalCard() {
  return <PortalCard icon="school" title="Everglow Academy" buttonLabel="ENTER PORTAL" route="/academy" />;
}

export function PlayZonePortalCard() {
  return <PortalCard icon="sports_esports" title="Play Zone" buttonLabel="ENTER PLAY ZONE" route="/play-zone" />;
}

function PortalCard({
  icon,
  title,
  buttonLabel,
  route,
}: {
  icon: string;
  title: string;
  buttonLabel: string;
  route: string;
}) {
  const navigate = useNavigate();
  const [pressed, setPressed] = useState(false);

  return (
    <div style={{ padding: '16px 24px' }}>
      <div
        style={{
          position: 'relative',
          height: 220,
          borderRadius: 24,
          background: linear([
            withAlpha(AppColors.velvet, 0.72),
            withAlpha(AppColors.plum, 0.55),
          ], { begin: Align.topLeft, end: Align.bottomRight }),
          ...insetBorder(withAlpha(AppColors.blushGold, 0.25), 1.5),
          overflow: 'hidden',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div
          aria-hidden
          style={{
            position: 'absolute',
            top: -50,
            right: -50,
            width: 150,
            height: 150,
            borderRadius: '50%',
            background: withAlpha(AppColors.deepRose, 0.15),
            pointerEvents: 'none',
          }}
        />
        <div
          style={{
            position: 'relative',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={icon} size={50} color={AppColors.blushGold} />
          <div style={{ height: 12 }} />
          <span
            style={{
              ...AppTypography.cormorantBold,
              fontSize: 28,
              letterSpacing: '0.5px',
              textShadow: `0 0 15px ${withAlpha(AppColors.deepRose, 0.4)}`,
            }}
          >
            {title}
          </span>
          <div style={{ height: 20 }} />
          <button
            type="button"
            className="bare-button"
            aria-label={title === 'Play Zone' ? 'Enter Play Zone' : `Enter ${title}`}
            onMouseDown={() => setPressed(true)}
            onMouseUp={() => setPressed(false)}
            onMouseLeave={() => setPressed(false)}
            onClick={() => navigate(route)}
            style={{
              padding: '14px 40px',
              background: linear([AppColors.deepRose, AppColors.blushGold]),
              borderRadius: 24,
              boxShadow: boxShadow([{ offset: [0, 4], blur: 10, color: withAlpha(AppColors.deepRose, 0.3) }]),
              transform: pressed ? 'scale(0.95)' : 'scale(1)',
              transition: 'transform 120ms ease',
            }}
          >
            <span
              style={{
                ...AppTypography.outfitWhite,
                fontWeight: 900,
                color: AppColors.petalWhite,
                letterSpacing: '2px',
              }}
            >
              {buttonLabel}
            </span>
          </button>
        </div>
      </div>
    </div>
  );
}
