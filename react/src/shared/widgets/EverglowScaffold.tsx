// Ports of everglow_scaffold.dart, everglow_icon_button.dart and the themed
// Material 3 FloatingActionButton.extended.
import { useState, type ReactNode } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint } from '../../core/theme/layout';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { boxShadow, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground, type RadialGlow } from './EverglowBackground';
import { Icon } from './Icon';
import { Tooltip } from './Tooltip';

/** Background + safe area + a centred column (500 / 720 / 960 wide), with an optional FAB. */
export function EverglowScaffold({
  children,
  header,
  backgroundColor = AppColors.twilight,
  glows,
  centerMaxWidth,
  floatingActionButton,
}: {
  children: ReactNode;
  header?: ReactNode;
  backgroundColor?: string;
  glows?: RadialGlow[];
  centerMaxWidth?: number;
  floatingActionButton?: ReactNode;
}) {
  const { width } = useViewport();
  const bp = AppBreakpoint.of(width);
  const maxWidth = centerMaxWidth ?? (bp === 'mobile' ? 500 : bp === 'tablet' ? 720 : 960);
  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden', background: backgroundColor }}>
      <EverglowBackground baseColor={backgroundColor} glows={glows} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          paddingTop: 'var(--safe-top, env(safe-area-inset-top, 0px))',
          paddingRight: 'var(--safe-right, env(safe-area-inset-right, 0px))',
          paddingBottom: 'var(--safe-bottom, env(safe-area-inset-bottom, 0px))',
          paddingLeft: 'var(--safe-left, env(safe-area-inset-left, 0px))',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {header}
        <div style={{ flex: 1, minHeight: 0, display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: '100%', maxWidth, height: '100%', display: 'flex', flexDirection: 'column' }}>{children}</div>
        </div>
      </div>
      {floatingActionButton && (
        <div
          style={{
            position: 'absolute',
            right: 'calc(16px + var(--safe-right, env(safe-area-inset-right, 0px)))',
            bottom: 'calc(16px + var(--safe-bottom, env(safe-area-inset-bottom, 0px)))',
            zIndex: 2,
          }}
        >
          {floatingActionButton}
        </div>
      )}
    </div>
  );
}

/** FloatingActionButton.extended with the app theme (deepRose, no elevation). */
export function ExtendedFab({ icon, label, onPressed }: { icon: string; label: string; onPressed: () => void }) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const overlay = pressed ? 0.1 : hovered ? 0.08 : 0;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onPressed}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => {
        setHovered(false);
        setPressed(false);
      }}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      style={{
        height: 56,
        padding: '0 20px 0 16px',
        borderRadius: 16,
        background: `linear-gradient(${withAlpha(AppColors.petalWhite, overlay)}, ${withAlpha(AppColors.petalWhite, overlay)}), ${AppColors.deepRose}`,
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        ...AppTypography.labelLarge,
        lineHeight: lineHeight(14),
        color: AppColors.petalWhite,
      }}
    >
      <Icon name={icon} size={24} color={AppColors.petalWhite} />
      {label}
    </button>
  );
}

export function EverglowIconButton({
  icon,
  onPressed,
  semanticLabel,
  tooltip,
  size = 44,
  iconColor = AppColors.roseQuartz,
  backgroundColor = Derived.surfaceGlass,
  borderColor = Derived.border,
  enabled = true,
}: {
  icon: string;
  onPressed?: () => void;
  semanticLabel: string;
  tooltip?: string;
  size?: number;
  iconColor?: string;
  backgroundColor?: string;
  borderColor?: string;
  enabled?: boolean;
}) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const scale = pressed ? 0.96 : hovered ? 1.03 : 1;
  const button = (
    <button
      type="button"
      className="bare-button"
      aria-label={semanticLabel}
      disabled={!enabled}
      onClick={() => enabled && onPressed?.()}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => {
        setHovered(false);
        setPressed(false);
      }}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: backgroundColor,
        border: `1px solid ${borderColor}`,
        boxShadow: hovered ? boxShadow([{ color: 'rgba(0,0,0,0.2)', blur: 8, offset: [0, 2] }]) : undefined,
        transform: `scale(${scale})`,
        transition: `transform ${orZero(AppMotion.fast)}ms ${CssCurves.easeOutStrong}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        boxSizing: 'border-box',
        flexShrink: 0,
      }}
    >
      <Icon name={icon} size={20} color={iconColor} />
    </button>
  );
  return tooltip ? <Tooltip message={tooltip}>{button}</Tooltip> : button;
}
