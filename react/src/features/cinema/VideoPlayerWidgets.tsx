// Ports of video_player_widgets.dart (pill/icon buttons, pulsing dot, cinematic
// loader), cinema_viewing_preferences.dart (compact chips), episode_navigator.dart
// (with the non-Netflix EpisodeTile), up_next_overlay.dart and torrent_download_sheet.dart.
import { useEffect, useState, type CSSProperties, type ReactNode } from 'react';
import { useValue } from '../../core/system/store';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Curves, motionReduced } from '../../core/theme/motion';
import { boxShadow, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { OfflineIds, useOfflineMedia } from '../../core/services/offlineMedia';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { cinemaPreferences } from './cinemaPreferences';
import { NetflixColors, TmdbImages } from './cinemaTypes';
import { nextEpisodeLabel, searchTorrents, type NextEpisode, type TorrentCopy, type TorrentSearch } from './playerServices';
import { fetchMediaDetails, fetchSeasonEpisodes, type TvEpisode } from './tmdbService';

const white = (a: number) => `rgba(255,255,255,${a})`;
const text = (size: number, style: CSSProperties, extra: CSSProperties = {}): CSSProperties => ({
  ...style,
  fontSize: size,
  lineHeight: lineHeight(size),
  ...extra,
});

/** `_playerDisplayTitle`: drops "S1 E2" / "Episode 3" suffixes from the route title. */
export function playerDisplayTitle(raw: string): string {
  let title = raw.trim();
  if (!title) return title;
  const suffixes = [
    /\s*[:|–—-]\s*S\d+\s*E\d+.*$/i,
    /\s*[:|–—-]\s*E\d+.*$/i,
    /\s*[:|–—-]\s*Episode\s*\d+.*$/i,
    /\s+S\d+\s*E\d+\s*$/i,
    /\s+E\d+\s*$/i,
    /\s+Episode\s*\d+\s*$/i,
  ];
  let changed = true;
  while (changed) {
    changed = false;
    for (const pattern of suffixes) {
      const next = title.replace(pattern, '').trim();
      if (next && next !== title) {
        title = next;
        changed = true;
      }
    }
  }
  return title || raw.trim();
}

function usePress() {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  return {
    hovered,
    pressed,
    handlers: {
      onPointerEnter: (e: React.PointerEvent) => e.pointerType === 'mouse' && setHovered(true),
      onPointerLeave: () => {
        setHovered(false);
        setPressed(false);
      },
      onPointerDown: () => setPressed(true),
      onPointerUp: () => setPressed(false),
      onPointerCancel: () => setPressed(false),
    },
  };
}

export function PlayerPillButton({
  icon,
  label,
  compact = false,
  onTap,
}: {
  icon: string;
  label: string;
  compact?: boolean;
  onTap?: () => void;
}) {
  const { hovered, pressed, handlers } = usePress();
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      {...handlers}
      style={{
        flexShrink: 0,
        display: 'flex',
        alignItems: 'center',
        gap: 6,
        padding: `7px ${compact ? 8 : 12}px`,
        borderRadius: AppRadius.full,
        background: white(hovered ? 0.16 : 0.1),
        border: `1px solid ${white(0.16)}`,
        transform: `scale(${pressed ? 0.96 : 1})`,
        transition: 'transform 120ms ease-out, background-color 180ms ease-out',
        cursor: 'pointer',
      }}
    >
      <Icon name={icon} size={14} color={white(0.7)} />
      <span style={text(11, AppTypography.outfitHeading, { color: white(0.7) })}>{label}</span>
    </button>
  );
}

export function PlayerIconButton({ icon, compact = false, onTap }: { icon: string; compact?: boolean; onTap?: () => void }) {
  const { hovered, pressed, handlers } = usePress();
  const size = compact ? 30 : 32;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={(e) => {
        e.stopPropagation();
        onTap?.();
      }}
      {...handlers}
      style={{
        flexShrink: 0,
        width: size,
        height: size,
        boxSizing: 'border-box',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: AppRadius.xs,
        background: white(hovered ? 0.18 : 0.1),
        border: `1px solid ${white(0.16)}`,
        transform: `scale(${pressed ? 0.92 : 1})`,
        transition: 'transform 120ms ease-out, background-color 180ms ease-out',
        cursor: 'pointer',
      }}
    >
      <Icon name={icon} size={16} color={hovered ? '#fff' : white(0.7)} />
    </button>
  );
}

