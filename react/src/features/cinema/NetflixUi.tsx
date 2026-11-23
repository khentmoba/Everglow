// Port of lib/features/cinema/presentation/widgets/netflix/*.dart.
import { useCallback, useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate } from 'react-router';
import { useViewport } from '../../core/system/viewport';
import { clearOnLogout, setBoundedCache } from '../../core/utils/boundedCache';
import { AppColors } from '../../core/theme/colors';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { NetflixColors, TmdbImages, type MediaItem } from './cinemaTypes';
import { showNetflixTouchPreview } from './NetflixTouchPreview';
import { fetchMediaDetails } from './tmdbService';

export interface NetflixNavLink {
  label: string;
  tab: number;
  browseOptionId?: string;
}

export interface NetflixMobileItem {
  label: string;
  icon: string;
  activeIcon: string;
  tab: number;
  browseOptionId?: string;
  isAnimeLink?: boolean;
}

export function cinemaNavLinks(isCinemaOnlyUser: boolean): NetflixNavLink[] {
  return [
    { label: 'Home', tab: 0 },
    { label: 'TV Shows', tab: 2, browseOptionId: 'collection-tv' },
    { label: 'Movies', tab: 2, browseOptionId: 'collection-movies' },
    { label: 'Popular', tab: 2, browseOptionId: 'collection-new' },
    { label: 'My List', tab: 3 },
    { label: 'Downloads', tab: 5 },
    ...(!isCinemaOnlyUser ? [{ label: 'Watch Together', tab: 4 }] : []),
    { label: 'Browse', tab: 2 },
    { label: 'Search', tab: 1 },
  ];
}

export function cinemaMobileNavItems(isCinemaOnlyUser: boolean, showDownloads = true): NetflixMobileItem[] {
  const all: NetflixMobileItem[] = isCinemaOnlyUser
    ? [
        { label: 'Home', icon: 'home', activeIcon: 'home', tab: 0 },
        {
          label: 'Popular',
          icon: 'local_fire_department',
          activeIcon: 'local_fire_department',
          tab: 2,
          browseOptionId: 'collection-new',
        },
        { label: 'My List', icon: 'bookmark_border', activeIcon: 'bookmark', tab: 3 },
        { label: 'Downloads', icon: 'download_for_offline', activeIcon: 'download_for_offline', tab: 5 },
        { label: 'Search', icon: 'search', activeIcon: 'search', tab: 1 },
        { label: 'Anime', icon: 'animation', activeIcon: 'animation', tab: 0, isAnimeLink: true },
      ]
    : [
        { label: 'Home', icon: 'home', activeIcon: 'home', tab: 0 },
        {
          label: 'Popular',
          icon: 'local_fire_department',
          activeIcon: 'local_fire_department',
          tab: 2,
          browseOptionId: 'collection-new',
        },
        { label: 'My List', icon: 'bookmark_border', activeIcon: 'bookmark', tab: 3 },
        { label: 'Downloads', icon: 'download_for_offline', activeIcon: 'download_for_offline', tab: 5 },
        { label: 'Search', icon: 'search', activeIcon: 'search', tab: 1 },
        { label: 'Together', icon: 'favorite_outline', activeIcon: 'favorite', tab: 4 },
      ];
  return showDownloads ? all : all.filter((i) => i.tab !== 5);
}

const DETAIL_CACHE_MAX = 60;
const cinemaDetailCache = new Map<string, Record<string, unknown>>();
clearOnLogout(cinemaDetailCache);
let closeActiveCinemaPreview: (() => void) | null = null;

function prefetchCinemaDetails(item: MediaItem): Promise<Record<string, unknown>> {
  const key = `${item.tmdbId}:${item.mediaType}`;
  const cached = cinemaDetailCache.get(key);
  if (cached) return Promise.resolve(cached);
  return fetchMediaDetails(item.tmdbId, item.mediaType).then((d) => {
    // A blank or failed lookup must not stick: a single hiccup would leave this
    // title's preview empty for the rest of the session.
    if (!d || Object.keys(d).length === 0) return {};
    setBoundedCache(cinemaDetailCache, key, d, DETAIL_CACHE_MAX);
    return d;
  }).catch(() => ({}));
}

