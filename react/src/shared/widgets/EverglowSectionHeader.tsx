import type { ReactNode } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { HueGlyph } from './HueGlyph';

/** Small in-page section title: a tinted glyph, a serif label and a fading rule. */
export function EverglowSectionHeader({
  label,
  icon,
  hue = AppColors.blushGold,
  trailing,
}: {
  label: string;
  icon: string;
  hue?: string;
  trailing?: ReactNode;
}) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 32 }}>
      <HueGlyph icon={icon} hue={hue} size={26} iconSize={14} />
      <h2
        style={{
          margin: 0,
          ...AppTypography.cormorantBoldWhite,
          fontSize: 20,
          lineHeight: 1.1,
          letterSpacing: 0.1,
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </h2>
      <div style={{ flex: 1, height: 1, minWidth: 16, background: linear([withAlpha(hue, 0.35), AppColors.transparent]) }} />
      {trailing}
    </div>
  );
}
