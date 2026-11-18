// Port of lib/features/dashboard/presentation/widgets/xp_progress_section.dart.
import { useEffect, useState } from 'react';
import { Logger } from '../../core/system/logger';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { XpProgressBar } from './XpProgressBar';
import { xpService, type UserProgress } from './xpService';

const zero = (uid: string): UserProgress => ({
  uid,
  xpTotal: 0,
  level: 1,
  streak: 0,
  lastActivity: new Date(),
});

export function XpProgressSection({ uid }: { uid: string | null }) {
  const [progress, setProgress] = useState<UserProgress | null>(() => (uid ? zero(uid) : null));
  const [hasError, setHasError] = useState(false);
  const [attemptKey, setAttemptKey] = useState(0);

  useEffect(() => {
    if (!uid) {
      setProgress(null);
      setHasError(false);
      return;
    }
    setProgress(zero(uid));
    setHasError(false);
    let cancelled = false;
    let retries = 0;
    let retryTimer = 0;
    let unsub: (() => void) | null = null;

    const subscribe = () => {
      unsub?.();
      unsub = xpService.watchProgress(uid)({
        data: (data) => {
          if (cancelled) return;
          retries = 0;
          if (data) {
            setProgress(data);
            setHasError(false);
          }
        },
        error: (e) => {
          if (cancelled) return;
          Logger.e('[XpProgressSection] watchProgress error (bg retry)', e);
          if (retries < 3) {
            retries++;
            retryTimer = window.setTimeout(subscribe, (1 + retries) * 1000);
          } else {
            setHasError(true);
          }
        },
      });
    };
    subscribe();
    return () => {
      cancelled = true;
      clearTimeout(retryTimer);
      unsub?.();
    };
  }, [uid, attemptKey]);

  if (!uid) return null;
  if (progress) return <XpProgressBar progress={progress} />;
  if (hasError) {
    return (
      <div
        style={{
          height: 92,
          padding: '12px 16px',
          background: withAlpha(AppColors.velvet, 0.82),
          borderRadius: 24,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
          display: 'flex',
          alignItems: 'center',
          gap: 12,
        }}
      >
        <Icon name="cloud_off" size={20} color={withAlpha(AppColors.roseQuartz, 0.5)} />
        <div style={{ flex: 1 }}>
          <div style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.85), fontSize: 12.5, fontWeight: 600 }}>
            Couldn&apos;t load XP
          </div>
          <div style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.petalWhite, 0.5), fontSize: 11 }}>
            Check connection and retry
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => setAttemptKey((k) => k + 1)}
          style={{
            padding: '7px 12px',
            borderRadius: 999,
            background: withAlpha(AppColors.deepRose, 0.22),
            border: `1px solid ${withAlpha(AppColors.deepRose, 0.35)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Icon name="refresh" size={14} color={AppColors.petalWhite} />
          <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.petalWhite }}>Retry</span>
        </button>
      </div>
    );
  }
  return <XpProgressBar progress={zero(uid)} />;
}