function NetflixHoverPreview({
  item,
  anchor,
  inList,
  onClose,
  onTap,
  onPlay,
  onToggleList,
  onPointerEnter,
  onPointerLeave,
}: {
  item: MediaItem;
  anchor: DOMRect;
  inList: boolean;
  onClose: () => void;
  onTap: () => void;
  onPlay?: (item: MediaItem) => void;
  onToggleList?: (item: MediaItem, add: boolean) => void;
  onPointerEnter: () => void;
  onPointerLeave: () => void;
}) {
  const key = `${item.tmdbId}:${item.mediaType}`;
  const [details, setDetails] = useState<Record<string, unknown> | null>(() => cinemaDetailCache.get(key) ?? null);
  const [listed, setListed] = useState(inList);

  useEffect(() => {
    setListed(inList);
  }, [inList]);

  useEffect(() => {
    if (cinemaDetailCache.has(key)) {
      setDetails(cinemaDetailCache.get(key)!);
      return;
    }
    let alive = true;
    void prefetchCinemaDetails(item).then((d) => {
      if (alive) setDetails(d);
    });
    return () => {
      alive = false;
    };
  }, [key, item]);

  const vw = typeof window !== 'undefined' ? window.innerWidth : 1200;
  const vh = typeof window !== 'undefined' ? window.innerHeight : 800;
  const width = Math.min(340, Math.max(290, Math.round(vw * 0.25)));
  const estHeight = Math.round(width * 0.5625 + 215);
  const margin = 12;
  const left = Math.max(margin, Math.min(vw - width - margin, anchor.left + anchor.width / 2 - width / 2));
  // Sit beside the tile, never on it: below when there is room, else above, so
  // the row heading and the tile itself stay readable.
  const below = anchor.bottom + 10;
  const above = anchor.top - estHeight - 10;
  const top =
    below + estHeight <= vh - margin
      ? below
      : above >= margin
        ? above
        : Math.max(margin, Math.min(vh - estHeight - margin, anchor.top + anchor.height / 2 - estHeight / 2));

  const backdropPath =
    item.backdropPath || (typeof details?.backdrop_path === 'string' ? details.backdrop_path : '');
  const backdropUrl = backdropPath ? TmdbImages.backdropFor(backdropPath) : TmdbImages.cardFor(item.posterPath);
  const voteAvg = typeof details?.vote_average === 'number' ? details.vote_average : (item.score ?? 0);
  const releaseDate = String(details?.release_date ?? details?.first_air_date ?? '');
  const year = item.year || (releaseDate.length >= 4 ? releaseDate.slice(0, 4) : '');
  const runtimeRaw =
    typeof details?.runtime === 'number'
      ? details.runtime
      : Array.isArray(details?.episode_run_time) && typeof details.episode_run_time[0] === 'number'
        ? details.episode_run_time[0]
        : null;
  const runtime =
    runtimeRaw && runtimeRaw > 0
      ? runtimeRaw >= 60
        ? `${Math.floor(runtimeRaw / 60)}h ${runtimeRaw % 60}m`
        : `${runtimeRaw}m`
      : null;
  const seasons = typeof details?.number_of_seasons === 'number' ? details.number_of_seasons : null;
  const seriesInfo = item.mediaType === 'tv' && seasons && seasons > 0 ? `${seasons} Season${seasons === 1 ? '' : 's'}` : null;
  const rawGenres =
    item.genres.length > 0
      ? item.genres
      : Array.isArray(details?.genres)
        ? details.genres.map((g) => String((g as Record<string, unknown>)?.name ?? '')).filter(Boolean)
        : [];
  const synopsis =
    item.synopsis ||
    (typeof details?.overview === 'string' && details.overview.trim() ? details.overview.trim() : '') ||
    `${item.mediaType === 'movie' ? 'Movie' : 'Series'}${year ? ` from ${year}` : ''}. Click for details, episodes, cast and more.`;

  return createPortal(
    <div
      onMouseEnter={onPointerEnter}
      onMouseLeave={onPointerLeave}
      onClick={(e) => {
        e.stopPropagation();
        onClose();
        onTap();
      }}
      style={{
        position: 'fixed',
        left,
        top,
        width,
        zIndex: 1300,
        borderRadius: 12,
        overflow: 'hidden',
        background: NetflixColors.surfaceElevated,
        border: `1px solid ${NetflixColors.hairline}`,
        boxShadow: '0 20px 44px rgba(0, 0, 0, 0.78)',
        cursor: 'pointer',
        animation: 'shelf-entrance 180ms cubic-bezier(0.22, 1, 0.36, 1) both',
      }}
    >
      <div style={{ position: 'relative', width: '100%', aspectRatio: '16 / 9', background: NetflixColors.surface }}>
        {backdropUrl && (
          <img
            src={backdropUrl}
            alt={item.title}
            loading="lazy"
            decoding="async"
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        )}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: linear(['rgba(0,0,0,0)', 'rgba(24,24,24,0.92)'], {
              begin: Align.topCenter,
              end: Align.bottomCenter,
              stops: [0.35, 1],
            }),
          }}
        />
        <div
          className="clamp-2"
          style={{
            position: 'absolute',
            left: 14,
            right: 14,
            bottom: 10,
            ...AppTypography.cormorantBold,
            fontSize: 20,
            lineHeight: 1.1,
            color: '#FFFFFF',
            textShadow: '0 2px 8px rgba(0,0,0,0.8)',
          }}
        >
          {item.title}
        </div>
      </div>

      <div style={{ padding: '12px 14px 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <button
            type="button"
            className="bare-button"
            aria-label={`Play ${item.title}`}
            title="Play"
            onClick={(e) => {
              e.stopPropagation();
              onClose();
              if (onPlay) onPlay(item);
              else onTap();
            }}
            style={{
              width: 40,
              height: 40,
              borderRadius: '50%',
              background: '#FFFFFF',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="play_arrow" size={20} color="#000000" />
          </button>
          {onToggleList && (
            <button
              type="button"
              className="bare-button"
              aria-label={listed ? 'Remove from My List' : 'Add to My List'}
              title={listed ? 'Remove from My List' : 'Add to My List'}
              onClick={(e) => {
                e.stopPropagation();
                const next = !listed;
                setListed(next);
                onToggleList(item, next);
              }}
              style={{
                width: 40,
                height: 40,
                borderRadius: '50%',
                background: 'rgba(42,42,42,0.8)',
                border: '1.5px solid rgba(255,255,255,0.45)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name={listed ? 'check' : 'add'} size={18} color="#FFFFFF" />
            </button>
          )}
          <div style={{ flex: 1 }} />
          <button
            type="button"
            className="bare-button"
            aria-label={`More info for ${item.title}`}
            title="More info"
            onClick={(e) => {
              e.stopPropagation();
              onClose();
              onTap();
            }}
            style={{
              width: 34,
              height: 34,
              borderRadius: '50%',
              background: 'rgba(42,42,42,0.8)',
              border: '1.5px solid rgba(255,255,255,0.45)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="expand_more" size={20} color="#FFFFFF" />
          </button>
        </div>

        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: '4px 8px' }}>
          {voteAvg > 0 && (
            <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: '#46D369' }}>
              {voteAvg > 0 ? `TMDB ${voteAvg.toFixed(1)}` : ''}
            </span>
          )}
          {year && <span style={{ ...AppTypography.outfitMedium, fontSize: 12, color: NetflixColors.textSecondary }}>{year}</span>}
          {(seriesInfo || runtime) && (
            <span style={{ ...AppTypography.outfitMedium, fontSize: 12, color: NetflixColors.textSecondary }}>
              {seriesInfo ?? runtime}
            </span>
          )}
          <span
            style={{
              padding: '1px 5px',
              border: '1px solid rgba(255,255,255,0.4)',
              borderRadius: 3,
              ...AppTypography.outfitBold,
              fontSize: 9.5,
              color: NetflixColors.textSecondary,
            }}
          >
            HD
          </span>
        </div>

        {rawGenres.length > 0 && (
          <div className="ellipsis" style={{ ...AppTypography.outfitMedium, fontSize: 11.5, color: '#FFFFFF' }}>
            {rawGenres.slice(0, 3).join('  •  ')}
          </div>
        )}

        <div className="clamp-3" style={{ ...AppTypography.bodySmall, fontSize: 11.5, lineHeight: 1.4, color: NetflixColors.textSecondary }}>
          {synopsis}
        </div>
      </div>
    </div>,
    document.body,
  );
}

export function NetflixPosterCard({
  item,
  onTap,
  onPlay,
  onRestart,
  onToggleList,
  isInList,
  progress,
  rank,
  compact = false,
  isDesktop = false,
  height,
}: {
  item: MediaItem;
  onTap: () => void;
  onPlay?: (item: MediaItem) => void;
  onRestart?: (item: MediaItem) => void;
  onToggleList?: (item: MediaItem, add: boolean) => void;
  isInList?: (item: MediaItem) => boolean;
  progress?: number | null;
  rank?: number;
  compact?: boolean;
  isDesktop?: boolean;
  /** The row's height: Flutter's horizontal ListView stretches every card to it. */
  height?: number;
}) {
  const { width: vw } = useViewport();
  const desktopCapable = isDesktop || vw >= 1024;
  const [hovered, setHovered] = useState(false);
  const [previewRect, setPreviewRect] = useState<DOMRect | null>(null);
  const [imgErr, setImgErr] = useState(false);
  const cardRef = useRef<HTMLButtonElement>(null);
  const showTimerRef = useRef<number | undefined>(undefined);
  const hideTimerRef = useRef<number | undefined>(undefined);
  const touchTimerRef = useRef<number | undefined>(undefined);
  const touchOriginRef = useRef<{ x: number; y: number } | null>(null);
  const longPressedRef = useRef(false);
  const posterUrl = TmdbImages.cardFor(item.posterPath);
  const cardWidth = compact ? undefined : rank != null ? 118 : isDesktop ? 172 : 124;

  const closePreview = useCallback(() => {
    window.clearTimeout(showTimerRef.current);
    window.clearTimeout(hideTimerRef.current);
    setHovered(false);
    setPreviewRect(null);
  }, []);

  useEffect(() => {
    if (!previewRect) return;
    const onScroll = () => closePreview();
    window.addEventListener('scroll', onScroll, { capture: true, passive: true });
    return () => window.removeEventListener('scroll', onScroll, { capture: true });
  }, [previewRect]);

  useEffect(() => {
    return () => {
      window.clearTimeout(showTimerRef.current);
      window.clearTimeout(hideTimerRef.current);
      window.clearTimeout(touchTimerRef.current);
    };
  }, []);

  const clearLongPress = () => {
    window.clearTimeout(touchTimerRef.current);
    touchOriginRef.current = null;
  };

  const handleTouchStart = (e: React.TouchEvent<HTMLButtonElement>) => {
    const t = e.touches[0];
    if (!t) return;
    longPressedRef.current = false;
    touchOriginRef.current = { x: t.clientX, y: t.clientY };
    window.clearTimeout(touchTimerRef.current);
    touchTimerRef.current = window.setTimeout(() => {
      longPressedRef.current = true;
      void showNetflixTouchPreview({
        item,
        inList: isInList?.(item) ?? false,
        onTap,
        onPlay: onPlay ? () => onPlay(item) : undefined,
        onRestart: onRestart ? () => onRestart(item) : undefined,
        onToggleList: onToggleList ? (add) => onToggleList(item, add) : undefined,
      });
    }, 480);
  };

  const handleTouchMove = (e: React.TouchEvent<HTMLButtonElement>) => {
    const origin = touchOriginRef.current;
    const t = e.touches[0];
    if (!origin || !t) return;
    if (Math.hypot(t.clientX - origin.x, t.clientY - origin.y) > 10) {
      clearLongPress();
    }
  };

  const handleEnter = () => {
    window.clearTimeout(hideTimerRef.current);
    setHovered(true);
    if (!desktopCapable) return;
    void prefetchCinemaDetails(item);
    window.clearTimeout(showTimerRef.current);
    showTimerRef.current = window.setTimeout(() => {
      const rect = cardRef.current?.getBoundingClientRect();
      if (!rect) return;
      if (closeActiveCinemaPreview && closeActiveCinemaPreview !== closePreview) {
        closeActiveCinemaPreview();
      }
      closeActiveCinemaPreview = closePreview;
      setPreviewRect(rect);
    }, 260);
  };

  const handleLeave = () => {
    window.clearTimeout(showTimerRef.current);
    setHovered(false);
    hideTimerRef.current = window.setTimeout(() => {
      setPreviewRect(null);
    }, 90);
  };

  const posterBox = (
    <button
      ref={cardRef}
      type="button"
      className="bare-button"
      aria-label={`Details for ${item.title}`}
      onMouseEnter={handleEnter}
      onMouseLeave={handleLeave}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={clearLongPress}
      onTouchCancel={clearLongPress}
      onClick={() => {
        if (longPressedRef.current) {
          longPressedRef.current = false;
          return;
        }
        closePreview();
        onTap();
      }}
      style={{
        position: 'relative',
        width: cardWidth ?? '100%',
        ...(height != null ? { height } : { aspectRatio: '2 / 3' }),
        borderRadius: 6,
        overflow: 'hidden',
        background: NetflixColors.surfaceElevated,
        boxShadow: boxShadow([
          hovered && desktopCapable
            ? { offset: [0, 14], blur: 24, color: 'rgba(0,0,0,0.65)' }
            : { offset: [0, 4], blur: 10, color: 'rgba(0,0,0,0.45)' },
        ]),
        transform: hovered && desktopCapable ? 'scale(1.04)' : 'scale(1)',
        transition: 'transform 220ms cubic-bezier(0.22, 1, 0.36, 1)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {posterUrl && !imgErr ? (
        <img
          src={posterUrl}
          alt={item.title}
          loading="lazy"
          decoding="async"
          onError={() => setImgErr(true)}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      ) : (
        <div
          style={{
            padding: 8,
            width: '100%',
            height: '100%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            textAlign: 'center',
          }}
        >
          <span
            className="clamp-3"
            style={{
              ...AppTypography.outfitBold,
              fontSize: 11,
              color: NetflixColors.textSecondary,
            }}
          >
            {item.title}
          </span>
        </div>
      )}
      {hovered && desktopCapable && <div style={{ position: 'absolute', inset: 0, background: NetflixColors.hoverScrim }} />}
      {previewRect && (
        <NetflixHoverPreview
          item={item}
          anchor={previewRect}
          inList={isInList?.(item) ?? false}
          onClose={closePreview}
          onTap={onTap}
          onPlay={onPlay}
          onToggleList={onToggleList}
          onPointerEnter={() => window.clearTimeout(hideTimerRef.current)}
          onPointerLeave={handleLeave}
        />
      )}
      {item.remindMe && (
        <div
          style={{
            position: 'absolute',
            top: 6,
            left: 6,
            width: 26,
            height: 26,
            borderRadius: '50%',
            background: NetflixColors.accent,
            boxShadow: '0 2px 8px rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="notifications" size={14} color="#FFFFFF" />
        </div>
      )}
      {progress != null && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            background: 'rgba(255,255,255,0.25)',
          }}
        >
          <div
            style={{
              height: '100%',
              width: `${Math.round(Math.max(0, Math.min(1, progress)) * 100)}%`,
              background: NetflixColors.accent,
            }}
          />
        </div>
      )}
    </button>
  );

  if (rank == null) return posterBox;

  const boxHeight = height ?? (cardWidth ?? 118) * 1.5;
  const digits = String(rank);
  // Outfit Black advances at a 200px font, in px.
  const textWidth = [...digits].reduce((w, c) => w + (outfitBlackDigit[c] ?? 580) * 0.2 + 0.25, 0);
  // A 200px font draws ±144px of digit ink inside a 200px line box; fitting the
  // whole line box (not the ink) keeps the glyph inside the row, so nothing clips.
  const slotWidth = 84 + (digits.length - 1) * 68;
  const scale = Math.min(slotWidth / textWidth, boxHeight / 200);
  const boxWidth = (cardWidth ?? 118) + slotWidth;
  return (
    <div style={{ position: 'relative', width: boxWidth, height: boxHeight, flexShrink: 0 }}>
      <div
        aria-hidden
        style={{
          position: 'absolute',
          left: 6,
          bottom: 0,
          width: textWidth,
          height: 200,
          transform: `scale(${scale})`,
          transformOrigin: 'bottom left',
          fontFamily: 'Outfit, sans-serif',
          fontSize: 200,
          fontWeight: 900,
          lineHeight: '200px',
          letterSpacing: 0.25,
          whiteSpace: 'nowrap',
          color: '#4D4D4D',
          WebkitTextStroke: '8px #000000',
          paintOrder: 'stroke fill',
          userSelect: 'none',
          pointerEvents: 'none',
        }}
      >
        {rank}
      </div>
      <div style={{ position: 'absolute', right: 0, top: 0, bottom: 0 }}>{posterBox}</div>
    </div>
  );
}

// Outfit Black digit advances (units per em 1000).
const outfitBlackDigit: Record<string, number> = {
  '0': 676,
  '1': 401,
  '2': 587,
  '3': 578,
  '4': 618,
  '5': 575,
  '6': 584,
  '7': 532,
  '8': 576,
  '9': 584,
};

export function NetflixRow({
  title,
  items,
  ranked = false,
  onTapItem,
  onPlayItem,
  onRestartItem,
  onToggleListItem,
  isInList,
  progress,
  isDesktop = false,
}: {
  title: string;
  items: MediaItem[];
  ranked?: boolean;
  onTapItem: (item: MediaItem) => void;
  onPlayItem?: (item: MediaItem) => void;
  onRestartItem?: (item: MediaItem) => void;
  onToggleListItem?: (item: MediaItem, add: boolean) => void;
  isInList?: (item: MediaItem) => boolean;
  /** 0..1 resume position, drawn as the red hairline Netflix puts on a tile. */
  progress?: (item: MediaItem) => number | null;
  isDesktop?: boolean;
}) {
  const scrollerRef = useRef<HTMLDivElement>(null);
  if (items.length === 0) return null;

  const hPad = isDesktop ? 48 : 16;
  const rowHeight = (isDesktop ? 172 : 124) * 1.5 + 6;
  const scrollBy = (dx: number) => {
    scrollerRef.current?.scrollBy({ left: dx, behavior: 'smooth' });
  };

  return (
    <section>
      <div style={{ padding: `26px ${hPad}px 12px` }}>
        <h3
          style={{
            margin: 0,
            ...AppTypography.outfitHeading,
            fontSize: isDesktop ? 20 : 17,
            letterSpacing: 0,
            color: NetflixColors.textPrimary,
          }}
        >
          {title}
        </h3>
      </div>
      <div style={{ position: 'relative' }}>
        <div
          ref={scrollerRef}
          className="no-scrollbar"
          style={{
            display: 'flex',
            gap: 8,
            height: rowHeight,
            padding: `0 ${hPad}px`,
            overflowX: 'auto',
          }}
        >
          {items.map((item, idx) => (
            <div key={`${item.mediaType}:${item.tmdbId}:${idx}`} style={{ flexShrink: 0 }}>
              <NetflixPosterCard
                item={item}
                rank={ranked ? idx + 1 : undefined}
                isDesktop={isDesktop}
                height={rowHeight}
                progress={progress?.(item) ?? null}
                onTap={() => onTapItem(item)}
                onPlay={onPlayItem}
                onRestart={onRestartItem}
                onToggleList={onToggleListItem}
                isInList={isInList}
              />
            </div>
          ))}
        </div>
        {isDesktop && items.length > 4 && (
          <>
            <button
              type="button"
              className="bare-button"
              aria-label="Scroll left"
              onClick={() => scrollBy(-540)}
              style={{
                position: 'absolute',
                left: 6,
                top: '42%',
                width: 36,
                height: 36,
                borderRadius: '50%',
                background: 'rgba(0,0,0,0.6)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="chevron_left" size={22} color="#FFFFFF" />
            </button>
            <button
              type="button"
              className="bare-button"
              aria-label="Scroll right"
              onClick={() => scrollBy(540)}
              style={{
                position: 'absolute',
                right: 6,
                top: '42%',
                width: 36,
                height: 36,
                borderRadius: '50%',
                background: 'rgba(0,0,0,0.6)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="chevron_right" size={22} color="#FFFFFF" />
            </button>
          </>
        )}
      </div>
    </section>
  );
}

export function NetflixBillboard({
  items,
  isDesktop,
  viewportHeight,
  rankOf,
  inListOf,
  onToggleList,
  onPlay,
  onInfo,
}: {
  items: MediaItem[];
  isDesktop: boolean;
  viewportHeight: number;
  /** Real position in the Top 10 row, or null when the title is not ranked. */
  rankOf?: (item: MediaItem) => number | null;
  inListOf?: (item: MediaItem) => boolean;
  onToggleList?: (item: MediaItem, add: boolean) => void;
  onPlay: (item: MediaItem) => void;
  onInfo: (item: MediaItem) => void;
}) {
  const [index, setIndex] = useState(0);
  const [details, setDetails] = useState<Record<string, unknown> | null>(null);
  const [imgErr, setImgErr] = useState(false);

  const safeIndex = items.length === 0 ? 0 : index % items.length;
  const item = items[safeIndex];

  useEffect(() => {
    if (!item) return;
    setImgErr(false);
    let alive = true;
    void fetchMediaDetails(item.tmdbId, item.mediaType).then((d) => {
      if (alive) setDetails(d);
    });
    return () => {
      alive = false;
    };
  }, [item?.tmdbId, item?.mediaType]);

  if (!item) return null;
  const h = isDesktop ? 560 : Math.max(380, Math.min(540, Math.round(viewportHeight * 0.58)));
  const backdropUrl = item.backdropPath ? TmdbImages.backdropFor(item.backdropPath) : TmdbImages.cardFor(item.posterPath);
  const voteAverage = typeof details?.vote_average === 'number' ? details.vote_average : (item.score ?? 0);
  const runtimeNum = typeof details?.runtime === 'number' ? details.runtime : null;
  const synopsis = typeof details?.overview === 'string' && details.overview ? details.overview : item.synopsis;
  const hPad = isDesktop ? 48 : 16;
  const topTenRank = rankOf?.(item) ?? null;
  const inList = inListOf?.(item) ?? false;

  return (
    <div style={{ position: 'relative', height: h, width: '100%', overflow: 'hidden', background: NetflixColors.surface }}>
      {backdropUrl && !imgErr ? (
        <img
          src={backdropUrl}
          alt={item.title}
          onError={() => setImgErr(true)}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      ) : (
        <div style={{ width: '100%', height: '100%', background: NetflixColors.surface }} />
      )}

      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 0,
          background: linear(['#00000000', '#00000000', '#33080808', NetflixColors.background], {
            begin: Align.topCenter,
            end: Align.bottomCenter,
            stops: [0, 0.42, 0.72, 1],
          }),
          pointerEvents: 'none',
        }}
      />
      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 0,
          background: linear(['rgba(8,8,8,0.7)', 'rgba(8,8,8,0.35)', '#00000000'], {
            begin: Align.centerLeft,
            end: Align.centerRight,
            stops: [0, 0.35, 0.75],
          }),
          pointerEvents: 'none',
        }}
      />

      <div style={{ position: 'absolute', left: hPad, right: hPad, bottom: 54, maxWidth: isDesktop ? 620 : undefined }}>
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: '6px 10px' }}>
          {topTenRank != null && (
            <span
              style={{
                padding: '3px 8px',
                background: NetflixColors.accent,
                borderRadius: 4,
                ...AppTypography.outfitHeading,
                fontSize: 11,
                color: '#FFFFFF',
              }}
            >
              {`#${topTenRank} in Top 10`}
            </span>
          )}
          {voteAverage > 0 && (
            <span style={{ ...AppTypography.outfitHeading, fontSize: 14, color: NetflixColors.textSecondary }}>
              {`TMDB ${voteAverage.toFixed(1)}`}
            </span>
          )}
          {item.year && (
            <span style={{ ...AppTypography.outfitMedium, fontSize: 13, color: 'rgba(255,255,255,0.85)' }}>{item.year}</span>
          )}
          {runtimeNum != null && (
            <span style={{ ...AppTypography.outfitMedium, fontSize: 13, color: 'rgba(255,255,255,0.85)' }}>
              {`${Math.floor(runtimeNum / 60)}h ${runtimeNum % 60}m`}
            </span>
          )}
          {item.mediaType === 'movie' ? (
            <span
              style={{
                padding: '2px 6px',
                border: '1px solid rgba(255,255,255,0.7)',
                borderRadius: 3,
                ...AppTypography.outfitHeading,
                fontSize: 10,
                letterSpacing: '0.5px',
              }}
            >
              HD
            </span>
          ) : (
            <span style={{ ...AppTypography.outfitMedium, fontSize: 13, color: 'rgba(255,255,255,0.85)' }}>Series</span>
          )}
        </div>

        <div style={{ height: 12 }} />

        <h2
          className="clamp-2"
          style={{
            margin: 0,
            ...AppTypography.cormorantBlack,
            fontSize: isDesktop ? 46 : 32,
            lineHeight: 1.02,
            letterSpacing: '0.2px',
            color: NetflixColors.textPrimary,
            textShadow: '0 0 18px rgba(0,0,0,0.67)',
          }}
        >
          {item.title}
        </h2>

        {synopsis && (
          <p
            className={isDesktop ? 'clamp-3' : 'clamp-2'}
            style={{
              margin: isDesktop ? '14px 0 0' : '10px 0 0',
              ...AppTypography.outfitMuted,
              fontSize: isDesktop ? 14.5 : 13,
              color: NetflixColors.textSecondary,
              lineHeight: 1.4,
              textShadow: '0 0 10px rgba(0,0,0,0.6)',
            }}
          >
            {synopsis}
          </p>
        )}

        <div style={{ height: isDesktop ? 22 : 18 }} />

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px 12px' }}>
          <button
            type="button"
            className="bare-button"
            onClick={() => onPlay(item)}
            style={{
              minHeight: 48,
              padding: `12px ${isDesktop ? 26 : 18}px`,
              borderRadius: 6,
              background: NetflixColors.textPrimary,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              ...AppTypography.outfitHeading,
              color: NetflixColors.background,
              fontSize: isDesktop ? 15 : 13.5,
            }}
          >
            <Icon name="play_arrow" size={isDesktop ? 20 : 18} color={NetflixColors.background} />
            <span>Play</span>
          </button>
          <button
            type="button"
            className="bare-button"
            onClick={() => onInfo(item)}
            style={{
              minHeight: 48,
              padding: `12px ${isDesktop ? 26 : 18}px`,
              borderRadius: 6,
              background: 'rgba(255, 255, 255, 0.2)',
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              ...AppTypography.outfitHeading,
              color: NetflixColors.textPrimary,
              fontSize: isDesktop ? 15 : 13.5,
            }}
          >
            <Icon name="info_outline" size={isDesktop ? 20 : 18} color={NetflixColors.textPrimary} />
            <span>More Info</span>
          </button>
          {onToggleList && (
            <button
              type="button"
              className="bare-button"
              aria-pressed={inList}
              aria-label={inList ? 'In My List' : 'Add to My List'}
              onClick={() => onToggleList(item, !inList)}
              style={{
                minWidth: 48,
                minHeight: 48,
                height: 48,
                padding: isDesktop ? '0 20px' : 0,
                width: isDesktop ? undefined : 48,
                borderRadius: isDesktop ? 6 : 24,
                boxSizing: 'border-box',
                background: 'rgba(255, 255, 255, 0.2)',
                border: `1.5px solid ${inList ? NetflixColors.accent : 'rgba(255,255,255,0.55)'}`,
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
                ...AppTypography.outfitHeading,
                color: NetflixColors.textPrimary,
                fontSize: 15,
              }}
            >
              <Icon name={inList ? 'check' : 'add'} size={isDesktop ? 22 : 20} color={inList ? NetflixColors.accent : NetflixColors.textPrimary} />
              {isDesktop && <span>My List</span>}
            </button>
          )}
        </div>
      </div>

      {items.length > 1 && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 16,
            display: 'flex',
            justifyContent: 'center',
            gap: 2,
          }}
        >
          {items.map((_, i) => {
            const active = i === safeIndex;
            return (
              <button
                key={i}
                type="button"
                className="bare-button"
                aria-label={`Slide ${i + 1}`}
                onClick={() => setIndex(i)}
                style={{ padding: '10px 5px' }}
              >
                <div
                  style={{
                    width: active ? 18 : 6,
                    height: 6,
                    borderRadius: 3,
                    background: active ? NetflixColors.accent : 'rgba(255,255,255,0.35)',
                    transition: 'width 300ms ease, background-color 300ms ease',
                  }}
                />
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

export function NetflixBottomNav({
  currentIndex,
  currentBrowseId,
  items,
  onSelect,
  onAnimeTap,
}: {
  currentIndex: number;
  currentBrowseId?: string | null;
  items: NetflixMobileItem[];
  onSelect: (tab: number, browseOptionId?: string) => void;
  onAnimeTap: () => void;
}) {
  return (
    <nav
      style={{
        position: 'fixed',
        left: 0,
        right: 0,
        bottom: 0,
        zIndex: 30,
        background: NetflixColors.background,
        borderTop: `1px solid ${NetflixColors.hairline}`,
        height: 'calc(62px + env(safe-area-inset-bottom, 0px))',
        paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        display: 'flex',
      }}
    >
      {items.map((item) => {
        const active =
          !item.isAnimeLink &&
          item.tab === currentIndex &&
          (item.browseOptionId ? item.browseOptionId === currentBrowseId : !currentBrowseId);
        const color = active ? '#FFFFFF' : item.isAnimeLink ? NetflixColors.accent : 'rgba(255,255,255,0.55)';
        return (
          <button
            key={item.label}
            type="button"
            className="bare-button"
            onClick={() => (item.isAnimeLink ? onAnimeTap() : onSelect(item.tab, item.browseOptionId))}
            style={{
              flex: 1,
              minWidth: 0,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 3,
            }}
          >
            <Icon name={active ? item.activeIcon : item.icon} variant={active ? 'round' : 'outlined'} size={23} color={color} />
            <span
              style={{
                ...AppTypography.outfitHeading,
                fontSize: 10.5,
                color,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                maxWidth: '100%',
              }}
            >
              {item.label}
            </span>
          </button>
        );
      })}
    </nav>
  );
}

export function NetflixCinemaTopBar({
  currentIndex,
  currentBrowseId,
  links,
  scrolled,
  userName,
  showAnime,
  onSelect,
  onAnimeTap,
  onDashboardTap,
  onLogout,
}: {
  currentIndex: number;
  currentBrowseId?: string | null;
  links: NetflixNavLink[];
  scrolled: boolean;
  userName: string;
  showAnime: boolean;
  onSelect: (tab: number, browseOptionId?: string) => void;
  onAnimeTap: () => void;
  onDashboardTap?: () => void;
  onLogout: () => void;
}) {
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);
  const letter = (userName || '?')[0].toUpperCase();

  return (
    <header
      style={{
        height: 'calc(56px + env(safe-area-inset-top, 0px))',
        paddingTop: 'env(safe-area-inset-top, 0px)',
        paddingLeft: 'calc(48px + env(safe-area-inset-left, 0px))',
        paddingRight: 'calc(48px + env(safe-area-inset-right, 0px))',
        background: scrolled ? 'rgba(0,0,0,0.92)' : 'transparent',
        borderBottom: `1px solid ${scrolled ? NetflixColors.hairline : 'transparent'}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <button
        type="button"
        className="bare-button"
        onClick={onDashboardTap}
        style={{
          padding: '6px 6px',
          display: 'inline-flex',
          alignItems: 'center',
          gap: 10,
          cursor: onDashboardTap ? 'pointer' : 'default',
        }}
      >
        <div
          style={{
            width: 30,
            height: 30,
            borderRadius: '50%',
            background: NetflixColors.accent,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="favorite" size={17} color="#FFFFFF" />
        </div>
        <span style={{ ...AppTypography.outfitHeading, fontSize: 18, color: '#FFFFFF' }}>Everglow</span>
        <span style={{ ...AppTypography.outfitHeading, fontSize: 11, color: NetflixColors.accent, letterSpacing: '1.2px' }}>
          CINEMA
        </span>
      </button>

      <div style={{ width: 30 }} />

      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 22, overflow: 'hidden' }}>
        {links.map((l) => {
          const active =
            l.tab === currentIndex && (l.browseOptionId ? l.browseOptionId === currentBrowseId : !currentBrowseId);
          return (
            <button
              key={l.label}
              type="button"
              className="bare-button"
              onClick={() => onSelect(l.tab, l.browseOptionId)}
              style={{
                ...AppTypography.outfitHeading,
                fontSize: 14,
                color: active ? '#FFFFFF' : 'rgba(255,255,255,0.72)',
                whiteSpace: 'nowrap',
              }}
            >
              {l.label}
            </button>
          );
        })}
      </div>

      {showAnime && <MediaSectionMenuButton currentRoute="/cinema" />}

      <div style={{ position: 'relative' }}>
        <button
          type="button"
          className="bare-button"
          aria-label="Account menu"
          onClick={() => setMenuOpen((v) => !v)}
          style={{
            width: 32,
            height: 32,
            borderRadius: '50%',
            background: 'rgba(255,255,255,0.08)',
            border: `1px solid ${NetflixColors.hairline}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            ...AppTypography.outfitHeading,
            fontSize: 13,
          }}
        >
          {letter}
        </button>
        {menuOpen && (
          <div
            style={{
              position: 'absolute',
              right: 0,
              top: 40,
              minWidth: 160,
              borderRadius: 10,
              background: NetflixColors.surfaceElevated,
              border: `1px solid ${NetflixColors.hairline}`,
              padding: 6,
              zIndex: 1200,
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            {onDashboardTap && (
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  setMenuOpen(false);
                  onDashboardTap();
                }}
                style={{ padding: '8px 12px', textAlign: 'left', ...AppTypography.outfitWhite, fontSize: 13 }}
              >
                Dashboard
              </button>
            )}
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setMenuOpen(false);
                onAnimeTap();
              }}
              style={{ padding: '8px 12px', textAlign: 'left', ...AppTypography.outfitWhite, fontSize: 13 }}
            >
              Anime
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setMenuOpen(false);
                navigate('/manga');
              }}
              style={{ padding: '8px 12px', textAlign: 'left', ...AppTypography.outfitWhite, fontSize: 13 }}
            >
              Mangacelestia
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setMenuOpen(false);
                navigate('/books');
              }}
              style={{ padding: '8px 12px', textAlign: 'left', ...AppTypography.outfitWhite, fontSize: 13 }}
            >
              Books
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setMenuOpen(false);
                navigate('/watch-party');
              }}
              style={{ padding: '8px 12px', textAlign: 'left', ...AppTypography.outfitWhite, fontSize: 13 }}
            >
              Watch Party
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setMenuOpen(false);
                navigate('/global-chat');
              }}
              style={{ padding: '8px 12px', textAlign: 'left', ...AppTypography.outfitWhite, fontSize: 13 }}
            >
              Global Chat
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setMenuOpen(false);
                onLogout();
              }}
              style={{ padding: '8px 12px', textAlign: 'left', ...AppTypography.outfitWhite, fontSize: 13 }}
            >
              Logout
            </button>
          </div>
        )}
      </div>
    </header>
  );
}

