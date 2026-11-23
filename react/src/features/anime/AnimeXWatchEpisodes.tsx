// Faithful port of animex_watch_page_episodes.dart, animex_episodes_mobile.dart,
// animex_episodes_desktop.dart and the spoiler helpers of animex_watch_page_sheets.dart.
import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { OfflineIds, useOfflineMedia } from '../../core/services/offlineMedia';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { TextButton, showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { MaterialSwitch } from '../../shared/widgets/MaterialFields';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { SheetDragHandle } from '../cinema/VideoPlayerWidgets';
import type { AniListEpisode, AniListSeason } from './animexData';
import { AnimexStores, useAnimexStores } from './animexStores';
import { AnimeXTokens, dmSansStyle, interBodyStyle } from './animeTokens';

const T = AnimeXTokens;
const white = (a: number) => withAlpha('#FFFFFF', a);
const ellipsis = (lines: number): CSSProperties =>
  lines === 1
    ? { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }
    : { display: '-webkit-box', WebkitLineClamp: lines, WebkitBoxOrient: 'vertical', overflow: 'hidden' };
const ymd = (d: Date) => `${d.getFullYear()}-${`${d.getMonth() + 1}`.padStart(2, '0')}-${`${d.getDate()}`.padStart(2, '0')}`;

export const episodeWithoutSpoilers = (e: AniListEpisode): AniListEpisode => ({
  number: e.number,
  duration: e.duration,
  airedAt: e.airedAt,
});

function useHideSpoilers() {
  useAnimexStores();
  return AnimexStores.hideSpoilers;
}

function smoothScroll(el: HTMLElement, axis: 'left' | 'top', target: number) {
  const max = axis === 'left' ? el.scrollWidth - el.clientWidth : el.scrollHeight - el.clientHeight;
  el.scrollTo({ [axis]: Math.min(Math.max(target, 0), Math.max(max, 0)), behavior: 'smooth' });
}

function filterEpisodes(episodes: AniListEpisode[], query: string, selected: number, hideSpoilers: boolean, ascending: boolean) {
  let list = episodes;
  if (query) {
    list = list.filter((e) => {
      const numStr = `${e.number}`;
      const padded = numStr.padStart(2, '0');
      const hidden = hideSpoilers && e.number >= selected;
      const t = hidden ? '' : (e.title ?? '').toLowerCase();
      const s = hidden ? '' : (e.synopsis ?? '').toLowerCase();
      return (
        numStr === query ||
        padded === query ||
        `episode ${numStr}`.includes(query) ||
        `ep ${numStr}`.includes(query) ||
        t.includes(query) ||
        s.includes(query)
      );
    });
  }
  return ascending ? list : [...list].reverse();
}

// ---------- _EpisodeThumbnail ----------

function Img({ src, fallback, placeholder }: { src?: string; fallback?: string; placeholder: ReactNode }) {
  const [stage, setStage] = useState(0);
  useEffect(() => setStage(0), [src, fallback]);
  const urls = [src, fallback].filter((u): u is string => !!u);
  const url = urls[stage];
  if (!url) return <>{placeholder}</>;
  return (
    <img
      src={url}
      alt=""
      onError={() => setStage((s) => s + 1)}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
    />
  );
}

export function EpisodeThumbnail({
  episode,
  fallbackPoster,
  isPlaying,
  width,
  height,
  compact = false,
}: {
  episode: AniListEpisode;
  fallbackPoster: string;
  isPlaying: boolean;
  width: number;
  height: number;
  /** Small rail rows: labels move outside the frame so they never collide. */
  compact?: boolean;
}) {
  const placeholder = (
    <div style={{ position: 'absolute', inset: 0, background: T.surfaceRaised, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Icon name="movie_filter" size={26} color={withAlpha(T.textMuted, 0.5)} />
    </div>
  );
  return (
    <div
      style={{
        position: 'relative',
        width,
        height,
        flexShrink: 0,
        borderRadius: T.radiusMd,
        overflow: 'hidden',
        background: T.surfaceRaised,
      }}
    >
      <Img src={episode.thumbnail || undefined} fallback={fallbackPoster || undefined} placeholder={placeholder} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: linear(['rgba(0,0,0,0)', 'rgba(0,0,0,0.333)', 'rgba(0,0,0,0.8)'], { begin: Align.topCenter, end: Align.bottomCenter, stops: [0.3, 0.65, 1] }),
        }}
      />
      {isPlaying && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: withAlpha(T.accent, 0.25),
            border: `2px solid ${T.accentWarm}`,
            borderRadius: T.radiusMd,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <div style={{ padding: 6, borderRadius: '50%', background: 'rgba(0,0,0,0.65)', display: 'flex' }}>
            <Icon name="play_arrow" size={18} color={T.accentWarm} />
          </div>
        </div>
      )}
      {!compact && (
        <div
          style={{
            position: 'absolute',
            left: 6,
            bottom: 6,
            padding: '2.5px 6px',
            background: T.accent,
            borderRadius: T.radiusSm,
            boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.4)', blur: 4, offset: [0, 1] }]),
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <Icon name="play_arrow" size={10} color="#FFFFFF" />
          <div style={{ width: 2.5 }} />
          <span style={dmSansStyle({ size: 10.5, color: '#FFFFFF', weight: 700 })}>Episode {episode.number}</span>
        </div>
      )}
      {!compact && episode.duration != null && episode.duration > 0 && (
        <div
          style={{
            position: 'absolute',
            right: 6,
            bottom: 6,
            padding: '2px 4.5px',
            background: 'rgba(0,0,0,0.867)',
            borderRadius: 3,
          }}
        >
          <span style={dmSansStyle({ size: 9.5, color: '#FFFFFF', weight: 600 })}>{episode.duration}m</span>
        </div>
      )}
    </div>
  );
}

// ---------- Download button ----------

function DownloadButton({
  animeId,
  episode,
  animeTitle,
  fallbackPoster,
  desktop,
}: {
  animeId: number;
  episode: AniListEpisode;
  animeTitle: string;
  fallbackPoster: string;
  desktop?: boolean;
}) {
  const offline = useOfflineMedia();
  const id = OfflineIds.animeEpisodeId(animeId, episode.number);
  if (offline.isDownloaded(id)) {
    return (
      <div style={{ paddingLeft: 6, paddingTop: desktop ? 2 : 0, flexShrink: 0 }}>
        <Tooltip message="Downloaded for offline viewing">
          <Icon name="offline_pin" size={18} color={T.accent} />
        </Tooltip>
      </div>
    );
  }
  if (offline.isDownloading(id)) {
    return (
      <div style={{ paddingLeft: 6, paddingTop: desktop ? 2 : 0, flexShrink: 0 }}>
        <CircularProgress size={16} strokeWidth={2} color={T.accent} />
      </div>
    );
  }
  return (
    <div style={{ paddingLeft: 4, flexShrink: 0 }}>
      <Tooltip message="Download episode">
        <button
          type="button"
          className="bare-button"
          aria-label="Download episode"
          onClick={(ev) => {
            ev.stopPropagation();
            showSnackBar(`Downloading Episode ${episode.number}...`, { duration: 2000 });
            void offline.startDownloadMedia({
              id,
              type: 'anime',
              mediaId: `${animeId}`,
              title: animeTitle,
              subtitle: `Episode ${episode.number} • ${episode.title ?? ''}`,
              season: 1,
              episode: episode.number,
              coverUrl: episode.thumbnail ?? fallbackPoster,
            });
          }}
          style={{ width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '50%' }}
        >
          <Icon name="download_for_offline_outlined" size={18} color={T.textMuted} />
        </button>
      </Tooltip>
    </div>
  );
}

function useRevealed(episodeNumber: number, hideSpoilers: boolean) {
  const [revealed, setRevealed] = useState(false);
  const prev = useRef({ episodeNumber, hideSpoilers });
  useLayoutEffect(() => {
    if (prev.current.episodeNumber !== episodeNumber) setRevealed(false);
    else if (prev.current.hideSpoilers && !hideSpoilers) setRevealed(false);
    prev.current = { episodeNumber, hideSpoilers };
  }, [episodeNumber, hideSpoilers]);
  return [revealed, setRevealed] as const;
}

function HideDetailsLink({ onTap, gap }: { onTap: () => void; gap: number }) {
  return (
    <div
      onClick={(ev) => {
        ev.stopPropagation();
        onTap();
      }}
      style={{ display: 'inline-flex', alignItems: 'center', cursor: 'pointer' }}
    >
      <Icon name="visibility_off_outlined" size={12} color={T.accentWarm} />
      <div style={{ width: gap }} />
      <span style={dmSansStyle({ size: 10.5, color: T.accentWarm, weight: 600 })}>Hide details</span>
    </div>
  );
}

function RevealButton({ onTap, iconSize, textStyle }: { onTap: () => void; iconSize: number; textStyle?: CSSProperties }) {
  return (
    <div onClick={(ev) => ev.stopPropagation()} style={{ display: 'inline-block' }}>
      <TextButton
        onPressed={onTap}
        color={T.accentWarm}
        icon={<Icon name="visibility_outlined" size={iconSize} color={T.accentWarm} />}
        style={{ padding: 0, ...textStyle }}
      >
        Reveal details
      </TextButton>
    </div>
  );
}

// ---------- _HideSpoilersSwitch ----------

export function HideSpoilersSwitch() {
  const hide = useHideSpoilers();
  const toggle = (v: boolean) => AnimexStores.setHideSpoilers(v);
  const [hover, setHover] = useState(false);
  return (
    <div
      onClick={() => toggle(!hide)}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        minHeight: 56,
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
        background: hover ? withAlpha(AppColors.petalWhite, 0.04) : undefined,
      }}
    >
      <div style={{ flex: 1, minWidth: 0, ...dmSansStyle({ size: 12, color: T.textPrimary }) }}>Hide spoilers</div>
      <div onClick={(e) => e.stopPropagation()}>
        <MaterialSwitch value={hide} onChanged={toggle} />
      </div>
    </div>
  );
}

