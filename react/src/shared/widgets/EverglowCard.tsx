// Port of lib/shared/widgets/everglow/everglow_card.dart.
import { useState, type CSSProperties, type ReactNode } from 'react';
import { Derived, withAlpha, AppColors } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppMotion, CssCurves, orZero } from '../../core/theme/motion';
import { shadowLayer, type BoxShadow } from '../../core/theme/paint';

export function EverglowCard({
  children,
  onTap,
  semanticLabel,
  radius = AppRadius.x2,
  padding = 20,
  fillColor = Derived.surfaceGlass,
  boxShadow,
  style,
}: {
  children: ReactNode;
  onTap?: () => void;
  semanticLabel?: string;
  radius?: number;
  padding?: number;
  fillColor?: string;
  /** Replaces the hover shadow, like Dart's `boxShadow` (drawn under the see-through fill). */
  boxShadow?: BoxShadow[];
  style?: CSSProperties;
}) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [focused, setFocused] = useState(false);
  const interactive = onTap != null;
  const scale = pressed ? 0.96 : hovered ? 1.03 : 1;
  const lift = hovered && !pressed ? -4 : 0;
  const ms = orZero(AppMotion.fast);

  return (
    <div
      role={interactive ? 'button' : undefined}
      aria-label={interactive ? semanticLabel : undefined}
      tabIndex={interactive ? 0 : undefined}
      onClick={onTap}
      onKeyDown={(e) => {
        if (interactive && (e.key === 'Enter' || e.key === ' ')) {
          e.preventDefault();
          onTap();
        }
      }}
      onMouseEnter={interactive ? () => setHovered(true) : undefined}
      onMouseLeave={
        interactive
          ? () => {
              setHovered(false);
              setPressed(false);
            }
          : undefined
      }
      onPointerDown={interactive ? () => setPressed(true) : undefined}
      onPointerUp={interactive ? () => setPressed(false) : undefined}
      onPointerCancel={interactive ? () => setPressed(false) : undefined}
      onFocus={interactive ? (e) => setFocused(e.currentTarget.matches(':focus-visible')) : undefined}
      onBlur={interactive ? () => setFocused(false) : undefined}
      style={{
        position: 'relative',
        cursor: interactive ? 'pointer' : undefined,
        outline: 'none',
        // AnimatedContainer's transform has no alignment, so it scales from the top-left corner.
        transform: `translateY(${lift}px) scale(${scale})`,
        transformOrigin: '0 0',
        transition: `transform ${ms}ms ${CssCurves.easeOutStrong}`,
        ...style,
      }}
    >
      {(boxShadow ?? (hovered ? [{ color: 'rgba(0,0,0,0.2)', blur: 8, offset: [0, 2] } as BoxShadow] : [])).map((s, i) => (
        <div key={i} aria-hidden style={shadowLayer(s, { radius })} />
      ))}
      <div
        style={{
          position: 'relative',
          // A Container with a border pads its child by the border width.
          padding: padding + 1,
          background: fillColor,
          borderRadius: radius,
          boxShadow: `inset 0 0 0 ${focused ? 1.4 : 1}px ${focused ? withAlpha(AppColors.blushGold, 0.65) : withAlpha(AppColors.moonlight, 0.08)}`,
          boxSizing: 'border-box',
        }}
      >
        {children}
      </div>
    </div>
  );
}
