// Port of lib/features/cinema/presentation/widgets/tabs/cinema_downloads_tab.dart.
import { useState, type CSSProperties } from 'react';
import { useNavigate } from 'react-router';
import {
  formattedDuration,
  formattedSize,
  offlineMedia,
  useOfflineMedia,
  type OfflineMediaItem,
} from '../../core/services/offlineMedia';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { ElevatedButton } from '../../shared/widgets/ElevatedButton';
import { Icon } from '../../shared/widgets/Icon';
import { LinearProgress } from '../../shared/widgets/LinearProgress';
import { cinemaTopInset } from './CinemaLibraryTab';
import { NetflixColors } from './cinemaTypes';

const text = (fontSize: number, color: string, fontWeight?: number, extra?: CSSProperties): CSSProperties => ({
  ...AppTypography.outfitHeading,
  fontSize,
  lineHeight: lineHeight(fontSize),
  color,
  ...(fontWeight ? { fontWeight } : {}),
  ...extra,
});
const ellipsis: CSSProperties = { whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' };
const card: CSSProperties = {
  background: NetflixColors.surface,
  borderRadius: AppRadius.md,
  border: `1px solid ${NetflixColors.hairline}`,
};
const sizeLine = (i: OfflineMediaItem) => {
  const d = formattedDuration(i);
  return `${formattedSize(i)}${d ? ` • ${d}` : ''}`;
};

export function CinemaDownloadsTab({ width, onBrowseCinema }: { width: number; onBrowseCinema: () => void }) {
  const service = useOfflineMedia();
  const navigate = useNavigate();
  const items = service.cinemaItems;

  const play = (item: OfflineMediaItem) => {
    const title = encodeURIComponent(item.title);
    navigate(
      item.type === 'tv'
        ? `/cinema/video/${item.mediaId}?type=tv&season=${item.season ?? 1}&episode=${item.episode ?? 1}&title=${title}`
        : `/cinema/video/${item.mediaId}?type=movie&title=${title}`,
    );
  };
  const remove = (item: OfflineMediaItem) => void offlineMedia.deleteDownload(item.id);

  const shows = new Map<string, OfflineMediaItem[]>();
  const movies: OfflineMediaItem[] = [];
  for (const item of items) {
    if (item.type === 'tv') {
      const list = shows.get(item.mediaId) ?? [];
      list.push(item);
      shows.set(item.mediaId, list);
    } else {
      movies.push(item);
    }
  }

  return (
    <div style={{ background: NetflixColors.background, padding: `${cinemaTopInset(width) + 8}px 16px 96px` }}>
      <Header count={items.length} />
      <div style={{ height: 16 }} />
      {items.length === 0 ? (
        <EmptyState onBrowseCinema={onBrowseCinema} />
      ) : (
        <>
          <StorageSummary storage={service.formattedCinemaStorage} />
          <div style={{ height: 20 }} />
          {shows.size > 0 && (
            <>
              <div style={{ paddingBottom: 12, ...text(15, NetflixColors.textSecondary, 700, { letterSpacing: 0.5 }) }}>
                TV Shows & Series
              </div>
              {[...shows.values()].map((episodes) => (
                <div key={episodes[0].mediaId}>
                  <SeriesGroup episodes={episodes} onPlay={play} onDelete={remove} />
                  <div style={{ height: 16 }} />
                </div>
              ))}
            </>
          )}
          {movies.length > 0 && (
            <>
              <div style={{ padding: '8px 0 12px', ...text(15, NetflixColors.textSecondary, 700, { letterSpacing: 0.5 }) }}>
                Movies
              </div>
              {movies.map((m) => (
                <div key={m.id}>
                  <MovieTile item={m} onPlay={play} onDelete={remove} />
                  <div style={{ height: 10 }} />
                </div>
              ))}
            </>
          )}
        </>
      )}
    </div>
  );
}

function Header({ count }: { count: number }) {
  const confirmClear = () =>
    void showDialog<void>((close) => (
      <AlertDialog
        background={NetflixColors.surface}
        title={<div style={text(17, NetflixColors.textPrimary, 700)}>Clear Cinema Downloads</div>}
        content={
          <div style={text(14, NetflixColors.textSecondary)}>
            Are you sure you want to remove all offline movies and TV episodes from this device?
          </div>
        }
        actions={[
          <TextButton
            key="cancel"
            color={NetflixColors.textMuted}
            onPressed={() => close(null)}
            style={text(14, NetflixColors.textMuted)}
          >
            Cancel
          </TextButton>,
          <ElevatedButton
            key="clear"
            background={NetflixColors.accent}
            onPressed={() => {
              close(null);
              void offlineMedia.clearAll('movie').then(() => offlineMedia.clearAll('tv'));
            }}
          >
            <span style={text(14, NetflixColors.textPrimary, 700)}>Clear</span>
          </ElevatedButton>,
        ]}
      />
    ));
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center' }}>
        <Icon name="download_for_offline" size={26} color={NetflixColors.accent} />
        <div style={{ width: 10 }} />
        <div style={{ minWidth: 0, ...ellipsis, ...text(22, NetflixColors.textPrimary, 700) }}>Downloads</div>
        {count > 0 && (
          <>
            <div style={{ width: 8 }} />
            <div
              style={{
                padding: '2px 8px',
                background: NetflixColors.surfaceElevated,
                borderRadius: AppRadius.full,
                border: `1px solid ${NetflixColors.hairline}`,
                ...text(12, NetflixColors.textSecondary, 600),
              }}
            >
              {count}
            </div>
          </>
        )}
      </div>
      {count > 0 && (
        <TextButton
          color={NetflixColors.textMuted}
          onPressed={confirmClear}
          icon={<Icon name="delete_sweep_outlined" size={18} color={NetflixColors.textMuted} />}
          style={text(13, NetflixColors.textMuted)}
        >
          Clear All
        </TextButton>
      )}
    </div>
  );
}

