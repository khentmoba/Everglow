import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { NetflixColors } from './cinemaTypes';
import { resumeSecondsOf, type MediaItem } from './cinemaTypes';

export type CinemaPlaybackAction = 'resume' | 'restart' | 'episodes' | 'finished' | 'remove';

function formatHms(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const rem = s % 60;
  return `${h}:${String(m).padStart(2, '0')}:${String(rem).padStart(2, '0')}`;
}

export function showCinemaPlaybackSheet(item: MediaItem): Promise<CinemaPlaybackAction | null> {
  const seconds = resumeSecondsOf(item) ?? item.currentTimestamp ?? 0;
  const position = formatHms(seconds);
  const isTv = item.mediaType === 'tv';

  const rowStyle = {
    width: '100%',
    padding: '12px 14px',
    borderRadius: 12,
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    textAlign: 'left' as const,
    background: withAlpha(NetflixColors.textPrimary, 0.04),
    border: `1px solid ${Derived.border}`,
  };

  return showModalBottomSheet<CinemaPlaybackAction>((close) => (
    <div
      style={{
        maxWidth: 520,
        margin: '0 auto',
        background: NetflixColors.surface,
        borderTopLeftRadius: 24,
        borderTopRightRadius: 24,
        borderTop: `1px solid ${Derived.border}`,
        padding: '14px 18px 24px',
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      <div style={{ alignSelf: 'center', width: 36, height: 4, borderRadius: 2, background: withAlpha(NetflixColors.textSecondary, 0.4) }} />
      <div style={{ ...AppTypography.outfitHeading, fontSize: 16.5, color: NetflixColors.textPrimary, marginBottom: 2 }}>
        {item.title}
      </div>

      <button type="button" className="bare-button" onClick={() => close('resume')} style={rowStyle}>
        <Icon name="play_arrow" size={22} color={NetflixColors.textPrimary} />
        <div style={{ flex: 1 }}>
          <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
            {seconds > 0 ? `Resume at ${position}` : 'Continue watching'}
          </div>
          <div style={{ fontSize: 12, color: Derived.textMuted }}>
            {isTv ? `Season ${item.currentSeason ?? 1}, episode ${item.currentEpisode ?? 1}` : 'Your saved place'}
          </div>
        </div>
      </button>

      <button type="button" className="bare-button" onClick={() => close('restart')} style={rowStyle}>
        <Icon name="replay" size={20} color={AppColors.petalWhite} />
        <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
          {isTv ? 'Restart this episode' : 'Start from the beginning'}
        </div>
      </button>

      {isTv && (
        <button type="button" className="bare-button" onClick={() => close('episodes')} style={rowStyle}>
          <Icon name="format_list_numbered" size={20} color={AppColors.petalWhite} />
          <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
            Choose a different episode
          </div>
        </button>
      )}

      <button type="button" className="bare-button" onClick={() => close('finished')} style={rowStyle}>
        <Icon name="done_all" size={20} color={AppColors.success} />
        <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
          {isTv ? 'Mark series finished' : 'Mark movie finished'}
        </div>
      </button>

      <button type="button" className="bare-button" onClick={() => close('remove')} style={rowStyle}>
        <Icon name="remove_circle_outline" size={20} color={AppColors.roseQuartz} />
        <div style={{ flex: 1 }}>
          <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.roseQuartz }}>
            Remove from Continue Watching
          </div>
          <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
            Clears the saved place; keeps the title in My List.
          </div>
        </div>
      </button>
    </div>
  ));
}
