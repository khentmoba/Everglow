// Port of lib/features/dashboard/presentation/widgets/dashboard_zone_header.dart.
import type { ReactNode } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint } from '../../core/theme/layout';
import { letterSpacing, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

export function DashboardZoneHeader({
  label,
  title,
  subtitle,
  icon,
  hue,
  trailing,
}: {
  label: string;
  title: string;
  subtitle: string;
  icon: string;
  hue: string;
  trailing?: ReactNode;
}) {
  const { width } = useViewport();
  const hPad = width < 360 ? 16 : 24;
  return (
    <div style={{ padding: `28px ${hPad}px 14px`, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
      <div style={{ display: 'flex', alignItems: 'center', alignSelf: 'stretch' }}>
        <div style={{ width: 22, height: 1, background: linear([AppColors.transparent, withAlpha(hue, 0.55)]) }} />
        <div style={{ width: 10 }} />
        <div
          style={{
            padding: '5px 10px',
            background: withAlpha(hue, 0.1),
            borderRadius: 999,
            border: `1px solid ${withAlpha(hue, 0.2)}`,
            display: 'inline-flex',
            alignItems: 'center',
          }}
        >
          <Icon name={icon} size={11} color={hue} />
          <div style={{ width: 6 }} />
          <span
            style={{
              ...AppTypography.outfitHeading,
              fontSize: 10,
              ...letterSpacing(1.1),
              color: hue,
            }}
          >
            {label.toUpperCase()}
          </span>
        </div>
        <div style={{ width: 10 }} />
        <div style={{ flex: 1, height: 1, background: withAlpha(AppColors.moonlight, 0.07) }} />
      </div>
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', alignItems: 'flex-end', alignSelf: 'stretch' }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <h2
            style={{
              margin: 0,
              ...AppTypography.cormorantBold,
              fontSize: 26,
              lineHeight: 1,
              letterSpacing: -0.3,
              color: AppColors.petalWhite,
            }}
          >
            {title}
          </h2>
          <div style={{ height: 4 }} />
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 12,
              color: withAlpha(AppColors.petalWhite, 0.52),
              letterSpacing: 0.2,
            }}
          >
            {subtitle}
          </span>
        </div>
        {trailing}
      </div>
    </div>
  );
}

export function DashboardPair({ left, right }: { left: ReactNode; right: ReactNode }) {
  const { width } = useViewport();
  const isWide = width >= AppBreakpoint.mobile;
  if (isWide) {
    return (
      <div style={{ padding: '0 16px', display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>{left}</div>
        <div style={{ flex: 1, minWidth: 0 }}>{right}</div>
      </div>
    );
  }
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <div style={{ padding: '0 16px' }}>{left}</div>
      <div style={{ padding: '0 16px' }}>{right}</div>
    </div>
  );
}
