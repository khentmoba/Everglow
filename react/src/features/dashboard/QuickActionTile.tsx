import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { CssCurves, reduceAmbientMotion } from '../../core/theme/motion';
import { AppTypography } from '../../core/theme/typography';
import { HueGlyph } from '../../shared/widgets/HueGlyph';

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
        padding: '6px 2px 4px',
        borderRadius: 18,
        background: activeHover ? withAlpha(action.hue, 0.06) : 'transparent',
        transform: reduceAmbient ? undefined : `translateY(${activeHover ? -2 : 0}px) scale(${activePress ? 0.94 : 1})`,
        transition: `transform 180ms ${CssCurves.easeOutStrong}, background 180ms ${CssCurves.easeOutStrong}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        minWidth: 0,
      }}
    >
      <HueGlyph icon={action.icon} hue={action.hue} size={56} iconSize={24} />
      <span
        style={{
          ...AppTypography.outfitBold,
          marginTop: 8,
          fontSize: 12.5,
          lineHeight: 1.15,
          color: withAlpha(AppColors.petalWhite, hovered ? 1 : 0.9),
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          maxWidth: '100%',
        }}
      >
        {action.label}
      </span>
      {action.caption && (
        <span
          style={{
            ...AppTypography.handwrittenBody,
            fontSize: 14,
            lineHeight: 1.1,
            color: withAlpha(action.hue, hovered ? 0.95 : 0.72),
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            maxWidth: '100%',
          }}
        >
          {action.caption}
        </span>
      )}
    </button>
  );
}
