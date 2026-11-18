// Port of lib/shared/widgets/everglow/app_update_prompt.dart.
import { useEffect } from 'react';
import { useAppUpdate, appUpdateService } from '../../core/system/appUpdate';
import { AppColors } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';

export function AppUpdatePrompt() {
  const update = useAppUpdate();

  useEffect(() => {
    appUpdateService.start();
  }, []);

  if (!update.updateAvailable) return null;

  return (
    <div
      style={{
        position: 'fixed',
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: 'calc(92px + env(safe-area-inset-bottom))',
        zIndex: 850,
        display: 'flex',
        justifyContent: 'center',
        pointerEvents: 'none',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: 520,
          pointerEvents: 'auto',
          borderRadius: AppRadius.lg,
          background: AppColors.deepRose,
          boxShadow: '0 8px 24px rgba(0, 0, 0, 0.42)',
          padding: `${AppSpacing.md}px ${AppSpacing.lg}px`,
          display: 'flex',
          alignItems: 'center',
          gap: AppSpacing.md,
        }}
      >
        <span style={{ fontSize: 20 }}>✨</span>
        <div style={{ flex: 1, ...AppTypography.bodyMedium, color: AppColors.petalWhite }}>
          A fresh Everglow update is ready
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={update.applyNow}
          style={{
            ...AppTypography.bodyMedium,
            color: AppColors.blushGold,
            fontWeight: 700,
            padding: '6px 8px',
          }}
        >
          Restart
        </button>
        <button
          type="button"
          className="bare-button"
          aria-label="Dismiss update notification"
          onClick={update.dismiss}
          style={{ padding: 4, display: 'grid', placeItems: 'center' }}
        >
          <Icon name="close" size={18} color={AppColors.petalWhite} />
        </button>
      </div>
    </div>
  );
}
