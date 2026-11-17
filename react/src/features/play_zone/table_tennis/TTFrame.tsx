// Shared pieces of the Table Tennis screens: the game iframe, the round
// overlay buttons (web_overlay_button.dart) and the portrait blocker.
import { useState, type CSSProperties } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, withAlpha } from '../../../core/theme/colors';
import { AppTypography } from '../../../core/theme/typography';
import { useViewport } from '../../../core/system/viewport';
import { TextButton } from '../../../shared/widgets/Dialogs';
import { Icon } from '../../../shared/widgets/Icon';

export { findTTIframe } from './ttService';

/** Navigator.maybePop from a /play-zone child: back if the app pushed us, else the hub. */
export function usePlayZoneBack() {
  const navigate = useNavigate();
  return () => {
    const idx = (window.history.state as { idx?: number } | null)?.idx;
    if (idx) navigate(-1);
    else navigate('/play-zone', { replace: true });
  };
}

function detectMobile() {
  try {
    return window.matchMedia('(pointer: coarse)').matches || window.matchMedia('(max-width: 900px)').matches;
  } catch {
    return false;
  }
}

/** True on a phone/tablet held upright, where the game can't be played. */
export function useMobilePortraitBlocked() {
  const [isMobile] = useState(detectMobile);
  const { width, height } = useViewport();
  return isMobile && height > width;
}

export function TTGameFrame({ src }: { src: string }) {
  return (
    <iframe
      src={src}
      data-everglow-tt="1"
      title="Table Tennis World Tour"
      tabIndex={0}
      allow="autoplay *; fullscreen *; pointer-lock *; gamepad *"
      allowFullScreen
      style={{ position: 'absolute', inset: 0, border: 0, width: '100%', height: '100%', display: 'block' }}
    />
  );
}

const ICON_CHARS = { close: '✕', replay: '⟳' } as const;

export function WebOverlayButton({
  icon,
  onTap,
  tooltip,
  size = 40,
}: {
  icon: keyof typeof ICON_CHARS;
  onTap: () => void;
  tooltip?: string;
  size?: number;
}) {
  return (
    <button
      type="button"
      title={tooltip ?? ''}
      aria-label={tooltip ?? ''}
      onClick={(e) => {
        onTap();
        e.currentTarget.blur();
      }}
      onContextMenu={(e) => e.preventDefault()}
      onDragStart={(e) => e.preventDefault()}
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: 'rgba(0, 0, 0, 0.45)',
        border: '1px solid rgba(255, 245, 245, 0.25)',
        color: '#FFF5F5',
        fontSize: Math.trunc(Math.min(28, Math.max(14, size * 0.55))),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
        padding: 0,
        margin: 0,
        outline: 'none',
        userSelect: 'none',
        WebkitTapHighlightColor: 'transparent',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        lineHeight: 1,
        boxSizing: 'border-box',
        touchAction: 'manipulation',
      }}
    >
      {ICON_CHARS[icon]}
    </button>
  );
}

export const overlayTop: CSSProperties = { position: 'absolute', top: 'calc(env(safe-area-inset-top, 0px) + 8px)' };

export function RotateBlock({ onBack }: { onBack: () => void }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: '#000',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name="screen_rotation" size={56} color={AppColors.roseQuartz} />
      <div style={{ height: 12 }} />
      <span style={{ ...AppTypography.cormorantSemiBoldWhite, fontSize: 28 }}>Rotate your device</span>
      <div style={{ height: 4 }} />
      <span style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.75) }}>
        Table Tennis runs in landscape.
      </span>
      <div style={{ height: 24 }} />
      <TextButton onPressed={onBack} color={withAlpha(AppColors.petalWhite, 0.7)} style={{ fontWeight: 500 }}>
        Back
      </TextButton>
    </div>
  );
}