function StorageSummary({ storage }: { storage: string }) {
  return (
    <div style={{ ...card, padding: '12px 16px', display: 'flex', alignItems: 'center' }}>
      <div
        style={{ padding: 8, background: NetflixColors.surfaceElevated, borderRadius: AppRadius.sm, display: 'flex' }}
      >
        <Icon name="offline_pin" size={20} color={NetflixColors.textPrimary} />
      </div>
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={text(14, NetflixColors.textPrimary, 600)}>Offline Ready</div>
        <div style={{ height: 2 }} />
        <div style={text(12, NetflixColors.textSecondary)}>Watch instantly without Wi-Fi or mobile data</div>
      </div>
      <div style={text(13, NetflixColors.gold, 700)}>{storage}</div>
    </div>
  );
}

/** Material IconButton: a 48px circle slot around the icon. */
function IconButton({
  icon,
  size,
  color,
  onPressed,
  label,
}: {
  icon: string;
  size: number;
  color: string;
  onPressed: () => void;
  label: string;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      title={label}
      onClick={onPressed}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        width: size + 16,
        height: size + 16,
        minWidth: 48,
        minHeight: 48,
        flexShrink: 0,
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: hovered ? withAlpha(AppColors.petalWhite, 0.08) : 'transparent',
      }}
    >
      <Icon name={icon} size={size} color={color} />
    </button>
  );
}

function CoverThumb({ url, width, height }: { url: string; width: number; height: number }) {
  const [failed, setFailed] = useState(false);
  const valid = url && (url.startsWith('http') || url.startsWith('assets/'));
  return (
    <div
      style={{
        width,
        height,
        borderRadius: AppRadius.xs,
        overflow: 'hidden',
        flexShrink: 0,
        background: NetflixColors.surfaceElevated,
      }}
    >
      {valid && !failed ? (
        <img
          src={url.startsWith('assets/') ? `/${url}` : url}
          alt=""
          onError={() => setFailed(true)}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      ) : (
        <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="movie_outlined" size={24} color={NetflixColors.textMuted} />
        </div>
      )}
    </div>
  );
}

type RowProps = { onPlay: (i: OfflineMediaItem) => void; onDelete: (i: OfflineMediaItem) => void };

function SeriesGroup({ episodes, onPlay, onDelete }: { episodes: OfflineMediaItem[] } & RowProps) {
  const sorted = [...episodes].sort((a, b) => (a.season ?? 0) - (b.season ?? 0) || (a.episode ?? 0) - (b.episode ?? 0));
  const first = sorted[0];
  return (
    <div style={{ ...card, overflow: 'hidden' }}>
      <div style={{ padding: 12, display: 'flex', alignItems: 'center' }}>
        <CoverThumb url={first.coverUrl} width={48} height={72} />
        <div style={{ width: 12 }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...ellipsis, ...text(16, NetflixColors.textPrimary, 700) }}>{first.title}</div>
          <div style={{ height: 4 }} />
          <div style={text(13, NetflixColors.textSecondary)}>
            {sorted.length} downloaded {sorted.length === 1 ? 'episode' : 'episodes'}
          </div>
        </div>
        <IconButton
          icon="play_circle_fill"
          size={32}
          color={NetflixColors.accent}
          label="Play First Episode"
          onPressed={() => onPlay(first)}
        />
      </div>
      <div style={{ height: 1, background: NetflixColors.hairline }} />
      {sorted.map((ep) => (
        <EpisodeRow key={ep.id} item={ep} onPlay={onPlay} onDelete={onDelete} />
      ))}
    </div>
  );
}