/** `_PulsingDot`: 1600ms easeOut ring, starting at 0.35; still under reduce motion. */
export function PulsingDot() {
  const still = motionReduced();
  const p = Curves.easeOut(0.35);
  return (
    <div style={{ width: 14, height: 14, position: 'relative', flexShrink: 0 }}>
      <div
        className={still ? undefined : 'player-pulse-ring'}
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '50%',
          background: NetflixColors.accent,
          opacity: (1 - p) * 0.35,
          transform: `scale(${1 + p * 1.6})`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 3,
          top: 3,
          width: 8,
          height: 8,
          borderRadius: '50%',
          background: NetflixColors.accent,
        }}
      />
    </div>
  );
}

/** `_CinematicLoader`: the 2200ms ring and sliding bar over the player while it starts. */
export function CinematicLoader({ providerName }: { providerName: string }) {
  const still = motionReduced();
  const v = 0.5;
  // A start that takes this long is not "almost there"; say what to do instead
  // of showing the same three words forever.
  const [slow, setSlow] = useState(false);
  useEffect(() => {
    const id = window.setTimeout(() => setSlow(true), 9000);
    return () => window.clearTimeout(id);
  }, []);
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        pointerEvents: 'none',
        background: withAlpha(NetflixColors.background, 0.96),
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div style={{ width: 72, height: 72, position: 'relative', flexShrink: 0 }}>
        <div
          className={still ? undefined : 'player-loader-ring'}
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: '50%',
            border: `1.5px solid ${withAlpha(NetflixColors.accent, (1 - v) * 0.45)}`,
            transform: `scale(${0.8 + v * 0.5})`,
          }}
        />
        <div
          style={{
            position: 'absolute',
            left: 8,
            top: 8,
            width: 56,
            height: 56,
            borderRadius: '50%',
            background: NetflixColors.surfaceElevated,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="movie" size={28} color="#fff" />
        </div>
      </div>
      <div style={{ height: 18 }} />
      <div style={text(14, AppTypography.outfitBold, { letterSpacing: 0.4 })}>Preparing your stream</div>
      <div style={{ height: 4 }} />
      <div style={text(12, AppTypography.outfitMuted)}>
        {slow ? `via ${providerName} · taking longer than usual, try Servers` : `via ${providerName}`}
      </div>
      <div style={{ height: 16 }} />
      <div
        style={{
          width: 140,
          height: 3,
          borderRadius: AppRadius.full,
          overflow: 'hidden',
          background: white(0.08),
          position: 'relative',
        }}
      >
        <div
          className={still ? undefined : 'player-loader-bar'}
          style={{ position: 'absolute', top: 0, left: (140 - 52) * v, width: 52, height: 3, background: NetflixColors.accent }}
        />
      </div>
    </div>
  );
}

/** `CinemaViewingPreferences(compact: true)`. */
export function CompactViewingPreferences() {
  const prefs = useValue(cinemaPreferences);
  return (
    <div style={{ background: NetflixColors.surface, padding: '6px 16px', display: 'flex', flexWrap: 'wrap', gap: '6px 8px' }}>
      <CompactChip label="Hide spoilers" selected={prefs.hideSpoilers} onChanged={(v) => cinemaPreferences.setHideSpoilers(v)} />
      <CompactChip
        label="Autoplay next episode"
        selected={prefs.autoplayNext}
        onChanged={(v) => cinemaPreferences.setAutoplayNext(v)}
      />
    </div>
  );
}

function CompactChip({ label, selected, onChanged }: { label: string; selected: boolean; onChanged: (v: boolean) => void }) {
  const [hovered, setHovered] = useState(false);
  const fill = selected ? withAlpha(NetflixColors.accent, 0.16) : NetflixColors.surfaceElevated;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={() => onChanged(!selected)}
      onPointerEnter={(e) => e.pointerType === 'mouse' && setHovered(true)}
      onPointerLeave={() => setHovered(false)}
      style={{
        height: 29.5,
        boxSizing: 'border-box',
        padding: '0 12px',
        borderRadius: AppRadius.full,
        border: `1px solid ${selected ? NetflixColors.accent : NetflixColors.hairline}`,
        background: hovered ? `linear-gradient(${white(0.08)}, ${white(0.08)}), ${fill}` : fill,
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
        ...text(12, AppTypography.outfitHeading, { color: selected ? NetflixColors.textPrimary : Derived.textMedium }),
      }}
    >
      {label}
    </button>
  );
}