export function MediaSectionMenuButton({ currentRoute }: { currentRoute: string }) {
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);

  return (
    <div style={{ position: 'relative' }}>
      <button
        type="button"
        className="bare-button"
        aria-label="Switch section"
        onClick={() => setOpen((v) => !v)}
        style={{
          width: 44,
          height: 44,
          borderRadius: '50%',
          background: NetflixColors.surface,
          border: `1px solid ${NetflixColors.hairline}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name="apps" size={20} color={AppColors.petalWhite} />
      </button>
      {open && (
        <div
          style={{
            position: 'absolute',
            right: 0,
            top: 48,
            minWidth: 180,
            borderRadius: 12,
            background: AppColors.inkDeep,
            border: `1px solid ${NetflixColors.hairline}`,
            padding: 6,
            zIndex: 1200,
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          {[
            ['/cinema', 'Cinema', 'movie'],
            ['/anime', 'Anime', 'animation'],
            ['/manga', 'Mangacelestia', 'auto_stories'],
            ['/books', 'Books', 'menu_book'],
            ['/watch-party', 'Watch Party', 'live_tv'],
            ['/global-chat', 'Global Chat', 'forum'],
          ].map(([route, label, icon]) => (
            <button
              key={route}
              type="button"
              className="bare-button"
              onClick={() => {
                setOpen(false);
                if (route !== currentRoute) navigate(route);
              }}
              style={{
                padding: '10px 12px',
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                color: AppColors.petalWhite,
                ...AppTypography.outfitWhite,
                fontSize: 13.5,
              }}
            >
              <Icon name={icon} variant="outlined" size={18} color={AppColors.petalWhite} />
              <span style={{ flex: 1, textAlign: 'left' }}>{label}</span>
              {route === currentRoute && <Icon name="check" size={16} color={AppColors.petalWhite} />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
