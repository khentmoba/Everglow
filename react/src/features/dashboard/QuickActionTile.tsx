// Port of lib/features/dashboard/presentation/widgets/quick_action_tile.dart.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { reduceAmbientMotion } from '../../core/theme/motion';
import { boxShadow, letterSpacing } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

export type QuickAction = {
  label: string;
  caption?: string;
  icon: string;
  route: string;
  hue: string;
};

export function QuickActionTile({ action }: { action: QuickAction }) {
  const navigate = useNavigate();
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);

  const activeHover = hovered && !reduceAmbient;
  const activePress = pressed && !reduceAmbient;

  return (
    <button
      type="button"
      className="bare-button"
      aria-label={action.label}
      onMouseEnter={() => !reduceAmbient && setHovered(true)}
      onMouseLeave={() => {
        setHovered(false);
        setPressed(false);
      }}
      onPointerDown={() => !reduceAmbient && setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerCancel={() => setPressed(false)}
      onClick={() => navigate(action.route)}
      style={{
        width: '100%',
        overflow: 'hidden',
        padding: '12px 10px 10px',
        borderRadius: AppRadius.lg,
        background: activeHover ? withAlpha(AppColors.velvet, 0.42) : Derived.surfaceGlass,
        border: `1px solid ${activeHover ? withAlpha(action.hue, 0.3) : withAlpha(AppColors.moonlight, 0.07)}`,
        boxShadow: activeHover ? boxShadow([{ color: withAlpha(action.hue, 0.1), blur: 10, offset: [0, 3] }]) : undefined,
        transform: reduceAmbient
          ? undefined
          : `translateY(${activeHover ? -2 : 0}px) scale(${activePress ? 0.94 : 1})`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          width: 40,
          height: 40,
          marginTop: 2,
          borderRadius: '50%',
          background: withAlpha(action.hue, 0.1),
          border: `1px solid ${withAlpha(action.hue, hovered ? 0.48 : 0.28)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={action.icon} size={16} color={action.hue} />
      </div>
      <div style={{ height: 10 }} />
      <span
        style={{
          ...AppTypography.outfitHeading,
          fontSize: 11,
          color: hovered ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.88),
          letterSpacing: 0.1,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          maxWidth: '100%',
        }}
      >
        {action.label}
      </span>
      {action.caption && (
        <>
          <div style={{ height: 2 }} />
          <span
            style={{
              ...AppTypography.outfitBold,
              fontSize: 9,
              ...letterSpacing(0.9),
              color: hovered ? action.hue : Derived.textMuted,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              maxWidth: '100%',
            }}
          >
            {action.caption.toUpperCase()}
          </span>
        </>
      )}
    </button>
  );
}