/** episode_list_section.dart `shouldRevealEpisodeDetails`. */
function shouldReveal(
  season: number,
  episode: number,
  o: {
    currentSeason: number;
    currentEpisode: number;
    position: number;
    duration: number;
    allWatched: boolean;
    completed: boolean;
  },
): boolean {
  if (o.allWatched) return true;
  if (season < o.currentSeason) return true;
  if (season > o.currentSeason || episode > o.currentEpisode) return false;
  if (episode < o.currentEpisode) return true;
  if (o.completed) return true;
  return o.duration > 0 && o.position / o.duration >= 0.95;
}

interface SeasonRow {
  number: number;
  name: string;
}

/** `EpisodeNavigator`: the collapsible season/episode picker under the player. */
export function EpisodeNavigator({
  tmdbId,
  initialSeason,
  initialEpisode,
  title,
  positionSeconds,
  durationSeconds,
  allEpisodesWatched,
  currentEpisodeCompleted,
  initiallyExpanded = false,
  onSeasonChanged,
  onEpisodeChanged,
}: {
  tmdbId: number;
  initialSeason: number;
  initialEpisode: number;
  title: string;
  positionSeconds: number;
  durationSeconds: number;
  allEpisodesWatched: boolean;
  currentEpisodeCompleted: boolean;
  initiallyExpanded?: boolean;
  onSeasonChanged: (s: number) => void;
  onEpisodeChanged: (e: number) => void;
}) {
  const prefs = useValue(cinemaPreferences);
  const [selectedSeason, setSelectedSeason] = useState(initialSeason);
  const [selectedEpisode, setSelectedEpisode] = useState(initialEpisode);
  const [seasons, setSeasons] = useState<SeasonRow[]>([]);
  const [episodes, setEpisodes] = useState<TvEpisode[]>([]);
  const [loadingSeasons, setLoadingSeasons] = useState(true);
  const [loadingEpisodes, setLoadingEpisodes] = useState(true);
  const [expanded, setExpanded] = useState(initiallyExpanded);

  const loadEpisodes = (season: number) => {
    setLoadingEpisodes(true);
    void fetchSeasonEpisodes(tmdbId, season).then((eps) => {
      setEpisodes(eps);
      setLoadingEpisodes(false);
    });
  };

  useEffect(() => {
    let alive = true;
    void fetchMediaDetails(tmdbId, 'tv').then((details) => {
      if (!alive) return;
      const raw = Array.isArray(details?.seasons) ? (details.seasons as Record<string, unknown>[]) : [];
      const rows = raw
        .filter(
          (s) => typeof s?.season_number === 'number' && Number.isInteger(s.season_number) && (s.season_number as number) > 0,
        )
        .map((s) => ({
          number: s.season_number as number,
          name: typeof s.name === 'string' ? s.name : `Season ${s.season_number as number}`,
        }));
      setSeasons(rows);
      setLoadingSeasons(false);
      if (rows.length) loadEpisodes(initialSeason);
    });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const selectSeason = (n: number) => {
    if (n === selectedSeason) return;
    setSelectedSeason(n);
    setSelectedEpisode(1);
    loadEpisodes(n);
    onSeasonChanged(n);
  };

  const selectEpisode = (n: number) => {
    if (n === selectedEpisode) return;
    setSelectedEpisode(n);
    onEpisodeChanged(n);
  };

  const spinner = (
    <div style={{ height: 80, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <CircularProgress size={24} strokeWidth={2} color={NetflixColors.accent} />
    </div>
  );
  const empty = (msg: string) => (
    <div style={{ padding: 16, textAlign: 'center', color: white(0.38), fontSize: 12, lineHeight: lineHeight(12, 1.17) }}>
      {msg}
    </div>
  );

  return (
    <div>
      <button
        type="button"
        className="bare-button player-focusable"
        aria-expanded={expanded}
        onClick={() => setExpanded((v) => !v)}
        style={{
          width: '100%',
          padding: '10px 16px',
          background: NetflixColors.surface,
          borderTop: `1px solid ${NetflixColors.hairline}`,
          display: 'flex',
          alignItems: 'center',
          cursor: 'pointer',
        }}
      >
        <Icon name="list" size={18} color={white(0.7)} />
        <div style={{ width: 8 }} />
        <span style={text(13, AppTypography.outfitHeading, { color: '#fff' })}>Episodes</span>
        {!loadingSeasons && seasons.length > 0 && (
          <>
            <div style={{ width: 6 }} />
            <span
              style={{
                padding: '2px 6px',
                background: white(0.08),
                borderRadius: 6,
                ...text(10, AppTypography.outfitBold, { color: white(0.54) }),
              }}
            >
              S{selectedSeason}
            </span>
          </>
        )}
        <div style={{ flex: 1 }} />
        <span style={{ display: 'flex', transform: `rotate(${expanded ? 180 : 0}deg)`, transition: 'transform 200ms' }}>
          <Icon name="expand_more" size={20} color={white(0.54)} />
        </span>
      </button>
      {expanded && (
        <div
          className="drawer-fade-in"
          style={{ background: NetflixColors.background, paddingBottom: 8, animationDuration: '200ms' }}
        >
          {loadingSeasons ? (
            spinner
          ) : seasons.length === 0 ? (
            empty('No season data available')
          ) : (
            <>
              <div className="no-scrollbar" style={{ height: 36, overflowX: 'auto', display: 'flex', padding: '0 16px', gap: 8 }}>
                {seasons.map((s) => {
                  const on = s.number === selectedSeason;
                  return (
                    <button
                      key={s.number}
                      type="button"
                      className="bare-button"
                      onClick={() => selectSeason(s.number)}
                      style={{
                        flexShrink: 0,
                        padding: '6px 14px',
                        borderRadius: 8,
                        background: on ? withAlpha(NetflixColors.accent, 0.16) : white(0.04),
                        border: `1px solid ${on ? withAlpha(NetflixColors.accent, 0.65) : white(0.1)}`,
                        transition: 'background-color 180ms, border-color 180ms',
                        cursor: 'pointer',
                        ...text(11, AppTypography.outfitHeading, {
                          color: on ? NetflixColors.accent : NetflixColors.textSecondary,
                        }),
                      }}
                    >
                      {s.name}
                    </button>
                  );
                })}
              </div>
              <div style={{ height: 8 }} />
              {loadingEpisodes ? (
                spinner
              ) : episodes.length === 0 ? (
                empty('No episode data available')
              ) : (
                <div style={{ maxWidth: 800, margin: '0 auto' }}>
                  {episodes.map((ep, i) => {
                    const epNum = ep.episodeNumber || i + 1;
                    const name = ep.name || `Episode ${epNum}`;
                    return (
                      <EpisodeTile
                        key={`${tmdbId}/${selectedSeason}/${epNum}`}
                        hideSpoilers={prefs.hideSpoilers}
                        revealedByProgress={
                          prefs.hideSpoilers &&
                          shouldReveal(selectedSeason, epNum, {
                            currentSeason: selectedSeason,
                            currentEpisode: selectedEpisode,
                            position: positionSeconds,
                            duration: durationSeconds,
                            allWatched: allEpisodesWatched,
                            completed: currentEpisodeCompleted,
                          })
                        }
                        epNum={epNum}
                        epName={name}
                        epOverview={ep.overview}
                        stillUrl={ep.stillRaw ? TmdbImages.stillFor(ep.stillRaw) : undefined}
                        selected={epNum === selectedEpisode}
                        onTap={() => selectEpisode(epNum)}
                        trailing={
                          <EpisodeDownloadAction
                            tmdbId={tmdbId}
                            season={selectedSeason}
                            epNum={epNum}
                            name={name}
                            stillPath={ep.stillRaw}
                            title={title}
                          />
                        }
                      />
                    );
                  })}
                </div>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}

function EpisodeDownloadAction({
  tmdbId,
  season,
  epNum,
  name,
  stillPath,
  title,
}: {
  tmdbId: number;
  season: number;
  epNum: number;
  name: string;
  stillPath?: string;
  title: string;
}) {
  const offline = useOfflineMedia();
  const id = OfflineIds.cinemaEpisodeId(tmdbId, season, epNum);
  if (offline.isDownloaded(id)) {
    return (
      <Tooltip message="Downloaded for offline viewing">
        <div style={{ padding: 6, borderRadius: '50%', background: withAlpha(NetflixColors.accent, 0.15), display: 'flex' }}>
          <Icon name="offline_pin" size={20} color={NetflixColors.accent} />
        </div>
      </Tooltip>
    );
  }
  if (offline.isDownloading(id)) return <CircularProgress size={24} strokeWidth={2} color={NetflixColors.accent} />;
  return (
    <Tooltip message="Download episode">
      <button
        type="button"
        className="bare-button"
        aria-label="Download episode"
        onClick={(e) => {
          e.stopPropagation();
          showSnackBar(`Downloading S${season} E${epNum} • ${name}...`, { duration: 2000 });
          void offline.startDownloadMedia({
            id,
            type: 'tv',
            mediaId: String(tmdbId),
            title: title || 'TV Series',
            subtitle: `S${season} E${epNum} • ${name}`,
            season,
            episode: epNum,
            coverUrl: stillPath ? TmdbImages.stillFor(stillPath) : '',
          });
        }}
        style={{
          width: 48,
          height: 48,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderRadius: '50%',
          cursor: 'pointer',
        }}
      >
        <Icon name="download_for_offline_outlined" size={22} color={NetflixColors.textMuted} />
      </button>
    </Tooltip>
  );
}

/** episode_list_section.dart `EpisodeTile` (the Everglow look, not the Netflix row). */
function EpisodeTile({
  epNum,
  epName,
  epOverview,
  stillUrl,
  onTap,
  selected,
  hideSpoilers,
  revealedByProgress,
  trailing,
}: {
  epNum: number;
  epName: string;
  epOverview: string;
  stillUrl?: string;
  onTap: () => void;
  selected: boolean;
  hideSpoilers: boolean;
  revealedByProgress: boolean;
  trailing?: ReactNode;
}) {
  const [pressed, setPressed] = useState(false);
  const [revealed, setRevealed] = useState(false);
  const [prevHide, setPrevHide] = useState(hideSpoilers);
  if (prevHide !== hideSpoilers) {
    setPrevHide(hideSpoilers);
    if (prevHide && !hideSpoilers) setRevealed(false);
  }
  const expanded = revealed || revealedByProgress;
  const hidden = hideSpoilers && !expanded;
  return (
    <div
      role="button"
      aria-label={`Play episode ${epNum}`}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      onClick={onTap}
      style={{ height: expanded ? undefined : 80, padding: '5px 20px', boxSizing: 'border-box', cursor: 'pointer' }}
    >
      <div
        style={{
          height: expanded ? undefined : '100%',
          boxSizing: 'border-box',
          background: withAlpha(AppColors.shimmerBase, pressed ? 0.8 : 0.5),
          borderRadius: 16,
          border: `${selected ? 1.4 : 1}px solid ${selected ? withAlpha(AppColors.deepRose, 0.65) : withAlpha(AppColors.roseQuartz, 0.08)}`,
          transition: 'background-color 140ms',
          overflow: 'hidden',
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <div style={{ height: 80, flexShrink: 0, alignSelf: 'center' }}>
          {stillUrl ? (
            <div style={{ width: 100, height: 80, position: 'relative', background: AppColors.shimmerBase }}>
              <img
                src={stillUrl}
                alt=""
                style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
              />
              <div
                style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to right, rgba(0,0,0,0.4), transparent)' }}
              />
              <span
                style={{
                  position: 'absolute',
                  left: 8,
                  bottom: 6,
                  ...text(11, AppTypography.outfitHeading, { color: '#fff', textShadow: '0 0 4px rgba(0,0,0,0.8)' }),
                }}
              >
                EP {epNum}
              </span>
            </div>
          ) : (
            <div
              style={{
                width: 64,
                height: 80,
                background: withAlpha(AppColors.deepRose, pressed ? 0.2 : 0.12),
                borderRadius: '15px 0 0 15px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                ...AppTypography.cormorantBlack,
                fontSize: 28,
                lineHeight: '28px',
                color: AppColors.deepRose,
              }}
            >
              {String(epNum).padStart(2, '0')}
            </div>
          )}
        </div>
        <div style={{ width: 12, flexShrink: 0 }} />
        <div
          style={{
            flex: 1,
            minWidth: 0,
            padding: `${hidden ? 0 : 6}px 0`,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
          }}
        >
          <div
            className={expanded ? 'clamp-2' : undefined}
            style={{
              ...AppTypography.outfitHeading,
              fontSize: 13,
              lineHeight: lineHeight(13, 1.25),
              ...(expanded ? {} : { whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }),
            }}
          >
            {hidden ? `Episode ${epNum}` : epName}
          </div>
          {hidden ? (
            <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
              <button
                type="button"
                className="bare-button"
                onClick={(e) => {
                  e.stopPropagation();
                  setRevealed(true);
                }}
                style={{
                  height: 40,
                  minWidth: 64,
                  padding: 0,
                  borderRadius: 20,
                  cursor: 'pointer',
                  ...AppTypography.labelLarge,
                  lineHeight: lineHeight(14),
                  color: AppColors.deepRose,
                }}
              >
                Reveal details
              </button>
            </div>
          ) : (
            <>
              {epOverview && (
                <>
                  <div style={{ height: 4 }} />
                  <div
                    className={expanded ? 'clamp-3' : 'clamp-2'}
                    style={text(11, AppTypography.outfitWhite, { color: AppColors.mutedPurple, lineHeight: lineHeight(11, 1.4) })}
                  >
                    {epOverview}
                  </div>
                </>
              )}
              {revealed && (
                <div
                  onClick={(e) => {
                    e.stopPropagation();
                    setRevealed(false);
                  }}
                  style={{
                    paddingTop: 6,
                    ...text(10.5, AppTypography.outfitWhite, { color: AppColors.deepRose, fontWeight: 600 }),
                  }}
                >
                  Hide details
                </div>
              )}
            </>
          )}
        </div>
        <div style={{ width: 6, flexShrink: 0 }} />
        {trailing && (
          <>
            {trailing}
            <div style={{ width: 4, flexShrink: 0 }} />
          </>
        )}
        <div style={{ padding: 8, flexShrink: 0 }}>
          <div
            style={{
              width: 32,
              height: 32,
              boxSizing: 'border-box',
              borderRadius: '50%',
              background: selected ? AppColors.deepRose : withAlpha(AppColors.deepRose, 0.15),
              border: `1.2px solid ${withAlpha(AppColors.deepRose, 0.5)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name={selected ? 'pause' : 'play_arrow'} size={18} color={selected ? '#fff' : AppColors.deepRose} />
          </div>
        </div>
      </div>
    </div>
  );
}

/** `UpNextOverlay`: the countdown card in the player's bottom-right corner. */
export function UpNextOverlay({
  next,
  secondsLeft,
  totalSeconds,
  onPlayNow,
  onCancel,
}: {
  next: NextEpisode;
  secondsLeft: number;
  totalSeconds: number;
  onPlayNow: () => void;
  onCancel: () => void;
}) {
  const progress = totalSeconds <= 0 ? 0 : Math.min(1, Math.max(0, secondsLeft / totalSeconds));
  return (
    <div
      style={{
        width: 300,
        boxSizing: 'border-box',
        padding: 14,
        background: withAlpha(NetflixColors.surface, 0.96),
        borderRadius: AppRadius.md,
        border: `1px solid ${NetflixColors.hairline}`,
        boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.5)', blur: 20, offset: [0, 8] }]),
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <span
          style={{
            padding: '3px 8px',
            background: NetflixColors.accent,
            borderRadius: AppRadius.full,
            ...text(10, AppTypography.outfitBold, { color: '#fff', letterSpacing: 1.2 }),
          }}
        >
          UP NEXT
        </span>
        <div style={{ flex: 1 }} />
        <button
          type="button"
          className="bare-button player-focusable"
          aria-label="Cancel"
          onClick={onCancel}
          style={{
            width: 24,
            height: 24,
            borderRadius: 6,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <Icon name="close" size={18} color={NetflixColors.textMuted} />
        </button>
      </div>
      <div style={{ height: 10 }} />
      <div style={text(14, AppTypography.outfitHeading, { color: NetflixColors.textPrimary })}>{nextEpisodeLabel(next)}</div>
      {next.name && (
        <>
          <div style={{ height: 2 }} />
          <div
            style={text(12, AppTypography.outfitWhite, {
              color: NetflixColors.textSecondary,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            })}
          >
            {next.name}
          </div>
        </>
      )}
      <div style={{ height: 10 }} />
      <div style={text(13, AppTypography.outfitWhite, { color: '#fff', fontWeight: 600 })}>Next episode in {secondsLeft}...</div>
      <div style={{ height: 8 }} />
      <div style={{ height: 4, borderRadius: AppRadius.full, overflow: 'hidden', background: white(0.12) }}>
        <div style={{ height: '100%', width: `${progress * 100}%`, background: NetflixColors.accent }} />
      </div>
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', gap: 8 }}>
        <button
          type="button"
          className="bare-button player-focusable"
          onClick={onPlayNow}
          style={{
            flex: 1,
            padding: '10px 0',
            background: NetflixColors.accent,
            borderRadius: AppRadius.sm,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 4,
            cursor: 'pointer',
          }}
        >
          <Icon name="play_arrow" size={18} color="#fff" />
          <span style={text(13, AppTypography.outfitBold, { color: '#fff' })}>Play now</span>
        </button>
        <button
          type="button"
          className="bare-button player-focusable"
          onClick={onCancel}
          style={{
            padding: '10px 14px',
            background: NetflixColors.surfaceElevated,
            borderRadius: AppRadius.sm,
            border: `1px solid ${NetflixColors.hairline}`,
            cursor: 'pointer',
            ...text(13, AppTypography.outfitBold, { color: NetflixColors.textSecondary }),
          }}
        >
          Cancel
        </button>
      </div>
    </div>
  );
}

/** Material IconButton: a 48px round tap slot. */
function RoundIconButton({
  icon,
  size,
  color,
  tooltip,
  onTap,
}: {
  icon: string;
  size: number;
  color: string;
  tooltip: string;
  onTap: () => void;
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
          width: 48,
          height: 48,
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
        }}
      >
        <Icon name={icon} size={size} color={color} />
      </button>
    </Tooltip>
  );
}

/** `TorrentDownloadSheet`: copies of the open title, each opening in a torrent app. */
/** The 48px drag-handle row the app theme's `showDragHandle` adds to the top of every modal sheet. */
export function SheetDragHandle() {
  return (
    <div style={{ alignSelf: 'stretch', height: 48, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ width: 32, height: 4, borderRadius: 2, background: withAlpha(AppColors.moonlight, 0.35) }} />
    </div>
  );
}

export function TorrentDownloadSheet({
  tmdbId,
  mediaType,
  title,
  season,
  episode,
  close,
}: {
  tmdbId: number;
  mediaType: string;
  title: string;
  season?: number;
  episode?: number;
  close: () => void;
}) {
  const [search, setSearch] = useState<TorrentSearch | null>(null);
  const [copied, setCopied] = useState<Set<string>>(new Set());
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let alive = true;
    setSearch(null);
    void searchTorrents({ tmdbId, mediaType, season, episode }).then((r) => alive && setSearch(r));
    return () => {
      alive = false;
    };
  }, [tmdbId, mediaType, season, episode, attempt]);

  const copy = async (c: TorrentCopy) => {
    try {
      await navigator.clipboard.writeText(c.magnet);
    } catch {
      /* clipboard blocked */
    }
    setCopied((s) => new Set(s).add(c.infoHash));
  };
  const open = (c: TorrentCopy) => {
    // A magnet link opens the torrent app when one is installed; copy it either way
    // since the page cannot tell whether an app picked it up.
    window.location.href = c.magnet;
    void copy(c);
  };

  const epLabel = mediaType === 'tv' && season != null && episode != null ? `S${season} E${episode}` : null;
  return (
    <div style={{ maxWidth: 640, margin: '0 auto' }}>
      <div
        style={{
          background: NetflixColors.surface,
          borderRadius: `${AppRadius.x2}px ${AppRadius.x2}px 0 0`,
          height: 'calc(78vh + 48px)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        }}
      >
        <SheetDragHandle />
        <div style={{ height: 10, flexShrink: 0 }} />
        <div style={{ width: 40, height: 4, borderRadius: AppRadius.full, background: NetflixColors.hairline, flexShrink: 0 }} />
        <div style={{ alignSelf: 'stretch', padding: '12px 16px 8px', display: 'flex', alignItems: 'center', flexShrink: 0 }}>
          <Icon name="download" size={20} color="#fff" />
          <div style={{ width: 10 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={text(16, AppTypography.outfitHeading, { color: '#fff' })}>
              {epLabel ? `Download · ${epLabel}` : 'Download'}
            </div>
            <div
              style={text(12, AppTypography.outfitWhite, {
                color: NetflixColors.textSecondary,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              })}
            >
              {title}
            </div>
          </div>
          <RoundIconButton icon="close" size={20} color={white(0.7)} tooltip="Close" onTap={close} />
        </div>
        <div style={{ alignSelf: 'stretch', flex: '1 1 0', minHeight: 0, overflowY: 'auto' }}>
          {search == null ? (
            <div style={{ padding: '42px 0', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <CircularProgress size={22} strokeWidth={2} color={AppColors.deepRose} />
              <div style={{ height: 14 }} />
              <div style={text(12, AppTypography.outfitMuted, { color: NetflixColors.textMuted })}>Looking for copies…</div>
            </div>
          ) : search.copies.length === 0 ? (
            <div style={{ padding: '30px 16px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <Icon name="download_for_offline_outlined" size={30} color={white(0.38)} />
              <div style={{ height: 12 }} />
              <div style={text(13, AppTypography.outfitWhite, { color: NetflixColors.textSecondary, textAlign: 'center' })}>
                {search.reason ?? 'No copies found for this title.'}
              </div>
              <div style={{ height: 6 }} />
              <button
                type="button"
                className="bare-button"
                onClick={() => setAttempt((a) => a + 1)}
                style={{
                  height: 40,
                  padding: '0 12px',
                  ...AppTypography.labelLarge,
                  lineHeight: lineHeight(14),
                  color: AppColors.deepRose,
                  cursor: 'pointer',
                }}
              >
                Try again
              </button>
            </div>
          ) : (
            <div style={{ padding: '0 16px 12px' }}>
              {search.copies.map((c) => (
                <div key={c.infoHash} style={{ paddingBottom: 8 }}>
                  <CopyTile copy={c} copied={copied.has(c.infoHash)} onTap={() => open(c)} onCopy={() => void copy(c)} />
                </div>
              ))}
            </div>
          )}
        </div>
        <div
          style={{
            padding: '0 16px 12px',
            flexShrink: 0,
            textAlign: 'center',
            ...text(11, AppTypography.outfitMuted, { color: NetflixColors.textMuted, lineHeight: lineHeight(11, 1.35) }),
          }}
        >
          Copies open in a torrent app. No app on this device? Copy the link and paste it there.
        </div>
      </div>
    </div>
  );
}

function CopyTile({
  copy,
  copied,
  onTap,
  onCopy,
}: {
  copy: TorrentCopy;
  copied: boolean;
  onTap: () => void;
  onCopy: () => void;
}) {
  const meta = [copy.size, copy.seeders > 0 ? `${copy.seeders} seeds` : '', copy.provider].filter(Boolean).join(' · ');
  return (
    <div
      role="button"
      onClick={onTap}
      style={{
        background: NetflixColors.surfaceElevated,
        borderRadius: AppRadius.sm,
        padding: '10px 4px 10px 12px',
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
      }}
    >
      {copy.quality && (
        <span
          style={{
            padding: '4px 8px',
            background: white(0.08),
            borderRadius: AppRadius.xs,
            border: `1px solid ${NetflixColors.hairline}`,
            ...text(10, AppTypography.outfitHeading, { color: '#fff' }),
          }}
        >
          {copy.quality}
        </span>
      )}
      <div style={{ width: 10, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          className="clamp-2"
          style={{
            ...AppTypography.outfitWhite,
            color: '#fff',
            fontSize: 12.5,
            lineHeight: lineHeight(12.5, 1.3),
            wordBreak: 'break-all',
          }}
        >
          {copy.filename}
        </div>
        {meta && (
          <div
            style={{
              paddingTop: 3,
              ...text(11, AppTypography.outfitMuted, {
                color: NetflixColors.textMuted,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }),
            }}
          >
            {meta}
          </div>
        )}
      </div>
      <RoundIconButton
        icon={copied ? 'check' : 'link'}
        size={18}
        color={copied ? NetflixColors.match : white(0.7)}
        tooltip={copied ? 'Copied' : 'Copy link'}
        onTap={onCopy}
      />
    </div>
  );
}