/** The chip already says "S1 E1"; the title should not say it twice. */
function subtitleWithoutSeason(item: OfflineMediaItem): string {
  return item.subtitle.replace(/^S\d+\s*E\d+\s*[·•-]\s*/i, '').trim();
}

function EpisodeRow({ item, onPlay, onDelete }: { item: OfflineMediaItem } & RowProps) {
  return (
    <div
      style={{ padding: '10px 14px', borderBottom: `1px solid ${NetflixColors.hairline}`, display: 'flex', alignItems: 'center' }}
    >
      <div
        style={{
          padding: '3px 7px',
          background: NetflixColors.surfaceElevated,
          borderRadius: AppRadius.xs,
          border: `1px solid ${NetflixColors.hairline}`,
          ...text(11, NetflixColors.gold, 700),
        }}
      >
        S{item.season ?? 1} E{item.episode ?? 1}
      </div>
      <div style={{ width: 10 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="clamp-2" style={text(13, NetflixColors.textPrimary, 600)}>
          {subtitleWithoutSeason(item) || `Episode ${item.episode ?? 1}`}
        </div>
        <div style={{ height: 2 }} />
        <div style={text(11, NetflixColors.textMuted)}>{sizeLine(item)}</div>
        {item.status === 'downloading' && (
          <>
            <div style={{ height: 4 }} />
            <LinearProgress
              value={item.progress}
              height={3}
              color={NetflixColors.accent}
              background={NetflixColors.surfaceElevated}
            />
          </>
        )}
      </div>
      <IconButton icon="play_circle_fill" size={26} color={NetflixColors.accent} label="Play" onPressed={() => onPlay(item)} />
      <IconButton
        icon="delete_outline"
        size={20}
        color={NetflixColors.textMuted}
        label="Delete download"
        onPressed={() => onDelete(item)}
      />
    </div>
  );
}

function MovieTile({ item, onPlay, onDelete }: { item: OfflineMediaItem } & RowProps) {
  return (
    <div style={{ ...card, padding: 12, display: 'flex', alignItems: 'center' }}>
      <CoverThumb url={item.coverUrl} width={52} height={78} />
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...ellipsis, ...text(15, NetflixColors.textPrimary, 700) }}>{item.title}</div>
        <div style={{ height: 4 }} />
        <div style={text(12, NetflixColors.textSecondary)}>{sizeLine(item)}</div>
        {item.status === 'downloading' && (
          <>
            <div style={{ height: 6 }} />
            <LinearProgress
              value={item.progress}
              height={3}
              color={NetflixColors.accent}
              background={NetflixColors.surfaceElevated}
            />
          </>
        )}
      </div>
      <IconButton icon="play_circle_fill" size={32} color={NetflixColors.accent} label="Play" onPressed={() => onPlay(item)} />
      <IconButton
        icon="delete_outline"
        size={20}
        color={NetflixColors.textMuted}
        label="Delete download"
        onPressed={() => onDelete(item)}
      />
    </div>
  );
}

function EmptyState({ onBrowseCinema }: { onBrowseCinema: () => void }) {
  return (
    <div style={{ padding: '48px 24px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div
        style={{
          padding: 20,
          background: NetflixColors.surface,
          borderRadius: '50%',
          border: `1px solid ${NetflixColors.hairline}`,
          display: 'flex',
        }}
      >
        <Icon name="file_download_outlined" size={48} color={NetflixColors.textMuted} />
      </div>
      <div style={{ height: 20 }} />
      <div style={text(18, NetflixColors.textPrimary, 700)}>No Offline Downloads Yet</div>
      <div style={{ height: 8 }} />
      <div
        style={{ textAlign: 'center', ...text(13, NetflixColors.textSecondary, undefined, { lineHeight: lineHeight(13, 1.4) }) }}
      >
        Download movies and TV episodes to watch offline anytime on your phone or tablet.
      </div>
      <div style={{ height: 24 }} />
      <ElevatedButton
        background={NetflixColors.accent}
        radius={AppRadius.sm}
        padding="12px 24px"
        onPressed={onBrowseCinema}
        icon={<Icon name="explore" size={18} color={NetflixColors.textPrimary} />}
      >
        <span style={text(14, NetflixColors.textPrimary, 700)}>Explore Cinema</span>
      </ElevatedButton>
    </div>
  );
}