interface CardProps {
  episode: AniListEpisode;
  fallbackPoster: string;
  animeTitle: string;
  animeId: number;
  isPlaying: boolean;
  hideSpoilers: boolean;
  onTap: () => void;
  onInfoTap: () => void;
}

export interface EpisodesProps {
  episodes: AniListEpisode[];
  selectedEpisode: number;
  animeTitle: string;
  animeId: number;
  fallbackPoster: string;
  onSelectEpisode: (n: number) => void;
  onShowInfo: (e: AniListEpisode) => void;
  seasons: AniListSeason[];
  onSelectSeason?: (s: AniListSeason) => void;
  nextSeason?: AniListSeason;
}

function infoTapFor(p: EpisodesProps, hideSpoilers: boolean, ep: AniListEpisode, active: boolean) {
  return () => {
    if (hideSpoilers && ep.number >= p.selectedEpisode) {
      showEpisodeInfoSheet({
        episode: ep,
        animeTitle: p.animeTitle,
        fallbackPoster: p.fallbackPoster,
        isPlaying: active,
        onPlay: () => p.onSelectEpisode(ep.number),
      });
    } else {
      p.onShowInfo(ep);
    }
  };
}

function Pill({ active, onTap, children, style }: { active?: boolean; onTap: () => void; children: ReactNode; style?: CSSProperties }) {
  return (
    <div
      onClick={onTap}
      style={{
        display: 'flex',
        alignItems: 'center',
        background: active ? withAlpha(T.accent, 0.2) : white(0.06),
        borderRadius: 999,
        border: `1px solid ${active ? T.accent : T.border}`,
        cursor: 'pointer',
        boxSizing: 'border-box',
        ...style,
      }}
    >
      {children}
    </div>
  );
}

