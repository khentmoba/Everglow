// Ports of lib/shared/widgets/shelf/: the media-shelf pieces books (and later
// other shelves) share. Each one matches its Flutter file box for box.
import { useState, type ReactNode } from 'react';
import { reduceAmbientMotion } from '../../../core/system/device';
import { useViewport } from '../../../core/system/viewport';
import { AppColors, withAlpha } from '../../../core/theme/colors';
import { Align, insetBorder, linear, lineHeight } from '../../../core/theme/paint';
import { AppTypography } from '../../../core/theme/typography';
import { EverglowBackground, type RadialGlow } from '../EverglowBackground';
import { Icon } from '../Icon';

export { insetBorder };

// atmospheric_backdrop.dart
export const shelfDefaultGlows: RadialGlow[] = [
  { color: AppColors.deepRose, alignment: [-0.7, -0.85], size: 0.85, opacity: 0.16 },
  { color: AppColors.softLavender, alignment: [0.85, 0.95], size: 0.75, opacity: 0.1 },
];

export function ShelfAtmosphericBackdrop({
  baseColor = AppColors.twilight,
  glows = shelfDefaultGlows,
}: {
  baseColor?: string;
  glows?: RadialGlow[];
}) {
  return <EverglowBackground baseColor={baseColor} glows={glows} />;
}

// shelf_icon_button.dart: a 44px glassy circle with a hairline rose ring.
export function ShelfIconButton({
  icon,
  onClick,
  label,
  tooltip,
  size = 44,
  iconColor,
  background,
}: {
  icon: string;
  onClick?: () => void;
  label: string;
  tooltip?: string;
  size?: number;
  iconColor?: string;
  background?: string;
}) {
  const [hover, setHover] = useState(false);
  const enabled = onClick != null;
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      title={tooltip}
      disabled={!enabled}
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: size,
        height: size,
        flexShrink: 0,
        borderRadius: '50%',
        background: background ?? withAlpha(AppColors.moonlight, 0.06),
        ...insetBorder(withAlpha(AppColors.roseQuartz, hover ? 0.55 : 0.15), 0.8),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: enabled ? 'pointer' : 'default',
        transition: 'box-shadow 220ms cubic-bezier(0.23, 1, 0.32, 1)',
      }}
    >
      <Icon name={icon} size={size * 0.45} color={iconColor ?? withAlpha(AppColors.roseQuartz, enabled ? 1 : 0.5)} />
    </button>
  );
}

// shelf_section_header.dart: accent bar, eyebrow + title, optional See all.
export function ShelfSectionHeader({
  eyebrow,
  title,
  subtitle,
  accent = AppColors.roseQuartz,
  onSeeAll,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  accent?: string;
  onSeeAll?: () => void;
}) {
  return (
    <div role="heading" aria-level={2} style={{ display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 3,
          height: 32,
          flexShrink: 0,
          borderRadius: 2,
          background: linear([accent, withAlpha(accent, 0.25)], { begin: Align.topCenter, end: Align.bottomCenter }),
        }}
      />
      <div style={{ width: 12, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...AppTypography.outfitHeading,
            fontSize: 9,
            lineHeight: lineHeight(9),
            color: withAlpha(accent, 0.75),
            letterSpacing: 2,
            whiteSpace: 'nowrap',
          }}
        >
          {eyebrow.toUpperCase()}
        </div>
        <div style={{ height: 2 }} />
        <div
          className="ellipsis"
          style={{ ...AppTypography.cormorantExtraBoldWhite, fontSize: 22, letterSpacing: 0.2, lineHeight: '22px' }}
        >
          {title}
        </div>
        {subtitle ? (
          <>
            <div style={{ height: 2 }} />
            <div
              className="ellipsis"
              style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), color: withAlpha(AppColors.roseQuartz, 0.55) }}
            >
              {subtitle}
            </div>
          </>
        ) : null}
      </div>
      {onSeeAll && (
        <>
          <div style={{ width: 8, flexShrink: 0 }} />
          <SeeAllChip accent={accent} onClick={onSeeAll} />
        </>
      )}
    </div>
  );
}

function SeeAllChip({ accent, onClick }: { accent: string; onClick: () => void }) {
  const [hover, setHover] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="See all"
      title="See all"
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        flexShrink: 0,
        padding: '8.8px 12.8px',
        borderRadius: 14,
        background: hover ? withAlpha(accent, 0.14) : 'transparent',
        ...insetBorder(withAlpha(accent, hover ? 0.55 : 0.3), 0.8),
        display: 'flex',
        alignItems: 'center',
        transition: 'background 220ms cubic-bezier(0.23, 1, 0.32, 1)',
      }}
    >
      <span style={{ ...AppTypography.outfitHeading, fontSize: 11, lineHeight: lineHeight(11), color: accent, letterSpacing: 0.3 }}>
        See all
      </span>
      <div style={{ width: 2 }} />
      <Icon name="arrow_forward" size={14} color={accent} />
    </button>
  );
}

// scroll_edge_fade.dart: a fade on the trailing (right) edge of a scroller.
export function ScrollEdgeFade({
  children,
  fadeWidth = 36,
  fadeColor = '#080810',
}: {
  children: ReactNode;
  fadeWidth?: number;
  fadeColor?: string;
}) {
  return (
    <div style={{ position: 'relative' }}>
      {children}
      <div
        style={{
          position: 'absolute',
          top: 0,
          bottom: 0,
          right: 0,
          width: fadeWidth,
          pointerEvents: 'none',
          background: linear([fadeColor, withAlpha(fadeColor, 0)], { begin: Align.centerRight, end: Align.centerLeft }),
        }}
      />
    </div>
  );
}

// staggered_entrance.dart: a 420ms fade + 12px rise, skipped when ambient
// motion is reduced.
export function StaggeredEntrance({ children }: { children: ReactNode }) {
  const viewport = useViewport();
  if (reduceAmbientMotion(viewport)) return <>{children}</>;
  return <div className="shelf-entrance">{children}</div>;
}
