// Port of lib/features/cinema/presentation/widgets/tabs/cinema_library_tab.dart
// (+ cinema_viewing_preferences.dart).
import { useEffect, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useValue } from '../../core/system/store';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { DropdownField, ExpansionTile, SwitchListTile, UnderlineTextField } from '../../shared/widgets/MaterialFields';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { cinemaPreferences } from './cinemaPreferences';
import { NetflixColors, type MediaItem } from './cinemaTypes';
import { NetflixPosterCard } from './NetflixUi';
import { isWatchedItem } from './tmdbService';

type Filter = 'all' | 'watching' | 'toWatch' | 'watched' | 'reminders';
type Sort = 'recentlySaved' | 'lastWatched' | 'title';

const status = (m: MediaItem) => m.status.trim().toLowerCase();
const isMovie = (m: MediaItem) => m.mediaType.trim().toLowerCase() !== 'tv' || m.format.trim().toLowerCase() === 'movie';
/** `isCompletedProgress`: a series whose last episode is reached. */
const isSeriesCompleted = (m: MediaItem) =>
  !isMovie(m) && m.episodeCount != null && m.episodeCount > 1 && m.currentEpisode != null && m.currentEpisode >= m.episodeCount;
const WATCHING = new Set(['watching', 'watching-khent', 'watching-clair', 'watching-both', 'watching-self']);
export const isCurrentlyWatching = (m: MediaItem) => !isSeriesCompleted(m) && WATCHING.has(status(m));
export const isCinemaItem = (m: MediaItem) => !m.isAnime || isMovie(m);

function progressOf(m: MediaItem): number | null {
  const pos = m.currentTimestamp ?? 0;
  const dur = m.durationSeconds ?? 0;
  if (pos <= 0 || dur <= 0) return null;
  return Math.min(1, Math.max(0, pos / dur));
}

/** `cinemaTopContentInset` (no safe-area top on the web).
 * Phones clear the 48px floating back button (10 + 48 + 10) so page titles never sit under it. */
export function cinemaTopInset(width: number) {
  // Tablets and desktops carry the top bar (56px); phones carry the floating button.
  if (width >= 700) return 56 + 20;
  return 68;
}

