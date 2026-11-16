// Flutter's Tooltip with Everglow's theme: shows on mouse hover, fades in
// over 150ms, sits 24px below the middle of what it describes.
import { useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';

const desktop = !/android|iphone|ipad|ipod/i.test(navigator.userAgent);

export function Tooltip({ message, children }: { message: string; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const [at, setAt] = useState<{ x: number; y: number } | null>(null);
  const [shown, setShown] = useState(false);
  return (
    <div
      ref={ref}
      style={{ display: 'inline-block' }}
      onPointerEnter={(e) => {
        if (e.pointerType !== 'mouse') return;
        const r = ref.current!.getBoundingClientRect();
        setAt({ x: r.left + r.width / 2, y: r.top + r.height / 2 + 24 });
        requestAnimationFrame(() => setShown(true));
      }}
      onPointerLeave={() => {
        setShown(false);
        window.setTimeout(() => setAt(null), 175);
      }}
    >
      {children}
      {at &&
        createPortal(
          <div
            role="tooltip"
            className="t-bodySmall"
            style={{
              position: 'fixed',
              left: at.x,
              top: at.y,
              transform: 'translateX(-50%)',
              minHeight: desktop ? 24 : 32,
              padding: desktop ? '4px 8px' : '4px 16px',
              display: 'flex',
              alignItems: 'center',
              whiteSpace: 'nowrap',
              background: withAlpha(AppColors.inkDeep, 0.95),
              borderRadius: 14,
              border: `1px solid ${Derived.border}`,
              color: Derived.textMuted,
              opacity: shown ? 1 : 0,
              transition: `opacity ${shown ? 150 : 75}ms linear`,
              pointerEvents: 'none',
              zIndex: 1000,
            }}
          >
            {message}
          </div>,
          document.body,
        )}
    </div>
  );
}