/** One episode of a binge list: thumb, number chip, title, duration, state. */
function MobileEpisodeRow(p: CardProps) {
  const [revealed, setRevealed] = useRevealed(p.episode.number, p.hideSpoilers);
  const hidden = p.hideSpoilers && !revealed;
  const ep = hidden ? episodeWithoutSpoilers(p.episode) : p.episode;
  const title = !hidden && ep.title ? ep.title : `Episode ${ep.number}`;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={p.onTap}
      aria-current={p.isPlaying ? 'true' : undefined}
      style={{
        width: '100%',
        minHeight: 68,
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: '8px 6px',
        boxSizing: 'border-box',
        borderRadius: T.radiusLg,
        background: p.isPlaying ? withAlpha(T.accent, 0.14) : 'transparent',
        border: `1px solid ${p.isPlaying ? withAlpha(T.accent, 0.5) : 'transparent'}`,
        textAlign: 'left',
      }}
    >
      <div style={{ position: 'relative', flexShrink: 0, width: 104 }}>
        <EpisodeThumbnail
          episode={p.episode}
          fallbackPoster={p.fallbackPoster}
          isPlaying={p.isPlaying}
          width={104}
          height={59}
          compact
        />
        <div
          style={{
            position: 'absolute',
            left: 4,
            bottom: 4,
            padding: '1px 5px',
            borderRadius: 4,
            background: 'rgba(0,0,0,0.75)',
            ...dmSansStyle({ size: 10, color: '#FFFFFF', weight: 800 }),
          }}
        >
          E{p.episode.number}
        </div>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...dmSansStyle({ size: 13.5, color: p.isPlaying ? T.accentWarm : T.textPrimary, weight: 700, height: 1.3 }),
            ...ellipsis(2),
          }}
        >
          {title}
        </div>
        <div style={{ height: 2 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {p.isPlaying && <span style={dmSansStyle({ size: 11, color: T.accentText, weight: 700 })}>Watching now</span>}
          {!p.isPlaying && ep.duration != null && ep.duration > 0 && (
            <span style={dmSansStyle({ size: 11.5, color: T.textSecondary })}>{ep.duration} min</span>
          )}
        </div>
      </div>
      {hidden ? (
        <div
          onClick={(ev) => {
            ev.stopPropagation();
            setRevealed(true);
          }}
          style={{ padding: 8, display: 'flex' }}
        >
          <Icon name="visibility" size={18} color={T.textSecondary} />
        </div>
      ) : (
        <DownloadButton animeId={p.animeId} episode={p.episode} animeTitle={p.animeTitle} fallbackPoster={p.fallbackPoster} />
      )}
    </button>
  );
}

