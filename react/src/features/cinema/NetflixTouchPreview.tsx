import { useState } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { NetflixColors, resumeSecondsOf, TmdbImages, type MediaItem } from './cinemaTypes';

export function showNetflixTouchPreview(opts: {
  item: MediaItem;
  inList: boolean;
  onTap?: () => void;
  onPlay?: () => void;
  onRestart?: () => void;
  onToggleList?: (add: boolean) => void;
}): Promise<void> {
  if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
    try {
      navigator.vibrate(12);
    } catch {
      // Haptics blocked or unsupported.
    }
  }
  return showDialog<void>((close) => <TouchPreviewDialog {...opts} onClose={() => close(undefined)} />).then(() => {});
}

function TouchPreviewDialog({
  item,
  inList: initialInList,
  onTap,
  onPlay,
  onRestart,
  onToggleList,
  onClose,
}: {
  item: MediaItem;
  inList: boolean;
  onTap?: () => void;
  onPlay?: () => void;
  onRestart?: () => void;
  onToggleList?: (add: boolean) => void;
  onClose: () => void;
}) {
  const [inList, setInList] = useState(initialInList);
  const backdrop = TmdbImages.backdropFor(item.backdropPath) || TmdbImages.posterFor(item.posterPath);
  const hasResume = (resumeSecondsOf(item) ?? 0) > 0;

  return (
    <div
      style={{
        width: 'min(90vw, 360px)',
        borderRadius: 16,
        overflow: 'hidden',
        background: NetflixColors.surfaceElevated,
        border: `1px solid ${NetflixColors.hairline}`,
        boxShadow: '0 20px 50px rgba(0,0,0,0.75)',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ position: 'relative', aspectRatio: '16 / 9', background: '#111' }}>
        {backdrop && (
          <img
            src={backdrop}
            alt={item.title}
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        )}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'linear-gradient(180deg, rgba(0,0,0,0.12) 0%, rgba(32,32,32,0.95) 100%)',
          }}
        />
        <button
          type="button"
          className="bare-button"
          aria-label="Close preview"
          onClick={onClose}
          style={{
            position: 'absolute',
            top: 8,
            right: 8,
            width: 32,
            height: 32,
            borderRadius: '50%',
            background: 'rgba(0,0,0,0.65)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="close" size={18} color="#FFFFFF" />
        </button>
        <div style={{ position: 'absolute', left: 14, right: 14, bottom: 10 }}>
          <div style={{ ...AppTypography.outfitHeading, fontSize: 17, color: '#FFFFFF' }}>{item.title}</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 3, fontSize: 11.5, color: NetflixColors.textSecondary }}>
            {item.year && <span>{item.year}</span>}
            {item.score != null && item.score > 0 && (
              <span style={{ color: NetflixColors.match, fontWeight: 700 }}>{Math.round(item.score * 10)}% Match</span>
            )}
            <span>{item.mediaType === 'tv' ? 'Series' : 'Movie'}</span>
          </div>
        </div>
      </div>

      <div style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {item.synopsis && (
          <div
            className="clamp-3"
            style={{ ...AppTypography.outfitWhite, fontSize: 12.5, color: NetflixColors.textSecondary, lineHeight: 1.45 }}
          >
            {item.synopsis}
          </div>
        )}

        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          {onPlay && (
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                onClose();
                onPlay();
              }}
              style={{
                flex: 1,
                minWidth: 110,
                padding: '10px 14px',
                borderRadius: 8,
                background: '#FFFFFF',
                color: '#000000',
                ...AppTypography.outfitBold,
                fontSize: 13.5,
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 6,
              }}
            >
              <Icon name="play_arrow" size={20} color="#000000" />
              <span>{hasResume ? 'Resume' : 'Play'}</span>
            </button>
          )}
          {hasResume && onRestart && (
            <button
              type="button"
              className="bare-button"
              aria-label="Start from beginning"
              onClick={() => {
                onClose();
                onRestart();
              }}
              style={{
                width: 40,
                height: 40,
                borderRadius: '50%',
                background: withAlpha(AppColors.petalWhite, 0.1),
                border: `1px solid ${Derived.border}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="replay" size={18} color="#FFFFFF" />
            </button>
          )}
          {onToggleList && (
            <button
              type="button"
              className="bare-button"
              aria-label={inList ? 'Remove from My List' : 'Add to My List'}
              onClick={() => {
                const next = !inList;
                setInList(next);
                onToggleList(next);
              }}
              style={{
                width: 40,
                height: 40,
                borderRadius: '50%',
                background: withAlpha(AppColors.petalWhite, 0.1),
                border: `1px solid ${Derived.border}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name={inList ? 'check' : 'add'} size={20} color="#FFFFFF" />
            </button>
          )}
          {onTap && (
            <button
              type="button"
              className="bare-button"
              aria-label="More details"
              onClick={() => {
                onClose();
                onTap();
              }}
              style={{
                width: 40,
                height: 40,
                borderRadius: '50%',
                background: withAlpha(AppColors.petalWhite, 0.1),
                border: `1px solid ${Derived.border}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="info_outline" size={20} color="#FFFFFF" />
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
