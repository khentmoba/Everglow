import { useState } from 'react';
import { useNavigate } from 'react-router';
import { prefetchRoute } from '../../core/router/routeChunks';
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

export function QuickActionTile({ action, badge = 0 }: { action: QuickAction; badge?: number }) {
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
      aria-label={badge > 0 ? `${action.label}, ${badge} new` : action.label}
      onMouseEnter={() => {
        prefetchRoute(action.route);
        if (!reduceAmbient) setHovered(true);
      }}
      onFocus={() => prefetchRoute(action.route)}
      onTouchStart={() => prefetchRoute(action.route)}
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
      <div style={{ position: 'relative' }}>
        <HueGlyph icon={action.icon} hue={action.hue} size={56} iconSize={24} />
        {badge > 0 && (
          <span
            aria-hidden
            style={{
              position: 'absolute',
              top: -5,
              right: -7,
              minWidth: 20,
              height: 20,
              padding: '0 6px',
              boxSizing: 'border-box',
              borderRadius: 999,
              background: AppColors.deepRose,
              boxShadow: `0 0 0 2px ${AppColors.inkDeep}, 0 2px 10px ${withAlpha(AppColors.deepRose, 0.6)}`,
              ...AppTypography.outfitBold,
              fontSize: 11,
              lineHeight: '20px',
              textAlign: 'center',
              color: AppColors.petalWhite,
            }}
          >
            {badge > 9 ? '9+' : badge}
          </span>
        )}
      </div>
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