export function MobileEpisodesSection(p: EpisodesProps) {
  const hideSpoilers = useHideSpoilers();
  const [showSearch, setShowSearch] = useState(false);
  const [ascending, setAscending] = useState(true);
  const [text, setText] = useState('');
  const query = text.trim().toLowerCase();

  const displayList = filterEpisodes(p.episodes, query, p.selectedEpisode, hideSpoilers, ascending);
  const upNext = p.episodes.find((e) => e.number === p.selectedEpisode + 1);

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span style={dmSansStyle({ size: 14, color: T.textPrimary, weight: 800, letterSpacing: 0.1 })}>EPISODES</span>
          <span style={dmSansStyle({ size: 12, color: T.textSecondary, weight: 600 })}>{p.episodes.length}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          {p.seasons.length > 1 && (
            <Pill
              onTap={() => showSeasonPickerSheet({ seasons: p.seasons, onSelectSeason: (s) => p.onSelectSeason?.(s) })}
              style={{ minHeight: 40, padding: '0 10px' }}
            >
              <Icon name="layers" size={14} color={T.accentText} />
              <div style={{ width: 4 }} />
              <span style={dmSansStyle({ size: 11.5, color: T.textPrimary, weight: 600 })}>Season</span>
              <Icon name="keyboard_arrow_down" size={14} color={T.textSecondary} />
            </Pill>
          )}
          <Pill
            active={showSearch}
            onTap={() => {
              if (showSearch) setText('');
              setShowSearch(!showSearch);
            }}
            style={{ width: 40, height: 40, justifyContent: 'center' }}
          >
            <Icon name="search" size={17} color={showSearch ? T.accentText : T.textSecondary} />
          </Pill>
          <Pill
            onTap={() => setAscending(!ascending)}
            style={{ width: 40, height: 40, justifyContent: 'center' }}
          >
            <Icon name="swap_vert" size={17} color={T.textSecondary} />
          </Pill>
          <Pill
            active={hideSpoilers}
            onTap={() => AnimexStores.setHideSpoilers(!hideSpoilers)}
            style={{ width: 40, height: 40, justifyContent: 'center' }}
          >
            <Icon name={hideSpoilers ? 'visibility_off' : 'visibility'} size={17} color={hideSpoilers ? T.accentText : T.textSecondary} />
          </Pill>
        </div>
      </div>

      {showSearch && (
        <>
          <div style={{ height: 10 }} />
          <div
            style={{
              height: 40,
              boxSizing: 'border-box',
              background: T.surface,
              borderRadius: T.radiusMd,
              border: `1px solid ${T.borderStrong}`,
              padding: '0 10px',
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <Icon name="search" size={16} color={T.textSecondary} />
            <div style={{ width: 8 }} />
            <input
              autoFocus
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Search by title, number, or keyword..."
              className="animex-input"
              style={{
                flex: 1,
                minWidth: 0,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                padding: 0,
                ...dmSansStyle({ size: 12.5, color: T.textPrimary }),
              }}
            />
            {query && (
              <div onClick={() => setText('')} style={{ cursor: 'pointer', display: 'flex' }}>
                <Icon name="close" size={16} color={T.textSecondary} />
              </div>
            )}
          </div>
        </>
      )}

      <div style={{ height: 12 }} />

      {!query && upNext && (
        <div style={{ marginBottom: 10 }}>
          <button
            type="button"
            className="bare-button"
            onClick={() => p.onSelectEpisode(upNext.number)}
            style={{
              width: '100%',
              minHeight: 56,
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '0 12px',
              borderRadius: T.radiusLg,
              background: white(0.05),
              border: `1px solid ${T.border}`,
              textAlign: 'left',
            }}
          >
            <Icon name="skip_next" size={18} color={T.accentText} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={dmSansStyle({ size: 10.5, color: T.textSecondary, weight: 800, letterSpacing: 0.08 })}>UP NEXT</div>
              <div style={{ height: 2 }} />
              <div style={{ ...dmSansStyle({ size: 13, color: T.textPrimary, weight: 600 }), ...ellipsis(1) }}>
                Episode {upNext.number}
                {hideSpoilers || !upNext.title ? '' : ` · ${upNext.title}`}
              </div>
            </div>
            <span style={dmSansStyle({ size: 12, color: T.accentText, weight: 700 })}>Play</span>
          </button>
        </div>
      )}

      {displayList.length === 0 ? (
        <div style={{ padding: '24px 0', textAlign: 'center', ...dmSansStyle({ size: 12.5, color: T.textSecondary }) }}>
          No episodes found matching "{query}"
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          {displayList.map((ep) => {
            const active = ep.number === p.selectedEpisode;
            return (
              <MobileEpisodeRow
                key={ep.number}
                episode={ep}
                fallbackPoster={p.fallbackPoster}
                animeTitle={p.animeTitle}
                animeId={p.animeId}
                isPlaying={active}
                hideSpoilers={hideSpoilers && ep.number >= p.selectedEpisode}
                onTap={() => p.onSelectEpisode(ep.number)}
                onInfoTap={infoTapFor(p, hideSpoilers, ep, active)}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}

// ---------- _DesktopEpisodeTile ----------

function DesktopEpisodeTile(p: CardProps) {
  const [hovered, setHovered] = useState(false);
  const [revealed, setRevealed] = useRevealed(p.episode.number, p.hideSpoilers);
  const hidden = p.hideSpoilers && !revealed;
  const ep = hidden ? episodeWithoutSpoilers(p.episode) : p.episode;
  const title = !hidden && ep.title ? ep.title : `Episode ${ep.number}`;
  const synopsis = ep.synopsis?.trim() ?? '';
  const synStyle = dmSansStyle({ size: 11, color: withAlpha(T.textSecondary, 0.85), height: 1.35 });
  return (
    <div
      onClick={p.onTap}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        padding: 8,
        borderRadius: T.radiusMd,
        background: p.isPlaying ? withAlpha(T.accent, 0.14) : hovered ? white(0.05) : 'transparent',
        border: `1px solid ${p.isPlaying ? withAlpha(T.accent, 0.5) : hovered ? white(0.12) : 'transparent'}`,
        transition: 'background-color 140ms, border-color 140ms',
        display: 'flex',
        alignItems: 'flex-start',
        cursor: 'pointer',
      }}
    >
      <EpisodeThumbnail episode={p.episode} fallbackPoster={p.fallbackPoster} isPlaying={p.isPlaying} width={116} height={66} />
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...dmSansStyle({ size: 12.5, color: p.isPlaying ? T.accentWarm : T.textPrimary, weight: 600, height: 1.25 }),
            ...ellipsis(2),
          }}
        >
          {title}
        </div>
        <div style={{ height: 3 }} />
        <div style={{ ...dmSansStyle({ size: 11, color: T.textSecondary }), ...ellipsis(1) }}>{p.animeTitle}</div>
        <div style={{ height: 4 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', columnGap: 8 }}>
          {p.isPlaying && (
            <div style={{ padding: '1.5px 6px', background: withAlpha(T.accent, 0.2), borderRadius: 3 }}>
              <span style={dmSansStyle({ size: 10, color: T.accentWarm, weight: 700 })}>Watching</span>
            </div>
          )}
          {hidden ? (
            <RevealButton onTap={() => setRevealed(true)} iconSize={14} textStyle={dmSansStyle({ size: 11, color: T.accentWarm })} />
          ) : revealed ? (
            <div>
              <div style={{ ...synStyle, ...ellipsis(4) }}>
                {synopsis || 'No detailed synopsis is available for this episode yet.'}
              </div>
              <div style={{ height: 4 }} />
              <HideDetailsLink onTap={() => setRevealed(false)} gap={3} />
            </div>
          ) : synopsis ? (
            <div
              onClick={(ev) => {
                ev.stopPropagation();
                p.onInfoTap();
              }}
              style={{ ...synStyle, ...ellipsis(3) }}
            >
              {synopsis}
            </div>
          ) : ep.airedAt ? (
            <span style={dmSansStyle({ size: 10, color: T.textMuted })}>{ymd(ep.airedAt)}</span>
          ) : null}
        </div>
      </div>
      <DownloadButton animeId={p.animeId} episode={p.episode} animeTitle={p.animeTitle} fallbackPoster={p.fallbackPoster} desktop />
    </div>
  );
}

// ---------- _DesktopEpisodesSidebar ----------

function SeasonDropdownButton({ seasons, onSelectSeason }: { seasons: AniListSeason[]; onSelectSeason?: (s: AniListSeason) => void }) {
  const [open, setOpen] = useState(false);
  const current = seasons.find((s) => s.isCurrent) ?? seasons[0]!;
  return (
    <div style={{ position: 'relative' }}>
      <div
        title="Change Season"
        onClick={() => setOpen(!open)}
        style={{
          maxWidth: 190,
          boxSizing: 'border-box',
          padding: '4.5px 9px',
          background: white(0.06),
          borderRadius: T.radiusMd,
          border: `1px solid ${T.border}`,
          display: 'flex',
          alignItems: 'center',
          cursor: 'pointer',
        }}
      >
        <Icon name="layers" size={13} color={T.accentWarm} />
        <div style={{ width: 6 }} />
        <span style={{ ...dmSansStyle({ size: 11.5, color: T.textPrimary, weight: 600 }), ...ellipsis(1), minWidth: 0 }}>{current.label}</span>
        <div style={{ width: 4 }} />
        <Icon name="keyboard_arrow_down" size={14} color={T.textSecondary} />
      </div>
      {open && (
        <>
          <div onClick={() => setOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 50 }} />
          <div
            style={{
              position: 'absolute',
              right: 0,
              top: 36,
              zIndex: 51,
              minWidth: 112,
              maxWidth: 280,
              padding: '8px 0',
              background: T.surfaceRaised,
              borderRadius: T.radiusMd,
              border: `1px solid ${T.borderStrong}`,
              boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.3)', blur: 8, offset: [0, 4] }]),
            }}
          >
            {seasons.map((season) => {
              const isCurrent = season.isCurrent;
              const meta = [
                season.format,
                ...(season.episodeCount && season.episodeCount > 0 ? [`${season.episodeCount} eps`] : []),
                ...(season.year && season.year > 0 ? [`${season.year}`] : []),
              ].join(' • ');
              return (
                <div
                  key={season.id}
                  title={season.title !== season.label ? season.title : undefined}
                  onClick={() => {
                    setOpen(false);
                    if (!isCurrent) onSelectSeason?.(season);
                  }}
                  style={{ height: 48, padding: '0 12px', display: 'flex', alignItems: 'center', cursor: 'pointer' }}
                >
                  <Icon
                    name={isCurrent ? 'check_circle' : 'radio_button_unchecked'}
                    size={16}
                    color={isCurrent ? T.accentWarm : T.textMuted}
                  />
                  <div style={{ width: 10 }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div
                      style={{
                        ...dmSansStyle({ size: 12.5, color: isCurrent ? T.accentWarm : T.textPrimary, weight: isCurrent ? 700 : 500 }),
                        ...ellipsis(1),
                      }}
                    >
                      {season.label}
                    </div>
                    {meta && <div style={dmSansStyle({ size: 10.5, color: T.textMuted })}>{meta}</div>}
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

export function DesktopEpisodesSidebar(p: EpisodesProps) {
  const hideSpoilers = useHideSpoilers();
  const [ascending, setAscending] = useState(true);
  const [text, setText] = useState('');
  const query = text.trim().toLowerCase();
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = listRef.current;
    if (!el || !p.episodes.length) return;
    const activeIndex = p.episodes.findIndex((e) => e.number === p.selectedEpisode);
    if (activeIndex <= 0) return;
    smoothScroll(el, 'top', activeIndex * 84 - 100);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [p.selectedEpisode]);

  const find = (n: number) => p.episodes.find((e) => e.number === n);
  const currentEp = find(p.selectedEpisode);
  const currentTitle = hideSpoilers ? `Episode ${p.selectedEpisode}` : (currentEp?.title ?? `Episode ${p.selectedEpisode}`);
  const nextEp = find(p.selectedEpisode + 1);
  const nextTitle =
    (nextEp == null ? undefined : hideSpoilers ? `Episode ${nextEp.number}` : nextEp.title) ??
    (p.selectedEpisode < p.episodes.length
      ? `Episode ${p.selectedEpisode + 1}`
      : p.nextSeason
        ? `${p.nextSeason.label} (Episode 1)`
        : undefined);
  const displayList = filterEpisodes(p.episodes, query, p.selectedEpisode, hideSpoilers, ascending);
  const box: CSSProperties = {
    height: 34,
    boxSizing: 'border-box',
    background: white(0.05),
    borderRadius: T.radiusMd,
    border: `1px solid ${T.border}`,
    padding: '0 10px',
    display: 'flex',
    alignItems: 'center',
  };

  return (
    <div
      style={{
        height: '100%',
        boxSizing: 'border-box',
        background: T.surface,
        borderRadius: T.radiusLg,
        border: `1px solid ${T.border}`,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ padding: '16px 16px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span style={dmSansStyle({ size: 16, color: T.textPrimary, weight: 700 })}>Episodes</span>
          <div style={{ width: 8 }} />
          <div style={{ padding: '2px 7px', background: white(0.08), borderRadius: 10 }}>
            <span style={dmSansStyle({ size: 11, color: T.textSecondary, weight: 600 })}>{p.episodes.length}</span>
          </div>
          {p.seasons.length > 1 && (
            <>
              <div style={{ width: 8 }} />
              <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end', minWidth: 0 }}>
                <SeasonDropdownButton seasons={p.seasons} onSelectSeason={p.onSelectSeason} />
              </div>
            </>
          )}
        </div>
        <div style={{ height: 5 }} />
        <div style={{ ...dmSansStyle({ size: 11.5, color: T.textSecondary }), ...ellipsis(1) }}>
          {hideSpoilers ? `Playing Episode ${p.selectedEpisode}` : `Playing Episode ${p.selectedEpisode} - ${currentTitle}`}
        </div>
        {nextTitle != null && (
          <>
            <div style={{ height: 2 }} />
            <div style={{ ...dmSansStyle({ size: 11, color: T.accentWarm, weight: 500 }), ...ellipsis(1) }}>Up next: {nextTitle}</div>
          </>
        )}
        <HideSpoilersSwitch />
        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ ...box, flex: 1, minWidth: 0 }}>
            <Icon name="search" size={16} color={T.textMuted} />
            <div style={{ width: 8 }} />
            <input
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Find episode"
              className="animex-input"
              style={{
                flex: 1,
                minWidth: 0,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                padding: 0,
                ...dmSansStyle({ size: 12, color: T.textPrimary }),
              }}
            />
            {query && (
              <div onClick={() => setText('')} style={{ cursor: 'pointer', display: 'flex' }}>
                <Icon name="close" size={15} color={T.textMuted} />
              </div>
            )}
          </div>
          <div style={{ width: 8 }} />
          <div onClick={() => setAscending(!ascending)} style={{ ...box, cursor: 'pointer' }}>
            <Icon name="swap_vert" size={15} color={T.textSecondary} />
            <div style={{ width: 4 }} />
            <span style={dmSansStyle({ size: 11.5, color: T.textSecondary, weight: 600 })}>{ascending ? 'Oldest' : 'Newest'}</span>
          </div>
        </div>
      </div>
      <div style={{ height: 1, background: T.border, flexShrink: 0 }} />
      <div style={{ flex: 1, minHeight: 0 }}>
        {displayList.length === 0 ? (
          <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', ...dmSansStyle({ size: 12.5, color: T.textMuted }) }}>
            No episodes found
          </div>
        ) : (
          <div ref={listRef} style={{ height: '100%', overflowY: 'auto', padding: 8, boxSizing: 'border-box', display: 'flex', flexDirection: 'column', gap: 4 }}>
            {displayList.map((ep) => {
              const active = ep.number === p.selectedEpisode;
              return (
                <DesktopEpisodeTile
                  key={ep.number}
                  episode={ep}
                  fallbackPoster={p.fallbackPoster}
                  animeTitle={p.animeTitle}
                  animeId={p.animeId}
                  isPlaying={active}
                  hideSpoilers={hideSpoilers && ep.number >= p.selectedEpisode}
                  onTap={() => p.onSelectEpisode(ep.number)}
                  onInfoTap={infoTapFor(p, hideSpoilers, ep, active)}
                />
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

// ---------- Sheets ----------

const sheetBox: CSSProperties = {
  background: T.surfaceRaised,
  borderRadius: '20px 20px 0 0',
  width: '100%',
  maxWidth: 640,
  margin: '0 auto',
  boxSizing: 'border-box',
  display: 'flex',
  flexDirection: 'column',
  paddingBottom: 'env(safe-area-inset-bottom, 0px)',
};

function EpisodeInfoSheet({
  episode,
  animeTitle,
  fallbackPoster,
  isPlaying,
  onPlay,
  hideSpoilers,
  close,
}: {
  episode: AniListEpisode;
  animeTitle: string;
  fallbackPoster: string;
  isPlaying: boolean;
  onPlay: () => void;
  hideSpoilers: boolean;
  close: () => void;
}) {
  const [revealed, setRevealed] = useState(!hideSpoilers);
  const ep = revealed ? episode : episodeWithoutSpoilers(episode);
  const title = ep.title ? ep.title : `Episode ${ep.number}`;
  const synopsis = ep.synopsis?.trim() ?? '';
  const chip = (label: string) => (
    <div style={{ padding: '2px 6px', background: white(0.08), borderRadius: 4 }}>
      <span style={dmSansStyle({ size: 10.5, color: T.textSecondary, weight: 600 })}>{label}</span>
    </div>
  );
  return (
    <div style={{ ...sheetBox, maxHeight: '75dvh' }}>
      <SheetDragHandle />
      <div style={{ height: 12, flexShrink: 0 }} />
      <div style={{ width: 40, height: 4, borderRadius: 2, background: T.textMuted, alignSelf: 'center', flexShrink: 0 }} />
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '16px 20px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start' }}>
          <EpisodeThumbnail episode={episode} fallbackPoster={fallbackPoster} isPlaying={isPlaying} width={120} height={68} />
          <div style={{ width: 14 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={dmSansStyle({ size: 15, color: T.textPrimary, weight: 700, height: 1.25 })}>{title}</div>
            <div style={{ height: 4 }} />
            <div style={dmSansStyle({ size: 12, color: T.textSecondary })}>{animeTitle}</div>
            <div style={{ height: 6 }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 6 }}>
              {ep.duration != null && ep.duration > 0 && chip(`${ep.duration} min`)}
              {ep.airedAt && chip(`Aired ${ymd(ep.airedAt)}`)}
            </div>
          </div>
        </div>
        <div style={{ height: 18 }} />
        <div style={{ height: 1, background: T.border }} />
        <div style={{ height: 14 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <Icon name="auto_stories_outlined" size={18} color={T.accentWarm} />
          <div style={{ width: 6 }} />
          <div style={{ flex: 1, ...dmSansStyle({ size: 13.5, color: T.accentWarm, weight: 700 }) }}>
            {revealed ? 'What happened in this episode' : 'Episode details hidden'}
          </div>
        </div>
        <div style={{ height: 8 }} />
        <div style={interBodyStyle({ size: 13, color: T.textSecondary, height: 1.6 })}>
          {!revealed
            ? 'Reveal the title and synopsis for this episode?'
            : synopsis || 'No detailed synopsis is available for this episode yet.'}
        </div>
        {!revealed && (
          <>
            <div style={{ height: 8 }} />
            <TextButton
              onPressed={() => setRevealed(true)}
              color={T.accentWarm}
              icon={<Icon name="visibility_outlined" size={18} color={T.accentWarm} />}
            >
              Reveal details
            </TextButton>
          </>
        )}
        <div style={{ height: 20 }} />
        {!isPlaying && (
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              close();
              onPlay();
            }}
            style={{
              width: '100%',
              padding: '12px 0',
              background: T.accent,
              borderRadius: T.radiusMd,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
              boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.2)', blur: 2, offset: [0, 1] }]),
            }}
          >
            <Icon name="play_arrow" size={20} color="#FFFFFF" />
            <span style={dmSansStyle({ size: 13.5, color: '#FFFFFF', weight: 700 })}>Play Episode {ep.number}</span>
          </button>
        )}
      </div>
    </div>
  );
}

export function showEpisodeInfoSheet(o: {
  episode: AniListEpisode;
  animeTitle: string;
  fallbackPoster: string;
  isPlaying: boolean;
  onPlay: () => void;
  hideSpoilers?: boolean;
}) {
  void showModalBottomSheet<void>((close) => (
    <EpisodeInfoSheet {...o} hideSpoilers={o.hideSpoilers ?? true} close={() => close(null)} />
  ));
}

export function showSeasonPickerSheet({ seasons, onSelectSeason }: { seasons: AniListSeason[]; onSelectSeason: (s: AniListSeason) => void }) {
  void showModalBottomSheet<void>((close) => (
    <div style={{ ...sheetBox, maxHeight: 'calc(100dvh - 48px)' }}>
      <SheetDragHandle />
      <div style={{ padding: '16px 20px 24px', display: 'flex', flexDirection: 'column', minHeight: 0 }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: white(0.2), alignSelf: 'center', flexShrink: 0 }} />
        <div style={{ height: 16, flexShrink: 0 }} />
        <div style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>
          <Icon name="layers" size={18} color={T.accentWarm} />
          <div style={{ width: 8 }} />
          <span style={dmSansStyle({ size: 17, color: T.textPrimary, weight: 700 })}>Select Season</span>
        </div>
        <div style={{ height: 14, flexShrink: 0 }} />
        <div style={{ minHeight: 0, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {seasons.map((season) => {
            const isCurrent = season.isCurrent;
            const meta = [
              season.format,
              ...(season.episodeCount && season.episodeCount > 0 ? [`${season.episodeCount} episodes`] : []),
              ...(season.year && season.year > 0 ? [`${season.year}`] : []),
            ].join(' • ');
            return (
              <div
                key={season.id}
                onClick={() => {
                  close(null);
                  if (!isCurrent) onSelectSeason(season);
                }}
                style={{
                  padding: 10,
                  background: isCurrent ? withAlpha(T.accent, 0.12) : white(0.04),
                  borderRadius: T.radiusMd,
                  border: `1px solid ${isCurrent ? T.accent : T.border}`,
                  display: 'flex',
                  alignItems: 'center',
                  cursor: 'pointer',
                  flexShrink: 0,
                }}
              >
                {season.coverImageUrl ? (
                  <img src={season.coverImageUrl} alt="" style={{ width: 42, height: 60, borderRadius: 6, objectFit: 'cover', flexShrink: 0 }} />
                ) : (
                  <div
                    style={{
                      width: 42,
                      height: 60,
                      borderRadius: 6,
                      background: white(0.05),
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                    }}
                  >
                    <Icon name="movie_outlined" size={24} color={T.textMuted} />
                  </div>
                )}
                <div style={{ width: 12 }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{
                      ...dmSansStyle({ size: 13, color: isCurrent ? T.accentWarm : T.textPrimary, weight: isCurrent ? 700 : 600 }),
                      ...ellipsis(2),
                    }}
                  >
                    {season.label}
                  </div>
                  <div style={{ height: 3 }} />
                  <div style={dmSansStyle({ size: 11, color: T.textSecondary })}>{meta}</div>
                </div>
                {isCurrent && (
                  <div style={{ padding: '3px 8px', background: withAlpha(T.accent, 0.2), borderRadius: 4 }}>
                    <span style={dmSansStyle({ size: 10, color: T.accentWarm, weight: 700 })}>Watching</span>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  ));
}
