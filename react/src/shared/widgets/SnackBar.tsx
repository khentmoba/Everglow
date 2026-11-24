// Flutter's floating SnackBar with Everglow's theme, as a tiny global queue.
import { useEffect, useState } from 'react';
import { AppColors, Derived } from '../../core/theme/colors';
import { ValueNotifier, useValue } from '../../core/system/store';

type SnackAction = { label: string; onPressed: () => void };
type Snack = { id: number; text: string; background?: string; duration: number; action?: SnackAction };

const current = new ValueNotifier<Snack | null>(null);
let nextId = 1;

export function showSnackBar(text: string, opts: { background?: string; duration?: number; action?: SnackAction } = {}) {
  current.value = { id: nextId++, text, background: opts.background, duration: opts.duration ?? 4000, action: opts.action };
}

export function SnackBarHost() {
  const snack = useValue(current);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (!snack) return;
    const show = requestAnimationFrame(() => setVisible(true));
    const hide = window.setTimeout(() => setVisible(false), snack.duration);
    const clear = window.setTimeout(() => {
      if (current.value?.id === snack.id) current.value = null;
    }, snack.duration + 250);
    return () => {
      cancelAnimationFrame(show);
      clearTimeout(hide);
      clearTimeout(clear);
    };
  }, [snack]);
  if (!snack) return null;
  return (
    <div
      role="status"
      style={{
        position: 'fixed',
        left: 0,
        right: 0,
        bottom: 'max(10px, env(safe-area-inset-bottom))',
        display: 'flex',
        justifyContent: 'center',
        padding: '0 15px',
        pointerEvents: 'none',
        // Above every surface, including Cinema's detail sheet (1400): a message
        // that explains what just happened is useless behind the panel.
        zIndex: 1600,
        opacity: visible ? 1 : 0,
        transition: 'opacity 250ms linear',
      }}
    >
      <div
        style={{
          width: '100%',
          padding: '14px 16px',
          borderRadius: 16,
          border: `1px solid ${Derived.border}`,
          background: snack.background ?? AppColors.velvet,
          boxShadow: '0 3px 6px rgba(0,0,0,0.3)',
          fontSize: 14,
          fontWeight: 500,
          color: AppColors.petalWhite,
          pointerEvents: 'auto',
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <span style={{ flex: 1 }}>{snack.text}</span>
        {snack.action && (
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              snack.action!.onPressed();
              current.value = null;
            }}
            style={{
              margin: '-14px -8px -14px 8px',
              padding: '0 12px',
              height: 40,
              fontSize: 14,
              fontWeight: 500,
              color: AppColors.deepRose,
            }}
          >
            {snack.action.label}
          </button>
        )}
      </div>
    </div>
  );
}
