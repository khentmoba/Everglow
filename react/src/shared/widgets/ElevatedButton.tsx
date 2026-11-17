// Material 3 ElevatedButton as app_theme.dart themes it: deepRose, 28/18 padding,
// radius 24, elevation 1, labelLarge text.
import { useState, type ReactNode } from 'react';
import { AppColors, M3Scheme, withAlpha } from '../../core/theme/colors';

/** ElevatedButton with the app theme: 28/18 padding, elevation 1. */
export function ElevatedButton({
  onPressed,
  background = AppColors.deepRose,
  radius = 24,
  icon,
  stretch = false,
  padding = '18px 28px',
  flat = false,
  disabled = false,
  disabledBackground,
  children,
}: {
  onPressed: () => void;
  background?: string;
  radius?: number;
  icon?: ReactNode;
  /** Inside `SizedBox(width: double.infinity)`: full width, content centred. */
  stretch?: boolean;
  /** styleFrom(padding:) as CSS padding. */
  padding?: string;
  /** elevation: 0. */
  flat?: boolean;
  /** onPressed: null. */
  disabled?: boolean;
  /** disabledBackgroundColor (M3 default: onSurface at 12%). */
  disabledBackground?: string;
  children: ReactNode;
}) {
  const [hovered, setHovered] = useState(false);
  // Material's padded tap target: a short button sits centred in a 48px slot.
  return (
    <div style={{ minHeight: 48, display: 'flex', alignItems: 'center', width: stretch ? '100%' : undefined, flexShrink: 0 }}>
      <button
        type="button"
        className="bare-button"
        onClick={disabled ? undefined : onPressed}
        disabled={disabled}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          padding,
          minHeight: 40,
          borderRadius: radius,
          // M3 hover: the foreground colour at 8% over the fill.
          background: disabled
            ? (disabledBackground ?? withAlpha(M3Scheme.onSurface, 0.12))
            : hovered
              ? `linear-gradient(${withAlpha(AppColors.petalWhite, 0.08)}, ${withAlpha(AppColors.petalWhite, 0.08)}), ${background}`
              : background,
          color: disabled ? withAlpha(M3Scheme.onSurface, 0.38) : AppColors.petalWhite,
          boxShadow: flat || disabled ? undefined : '0 1px 2px rgba(0,0,0,0.3), 0 1px 3px 1px rgba(0,0,0,0.15)',
          width: stretch ? '100%' : undefined,
          justifyContent: stretch ? 'center' : undefined,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          cursor: disabled ? 'default' : 'pointer',
          flexShrink: 0,
        }}
      >
        {icon}
        {children}
      </button>
    </div>
  );
}