export function CinemaLibraryTab({
  width,
  watchlist,
  onMediaTap,
  onSwitchTab,
}: {
  width: number;
  watchlist: MediaItem[];
  onMediaTap: (m: MediaItem) => void;
  onSwitchTab: (tab: number) => void;
}) {
  const auth = useAuth();
  const [filter, setFilter] = useState<Filter>('all');
  const [sort, setSort] = useState<Sort>('recentlySaved');
  const [search, setSearch] = useState('');

  useEffect(() => cinemaPreferences.setUser(auth.currentUser), [auth.currentUser]);

  const isDesktop = width >= 1024;
  const h = isDesktop ? 48 : 16;
  const all = watchlist.filter(isCinemaItem);
  const filtered =
    filter === 'watching'
      ? all.filter(isCurrentlyWatching)
      : filter === 'toWatch'
        ? all.filter((m) => status(m) === 'to-watch')
        : filter === 'watched'
          ? all.filter(isWatchedItem)
          : filter === 'reminders'
            ? all.filter((m) => m.remindMe)
            : all;
  const q = search.trim().toLowerCase();
  const visible = filtered
    .filter((m) => m.title.toLowerCase().includes(q))
    .sort((a, b) => {
      const c =
        sort === 'recentlySaved'
          ? b.addedAt.getTime() - a.addedAt.getTime()
          : sort === 'lastWatched'
            ? (b.progressUpdatedAt?.getTime() ?? 0) - (a.progressUpdatedAt?.getTime() ?? 0)
            : a.title.toLowerCase().localeCompare(b.title.toLowerCase());
      if (c !== 0) return c;
      const t = a.title.toLowerCase().localeCompare(b.title.toLowerCase());
      return t !== 0 ? t : a.id.localeCompare(b.id);
    });
  const cols = isDesktop ? 6 : width >= 600 ? 5 : 3;

  return (
    <div>
      <div style={{ padding: `${cinemaTopInset(width)}px ${h}px 2px`, display: 'flex', alignItems: 'flex-end' }}>
        <span
          style={{
            ...AppTypography.outfitHeading,
            fontSize: isDesktop ? 22 : 20,
            lineHeight: lineHeight(isDesktop ? 22 : 20),
            color: NetflixColors.textPrimary,
          }}
        >
          My List
        </span>
        <div style={{ width: 10 }} />
        <span
          style={{
            paddingBottom: 2,
            ...AppTypography.outfitWhite,
            fontSize: 13,
            lineHeight: lineHeight(13),
            color: NetflixColors.textMuted,
            fontWeight: 500,
          }}
        >
          {all.length} {all.length === 1 ? 'title' : 'titles'}
        </span>
      </div>
      <div
        className="no-scrollbar"
        style={{ padding: `8px ${h}px 10px`, paddingRight: h + 16, display: 'flex', gap: 8, overflowX: 'auto' }}
      >
        {(
          [
            ['all', 'All'],
            ['watching', 'Watching'],
            ['toWatch', 'Want to Watch'],
            ['watched', 'Watched'],
            ['reminders', 'Reminders'],
          ] as const
        ).map(([id, label]) => (
          <LibraryPill key={id} label={label} selected={filter === id} onTap={() => setFilter(id)} />
        ))}
      </div>
      <div style={{ padding: `0 ${h}px 16px` }}>
        <UnderlineTextField
          label="Search My List"
          value={search}
          onChange={setSearch}
          prefixIcon="search"
          suffix={
            search ? (
              <Tooltip message="Clear search">
                <button
                  type="button"
                  className="bare-button"
                  aria-label="Clear search"
                  onClick={() => setSearch('')}
                  style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  <Icon name="close" size={24} color="#D6C2C4" />
                </button>
              </Tooltip>
            ) : undefined
          }
        />
        <div style={{ height: 6 }} />
        <DropdownField<Sort>
          label="Sort My List"
          value={sort}
          menuColor={NetflixColors.surface}
          items={[
            { value: 'recentlySaved', label: 'Recently saved' },
            { value: 'lastWatched', label: 'Last watched' },
            { value: 'title', label: 'Title' },
          ]}
          onChanged={setSort}
        />
        <div style={{ height: 6 }} />
        <ExpansionTile title="Viewing preferences">
          <CinemaViewingPreferences />
        </ExpansionTile>
      </div>
      {all.length === 0 ? (
        <EmptyLibrary isDesktop={isDesktop} onFind={() => onSwitchTab(1)} />
      ) : visible.length === 0 ? (
        <div
          style={{
            padding: '60px 0',
            textAlign: 'center',
            ...AppTypography.outfitWhite,
            color: NetflixColors.textMuted,
            fontSize: 14,
            lineHeight: lineHeight(14),
          }}
        >
          No titles match your search or filter.
        </div>
      ) : (
        <div style={{ padding: `0 ${h}px`, display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 10 }}>
          {visible.map((m) => {
            const watching = isCurrentlyWatching(m);
            return (
              <div key={m.id || `${m.mediaType}:${m.tmdbId}`} style={{ position: 'relative' }}>
                {/* No remove badge here: "remove from Continue Watching" lives in the
                    tile menu on Home, where the progress it clears is visible. */}
                <div style={{ aspectRatio: '0.67' }}>
                  <NetflixPosterCard item={m} compact caption progress={watching ? progressOf(m) : null} onTap={() => onMediaTap(m)} />
                </div>
              </div>
            );
          })}
        </div>
      )}
      <div style={{ height: 110 }} />
    </div>
  );
}

