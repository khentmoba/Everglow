import { useState } from 'react';
import { ConnectivityService } from '../../core/network/connectivity';
import { NetworkQualityService } from '../../core/network/networkQuality';
import { useValue } from '../../core/system/store';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';

export function ConnectivityBanner() {
  const isOnline = useValue(ConnectivityService.isOnlineNotifier);
  const quality = useValue(NetworkQualityService.qualityNotifier);
  const saveData = useValue(NetworkQualityService.saveDataNotifier);
  const [dismissedSlow, setDismissedSlow] = useState(false);
  const [retrying, setRetrying] = useState(false);

  const isSlow = quality === 'slow' || saveData;
  if (isOnline && (!isSlow || dismissedSlow)) return null;

  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        maxWidth: '100%',
        padding: '8px 14px',
        borderRadius: 999,
        background: isOnline ? withAlpha(AppColors.plum, 0.94) : withAlpha(AppColors.inkDeep, 0.96),
        border: `1px solid ${withAlpha(isOnline ? AppColors.warmAmber : AppColors.roseQuartz, 0.45)}`,
        boxShadow: '0 8px 24px rgba(0, 0, 0, 0.45)',
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        pointerEvents: 'auto',
      }}
    >
      <Icon
        name={isOnline ? 'data_saver_on' : 'wifi_off'}
        size={16}
        color={isOnline ? AppColors.warmAmber : AppColors.roseQuartz}
      />
      <span
        style={{
          ...AppTypography.outfitMedium,
          fontSize: 12,
          color: AppColors.petalWhite,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {isOnline
          ? 'Slow connection · lighter images on'
          : 'Offline · showing saved data'}
      </span>
      {!isOnline ? (
        <button
          type="button"
          className="bare-button"
          disabled={retrying}
          onClick={async () => {
            setRetrying(true);
            await ConnectivityService.checkConnectivity();
            setRetrying(false);
          }}
          style={{
            padding: '3px 10px',
            borderRadius: 999,
            background: withAlpha(AppColors.deepRose, 0.35),
            border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.4)}`,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 11,
            flexShrink: 0,
          }}
        >
          {retrying ? 'Checking…' : 'Retry'}
        </button>
      ) : (
        <button
          type="button"
          className="bare-button"
          aria-label="Dismiss slow connection notice"
          onClick={() => setDismissedSlow(true)}
          style={{ padding: 2, display: 'flex', alignItems: 'center' }}
        >
          <Icon name="close" size={14} color={withAlpha(AppColors.petalWhite, 0.7)} />
        </button>
      )}
    </div>
  );
}
