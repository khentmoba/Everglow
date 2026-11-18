// Port of lib/features/dashboard/presentation/widgets/dashboard_load_veil.dart.
import { useEffect, useState } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Curves, motionReduced, orZero } from '../../core/theme/motion';
import { letterSpacing, linear } from '../../core/theme/paint';
import { Icon } from '../../shared/widgets/Icon';

let requestedAfterPasscode = false;

export const DashboardLoadVeilControl = {
  requestPasscodeLoader() {
    requestedAfterPasscode = true;
  },
  consumePasscodeLoaderRequest(): boolean {
    const requested = requestedAfterPasscode;
    requestedAfterPasscode = false;
    return requested;
  },
};

export function labelForPercent(percent: number): string {
  if (percent < 18) return 'opening the door…';
  if (percent < 36) return 'gathering memories…';
  if (percent < 54) return 'checking your dates…';
  if (percent < 72) return 'unsealing letters…';
  if (percent < 88) return 'waking the garden…';
  if (percent < 100) return 'counting your stars…';
  return 'opening your story…';
}

export function DashboardLoadVeil({
  visible,
  onSkip,
  onComplete,
  duration = 2200,
}: {
  visible: boolean;
  onSkip?: () => void;
  onComplete?: () => void;
  duration?: number;
}) {
  const [progress, setProgress] = useState(0.01);
  const [rendered, setRendered] = useState(visible);

  useEffect(() => {
    if (visible) setRendered(true);
    else {
      const t = window.setTimeout(() => setRendered(false), orZero(500));
      return () => window.clearTimeout(t);
    }
  }, [visible]);

  useEffect(() => {
    if (!visible) return;
    if (motionReduced()) {
      setProgress(1);
      const t = window.setTimeout(() => {
        onComplete?.();
        onSkip?.();
      }, 250);
      return () => window.clearTimeout(t);
    }
    const dur = Math.max(1, orZero(duration));
    const start = performance.now();
    let raf = 0;
    let completeTimer = 0;
    const tick = (now: number) => {
      const raw = Math.min(1, (now - start) / dur);
      const eased = Curves.easeInOutCubic(raw);
      setProgress(Math.max(0.01, eased));
      if (raw < 1) {
        raf = requestAnimationFrame(tick);
      } else {
        completeTimer = window.setTimeout(() => {
          onComplete?.();
          onSkip?.();
        }, orZero(250));
      }
    };
    raf = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf);
      window.clearTimeout(completeTimer);
    };
  }, [visible, duration, onComplete, onSkip]);

  if (!rendered) return null;

  const pct = Math.min(100, Math.max(1, Math.round((visible ? progress : 1) * 100)));
  const label = labelForPercent(pct);

  return (
    <div
      aria-label={`Loading your story, ${pct}%`}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 900,
        pointerEvents: visible ? 'auto' : 'none',
        opacity: visible ? 1 : 0,
        transition: `opacity ${orZero(500)}ms ease-out`,
        background: linear([AppColors.inkDeep, AppColors.twilight, AppColors.velvet], { stops: [0, 0.55, 1] }),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <Icon name="favorite" size={26} color={AppColors.auroraRose} />
        <div style={{ height: 10 }} />
        <div
          style={{
            color: withAlpha(AppColors.petalWhite, 0.85),
            fontSize: 11,
            fontWeight: 600,
            ...letterSpacing(4),
          }}
        >
          EVERGLOW
        </div>
        <div style={{ height: 14 }} />
        <div
          style={{
            color: withAlpha(AppColors.petalWhite, 0.9),
            fontSize: 28,
            fontWeight: 600,
            ...letterSpacing(1),
            fontVariantNumeric: 'tabular-nums',
          }}
        >
          {pct}%
        </div>
        <div style={{ height: 10 }} />
        <div
          style={{
            width: 140,
            height: 2,
            borderRadius: 2,
            overflow: 'hidden',
            background: 'rgba(245, 239, 230, 0.15)',
          }}
        >
          <div
            style={{
              width: `${pct}%`,
              height: '100%',
              background: AppColors.blushGold,
            }}
          />
        </div>
        <div style={{ height: 8 }} />
        <div
          style={{
            color: withAlpha(AppColors.petalWhite, 0.45),
            fontSize: 10,
            ...letterSpacing(0.3),
          }}
        >
          {label}
        </div>
        {onSkip && (
          <>
            <div style={{ height: 22 }} />
            <button
              type="button"
              className="bare-button"
              onClick={onSkip}
              style={{
                color: withAlpha(AppColors.petalWhite, 0.7),
                fontSize: 12,
                fontWeight: 600,
                padding: '10px 22px',
                borderRadius: 999,
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
              }}
            >
              Skip
            </button>
          </>
        )}
      </div>
    </div>
  );
}