/** `NetflixRemoveBadge`: a 48px outlined IconButton on a dark wash. */
export function NetflixRemoveBadge({
  onTap,
  tooltip = 'Remove from Continue Watching',
}: {
  onTap: () => void;
  tooltip?: string;
}) {
  return (
    <Tooltip message={tooltip}>
      <button
        type="button"
        className="bare-button"
        aria-label={tooltip}
        onClick={(e) => {
          e.stopPropagation();
          onTap();
        }}
        style={{
          width: 44,
          height: 44,
          boxSizing: 'border-box',
          borderRadius: '50%',
          background: 'transparent',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <span
          style={{
            width: 28,
            height: 28,
            borderRadius: '50%',
            background: 'rgba(8,8,8,0.72)',
            border: '1px solid rgba(245,245,245,0.55)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="close" size={15} color={NetflixColors.textPrimary} />
        </span>
      </button>
    </Tooltip>
  );
}

function LibraryPill({ label, selected, onTap }: { label: string; selected: boolean; onTap: () => void }) {
  const [hovered, setHovered] = useState(false);
  const fg = selected ? NetflixColors.background : NetflixColors.textSecondary;
  const bg = selected ? NetflixColors.textPrimary : NetflixColors.surface;
  return (
    <button
      type="button"
      className="bare-button"
      aria-pressed={selected}
      onClick={onTap}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        minWidth: 48,
        height: 48,
        padding: '0 15px',
        boxSizing: 'border-box',
        borderRadius: 24,
        border: `1px solid ${selected ? NetflixColors.textPrimary : NetflixColors.hairline}`,
        background: hovered ? `linear-gradient(${fg}14, ${fg}14), ${bg}` : bg,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        ...AppTypography.outfitHeading,
        fontSize: 12.5,
        lineHeight: lineHeight(12.5),
        color: fg,
        whiteSpace: 'nowrap',
      }}
    >
      {label}
    </button>
  );
}

function EmptyLibrary({ isDesktop, onFind }: { isDesktop: boolean; onFind: () => void }) {
  return (
    <div style={{ padding: '0 32px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <Icon name="bookmark_border" size={52} color={NetflixColors.textMuted} />
      <div style={{ height: 18 }} />
      <div
        style={{
          ...AppTypography.outfitHeading,
          fontSize: isDesktop ? 19 : 17,
          lineHeight: lineHeight(isDesktop ? 19 : 17),
          color: NetflixColors.textPrimary,
        }}
      >
        Your list is empty
      </div>
      <div style={{ height: 6 }} />
      <div
        style={{
          ...AppTypography.outfitWhite,
          color: NetflixColors.textMuted,
          fontSize: 13,
          lineHeight: lineHeight(13, 1.5),
          textAlign: 'center',
        }}
      >
        Movies and shows you save or watch will appear here.
      </div>
      <div style={{ height: 26 }} />
      <button
        type="button"
        className="bare-button"
        onClick={onFind}
        style={{ padding: '11px 22px', background: '#FFFFFF', borderRadius: 6, display: 'flex', alignItems: 'center' }}
      >
        <Icon name="search" size={17} color="#000000" />
        <div style={{ width: 8 }} />
        <span style={{ ...AppTypography.outfitHeading, color: '#000000', fontSize: 13.5, lineHeight: lineHeight(13.5) }}>
          Find Something
        </span>
      </button>
    </div>
  );
}

/** `CinemaViewingPreferences` (the full list form). */
function CinemaViewingPreferences() {
  const prefs = useValue(cinemaPreferences);
  return (
    <div style={{ background: NetflixColors.surface, padding: '0 24px 0 16px' }}>
      <SwitchListTile
        title="Hide spoilers"
        subtitle="Keep episode titles, stories and pictures hidden"
        value={prefs.hideSpoilers}
        onChanged={(v) => cinemaPreferences.setHideSpoilers(v)}
        activeThumbColor={NetflixColors.accent}
      />
      <SwitchListTile
        title="Autoplay next episode"
        subtitle="Only after a supported player confirms the episode has ended"
        value={prefs.autoplayNext}
        onChanged={(v) => cinemaPreferences.setAutoplayNext(v)}
        activeThumbColor={NetflixColors.accent}
      />
    </div>
  );
}
