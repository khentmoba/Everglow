// Port of lib/shared/widgets/everglow/everglow_button.dart.
import { useState } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { CssCurves, orZero } from '../../core/theme/motion';
import { boxShadow } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';
import { Tooltip } from './Tooltip';

type Variant = 'filled' | 'glass' | 'ghost' | 'pill';

export function EverglowButton({
  label,
  icon,
  onPressed,
  variant = 'filled',
  enabled = true,
  tooltip,
  backgroundColor,
  foregroundColor,
  fullWidth = false,
  stretch = false,
}: {
  label: string;
  icon?: string;
  onPressed?: () => void;
  variant?: Variant;
  enabled?: boolean;
  tooltip?: string;
  backgroundColor?: string;
  foregroundColor?: string;
  fullWidth?: boolean;
  /** Stretched by its parent (a ListView child): full width with the label on the left, as Flutter lays it out. */
  stretch?: boolean;
}) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);

  const radius = variant === 'pill' ? AppRadius.full : AppRadius.x2;
  const pad =
    variant === 'pill'
      ? `${AppSpacing.sm}px ${AppSpacing.x2}px`
      : variant === 'ghost'
        ? `${AppSpacing.md}px ${AppSpacing.lg}px`
        : `${AppSpacing.md}px ${AppSpacing.x2}px`;

  const color =
    foregroundColor ?? (variant === 'ghost' ? Derived.textMedium : AppColors.petalWhite);

  let background = 'transparent';
  let border = 'none';
  let shadow: string | undefined;

  if (variant === 'filled') {
    const base = backgroundColor ?? AppColors.deepRose;
    background = enabled ? base : withAlpha(base, 0.5);
    shadow = hovered
      ? boxShadow([{ color: withAlpha(AppColors.deepRose, 0.35), blur: 18, offset: [0, 6] }])
      : boxShadow([{ color: 'rgba(0,0,0,0.22)', blur: 8, offset: [0, 3] }]);
  } else if (variant === 'glass') {
    background = Derived.surfaceGlass;
    border = `1px solid ${Derived.border}`;
    shadow = boxShadow([{ color: 'rgba(0,0,0,0.22)', blur: hovered ? 14 : 8, offset: [0, 3] }]);
  } else if (variant === 'ghost') {
    background = hovered ? withAlpha(AppColors.moonlight, 0.08) : 'transparent';
  } else if (variant === 'pill') {
    background = withAlpha(AppColors.deepRose, hovered ? 0.15 : 0.08);
    border = `1px solid ${withAlpha(AppColors.deepRose, 0.22)}`;
  }

  const scale = pressed ? 0.96 : hovered ? 1.03 : 1;
  const ty = hovered && !pressed ? -4 : 0;

  const btn = (
    <button
      type="button"
      className="bare-button"
      disabled={!enabled}
      aria-label={tooltip ?? label}
      onMouseEnter={() => enabled && setHovered(true)}
      onMouseLeave={() => {
        setHovered(false);
        setPressed(false);
      }}
      onPointerDown={() => enabled && setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerCancel={() => setPressed(false)}
      onClick={() => enabled && onPressed?.()}
      style={{
        padding: pad,
        borderRadius: radius,
        background,
        border,
        boxShadow: shadow,
        transform: `translateY(${ty}px) scale(${scale})`,
        transition: `transform ${orZero(160)}ms ${CssCurves.easeOutStrong}, background ${orZero(160)}ms ${CssCurves.easeOutStrong}`,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: stretch ? 'flex-start' : 'center',
        width: fullWidth || stretch ? '100%' : undefined,
        cursor: enabled ? 'pointer' : 'default',
      }}
    >
      {icon && (
        <>
          <Icon name={icon} size={18} color={color} />
          <div style={{ width: AppSpacing.sm }} />
        </>
      )}
      <span
        style={{
          ...AppTypography.labelLarge,
          color,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {label}
      </span>
    </button>
  );

  return tooltip ? <Tooltip message={tooltip}>{btn}</Tooltip> : btn;
}
