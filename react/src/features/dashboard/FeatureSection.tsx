// Port of lib/features/dashboard/presentation/widgets/feature_section.dart.
import { useState, type ReactNode } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { CssCurves, orZero, reduceAmbientMotion } from '../../core/theme/motion';
import { linear, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { HueGlyph } from '../../shared/widgets/HueGlyph';
import { Icon } from '../../shared/widgets/Icon';

export function FeatureSection({
  icon,
  hue,
  title,
  subtitle,
  trailing,
  children,
  onTap,
  padding = 18,
}: {
  icon: string;
  hue: string;
  title: string;
  subtitle?: string;
  trailing?: ReactNode;
  children: ReactNode;
  onTap?: () => void;
  padding?: number;
}) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const [hovered, setHovered] = useState(false);

  const activeHover = hovered && !reduceAmbient;
  return (
    <div
      style={{
        position: 'relative',
        transform: activeHover ? 'translateY(-2px)' : undefined,
        transition: reduceAmbient ? undefined : `transform ${orZero(220)}ms ${CssCurves.easeOutStrong}`,
      }}
      onMouseEnter={() => !reduceAmbient && setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {!reduceAmbient && (
        <div
          style={shadowLayer(
            { color: withAlpha(AppColors.inkDeep, 0.18), blur: 14, offset: [0, 6] },
            { radius: AppRadius.xl },
          )}
          aria-hidden
        />
      )}
      <div
        onClick={onTap}
        style={{
          position: 'relative',
          background: withAlpha(AppColors.velvet, 0.34),
          borderRadius: AppRadius.xl,
          border: `1px solid ${activeHover ? withAlpha(hue, 0.22) : withAlpha(AppColors.moonlight, 0.07)}`,
          cursor: onTap ? 'pointer' : undefined,
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 22,
            right: 22,
            height: 1,
            background: linear([AppColors.transparent, withAlpha(hue, 0.2), AppColors.transparent]),
            pointerEvents: 'none',
          }}
        />
        <div style={{ padding }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <HueGlyph icon={icon} hue={hue} size={40} iconSize={19} />
            <div style={{ width: 12 }} />
            <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
              <span style={{ ...AppTypography.cormorantBold, fontSize: 20, lineHeight: 1 }}>{title}</span>
              {subtitle && (
                <>
                  <div style={{ height: 3 }} />
                  <span
                    style={{
                      ...AppTypography.outfitWhite,
                      fontSize: 11,
                      fontWeight: 500,
                      letterSpacing: 0.25,
                      color: withAlpha(AppColors.petalWhite, 0.48),
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      maxWidth: '100%',
                    }}
                  >
                    {subtitle}
                  </span>
                </>
              )}
            </div>
            {trailing}
          </div>
          <div style={{ height: 14 }} />
          {children}
        </div>
      </div>
    </div>
  );
}

export function SectionPillLink({
  label,
  onTap,
  hue = AppColors.blushGold,
}: {
  label: string;
  onTap: () => void;
  hue?: string;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      onClick={(e) => {
        e.stopPropagation();
        onTap();
      }}
      style={{
        padding: '7px 12px',
        background: withAlpha(hue, 0.09),
        borderRadius: 999,
        border: `1px solid ${withAlpha(hue, 0.28)}`,
        display: 'inline-flex',
        alignItems: 'center',
      }}
    >
      <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: hue }}>{label}</span>
      <div style={{ width: 3 }} />
      <Icon name="chevron_right" size={14} color={hue} />
    </button>
  );
}

export function SectionChevron({ hue = AppColors.blushGold }: { hue?: string }) {
  return (
    <div
      style={{
        width: 28,
        height: 28,
        borderRadius: '50%',
        background: withAlpha(hue, 0.1),
        border: `1px solid ${withAlpha(hue, 0.28)}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name="chevron_right" size={16} color={hue} />
    </div>
  );
}
