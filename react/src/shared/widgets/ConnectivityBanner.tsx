import { useState } from 'react';
import { useLocation } from 'react-router';
import { ConnectivityService } from '../../core/network/connectivity';
import { NetworkQualityService } from '../../core/network/networkQuality';
import { useValue } from '../../core/system/store';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from './Icon';

export function ConnectivityBanner() {
  const { pathname } = useLocation();
  const isOnline = useValue(ConnectivityService.isOnlineNotifier);
  const quality = useValue(NetworkQualityService.qualityNotifier);
  const saveData = useValue(NetworkQualityService.saveDataNotifier);
  const [dismissedSlow, setDismissedSlow] = useState(false);
  const [retrying, setRetrying] = useState(false);

  const isSlow = quality === 'slow' || saveData;
  if (isOnline && (!isSlow || dismissedSlow)) return null;

  const isManga = pathname.startsWith('/manga');
  const bg = isManga
    ? 'var(--katana-surface, #13161F)'
    : isOnline
      ? withAlpha(AppColors.plum, 0.94)
      : withAlpha(AppColors.inkDeep, 0.96);
  const borderColor = isManga
    ? isOnline
      ? 'var(--katana-accent, #F59E0B)'
      : 'var(--katana-border-strong, #384259)'
    : withAlpha(isOnline ? AppColors.warmAmber : AppColors.roseQuartz, 0.45);
  const iconColor = isManga
    ? isOnline
      ? 'var(--katana-accent, #F59E0B)'
      : 'var(--katana-text-muted, #A8B3C7)'
    : isOnline
      ? AppColors.warmAmber
      : AppColors.roseQuartz;
  const textColor = isManga ? 'var(--katana-text, #F3F5F9)' : AppColors.petalWhite;
  const retryBg = isManga ? 'var(--katana-accent, #F59E0B)' : withAlpha(AppColors.deepRose, 0.35);
  const retryBorder = isManga ? 'var(--katana-accent, #F59E0B)' : withAlpha(AppColors.roseQuartz, 0.4);
  const retryColor = isManga ? 'var(--katana-accent-ink, #111318)' : AppColors.petalWhite;

  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        maxWidth: '100%',
        padding: '6px 14px',
        minHeight: 40,
        borderRadius: 999,
        background: bg,
        border: `1px solid ${borderColor}`,
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
        color={iconColor}
      />
      <span
        style={{
          ...AppTypography.outfitMedium,
          fontSize: 12,
          color: textColor,
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
            minHeight: 32,
            padding: '4px 12px',
            borderRadius: 999,
            background: retryBg,
            border: `1px solid ${retryBorder}`,
            color: retryColor,
            ...AppTypography.outfitBold,
            fontSize: 11.5,
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
          style={{ width: 32, height: 32, display: 'grid', placeItems: 'center', flexShrink: 0 }}
        >
          <Icon name="close" size={14} color={isManga ? 'var(--katana-text-muted, #A8B3C7)' : withAlpha(AppColors.petalWhite, 0.7)} />
        </button>
      )}
    </div>
  );
}
