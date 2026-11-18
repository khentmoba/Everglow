import { AppColors, withAlpha } from '../../core/theme/colors';
import { Icon } from './Icon';

/** A soft rounded-square tile tinted from one hue, holding one icon. */
export function HueGlyph({ icon, hue, size = 36, iconSize }: { icon: string; hue: string; size?: number; iconSize?: number }) {
  return (
    <span
      aria-hidden
      style={{
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.34),
        flexShrink: 0,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: `linear-gradient(145deg, ${withAlpha(hue, 0.3)}, ${withAlpha(hue, 0.08)} 70%)`,
        boxShadow: `inset 0 1px 0 ${withAlpha(AppColors.petalWhite, 0.1)}, inset 0 0 0 1px ${withAlpha(hue, 0.16)}, 0 4px 12px ${withAlpha(AppColors.inkDeep, 0.35)}`,
      }}
    >
      <Icon name={icon} size={iconSize ?? Math.round(size * 0.48)} color={hue} />
    </span>
  );
}
