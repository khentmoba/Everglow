// Material 3 ElevatedButton as app_theme.dart themes it: deepRose, 28/18 padding,
// radius 24, elevation 1, labelLarge text.
import { useState, type ReactNode } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';

/** ElevatedButton with the app theme: 28/18 padding, elevation 1. */
export function ElevatedButton({
  onPressed,
  background = AppColors.deepRose,
  radius = 24,
  icon,
  stretch = false,
  children,
}: {
  onPressed: () => void;
  background?: string;
  radius?: number;
  icon?: ReactNode;
  /** Inside `SizedBox(width: double.infinity)`: full width, content centred. */
  stretch?: boolean;
  children: ReactNode;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onPressed}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        padding: '18px 28px',
        minHeight: 40,
        borderRadius: radius,
        // M3 hover: the foreground colour at 8% over the fill.
        background: hovered
          ? `linear-gradient(${withAlpha(AppColors.petalWhite, 0.08)}, ${withAlpha(AppColors.petalWhite, 0.08)}), ${background}`
          : background,
        color: AppColors.petalWhite,
        boxShadow: '0 1px 2px rgba(0,0,0,0.3), 0 1px 3px 1px rgba(0,0,0,0.15)',
        width: stretch ? '100%' : undefined,
        justifyContent: stretch ? 'center' : undefined,
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        cursor: 'pointer',
        flexShrink: 0,
      }}
    >
      {icon}
      {children}
    </button>
  );
}
