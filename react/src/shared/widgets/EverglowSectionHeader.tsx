// Port of lib/shared/widgets/everglow/everglow_section_header.dart.
import { AppColors, withAlpha } from '../../core/theme/colors';
import { letterSpacing, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';

export function EverglowSectionHeader({
  label,
  icon,
  hue = AppColors.blushGold,
}: {
  label: string;
  icon: string;
  hue?: string;
}) {
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 22,
          height: 1,
          background: linear([AppColors.transparent, withAlpha(hue, 0.5)]),
        }}
      />
      <div style={{ width: 10 }} />
      <div
        style={{
          padding: '5px 10px',
          background: withAlpha(AppColors.moonlight, 0.06),
          borderRadius: 999,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
          display: 'inline-flex',
          alignItems: 'center',
        }}
      >
        <Icon name={icon} size={11} color={withAlpha(hue, 0.92)} />
        <div style={{ width: 6 }} />
        <span
          style={{
            ...AppTypography.outfitHeading,
            fontSize: 10,
            ...letterSpacing(2.0),
            color: hue,
          }}
        >
          {label.toUpperCase()}
        </span>
      </div>
      <div style={{ width: 10 }} />
      <div style={{ flex: 1, height: 1, background: withAlpha(AppColors.moonlight, 0.07) }} />
    </div>
  );
}
