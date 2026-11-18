// Port of lib/features/dashboard/presentation/widgets/dashboard_zone_header.dart.
import type { ReactNode } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint } from '../../core/theme/layout';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { HueGlyph } from '../../shared/widgets/HueGlyph';

export function DashboardZoneHeader({
  title,
  subtitle,
  icon,
  hue,
  trailing,
}: {
  label?: string;
  title: string;
  subtitle: string;
  icon: string;
  hue: string;
  trailing?: ReactNode;
}) {
  const { width } = useViewport();
  const hPad = width < 360 ? 16 : 20;
  return (
    <div style={{ padding: `40px ${hPad}px 16px` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <HueGlyph icon={icon} hue={hue} size={44} iconSize={20} />
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <h2
            style={{
              margin: 0,
              ...AppTypography.cormorantBoldWhite,
              fontSize: 30,
              lineHeight: 1,
              letterSpacing: -0.4,
            }}
          >
            {title}
          </h2>
          <span
            style={{
              ...AppTypography.handwrittenBody,
              fontSize: 18,
              lineHeight: 1.2,
              marginTop: 2,
              color: withAlpha(hue, 0.85),
            }}
          >
            {subtitle}
          </span>
        </div>
        {trailing}
      </div>
      <div
        aria-hidden
        style={{ height: 1, marginTop: 16, background: linear([withAlpha(hue, 0.4), withAlpha(AppColors.moonlight, 0.06), AppColors.transparent], { stops: [0, 0.5, 1] }) }}
      />
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
