// Port of lib/features/cinema/presentation/widgets/netflix/*.dart + episode_drawer.dart.
import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { AppColors } from '../../core/theme/colors';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { NetflixColors, TmdbImages, type MediaItem } from './cinemaTypes';
import {
  fetchCredits,
  fetchMediaDetails,
  fetchSeasonEpisodes,
  fetchSimilar,
  type CastMember,
  type TvEpisode,
} from './tmdbService';

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
    { label: 'New & Popular', tab: 2, browseOptionId: 'collection-new' },
    { label: 'My List', tab: 3 },
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

export function NetflixPosterCard({
  item,
  onTap,
  progress,
  rank,
  compact = false,
  isDesktop = false,
  height,
}: {
  item: MediaItem;
  onTap: () => void;
  progress?: number | null;
  rank?: number;
  compact?: boolean;
  isDesktop?: boolean;
  /** The row's height: Flutter's horizontal ListView stretches every card to it. */
  height?: number;
}) {
  const [hovered, setHovered] = useState(false);
  const [imgErr, setImgErr] = useState(false);
  const posterUrl = TmdbImages.cardFor(item.posterPath);
  const cardWidth = compact ? undefined : rank != null ? 118 : isDesktop ? 172 : 124;

  const posterBox = (
    <button
      type="button"
      className="bare-button"
      aria-label={`Details for ${item.title}`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={onTap}
      style={{
        position: 'relative',
        width: cardWidth ?? '100%',
        ...(height != null ? { height } : { aspectRatio: '2 / 3' }),
        borderRadius: 6,
        overflow: 'hidden',
        background: NetflixColors.surfaceElevated,
        boxShadow: boxShadow([
          hovered && isDesktop
            ? { offset: [0, 14], blur: 24, color: 'rgba(0,0,0,0.65)' }
            : { offset: [0, 4], blur: 10, color: 'rgba(0,0,0,0.45)' },
        ]),
        transform: hovered && isDesktop ? 'scale(1.04)' : 'scale(1)',
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
      {hovered && isDesktop && <div style={{ position: 'absolute', inset: 0, background: NetflixColors.hoverScrim }} />}
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

  const boxWidth = (cardWidth ?? 118) + 64;
  const boxHeight = height ?? (cardWidth ?? 118) * 1.5;
  // FittedBox(contain, bottomLeft) around Outfit 200 / w900 / height 0.8 in an
  // 84px-wide slot. Flutter spreads the negative leading by ascent:descent
  // (1.0 : 0.26), so the baseline sits at 200 - 92 / 1.26 inside the 160px
  // line instead of the browser's even split.
  const digits = String(rank);
  const textWidth = [...digits].reduce((w, c) => w + (outfitBlackDigit[c] ?? 580) * 0.2 + 0.25, 0);
  const scale = Math.min(84 / textWidth, boxHeight / 160);
  return (
    <div style={{ position: 'relative', width: boxWidth, height: boxHeight, flexShrink: 0 }}>
      <div
        aria-hidden
        style={{
          position: 'absolute',
          left: 0,
          bottom: 0,
          width: textWidth,
          height: 160,
          transform: `scale(${scale})`,
          transformOrigin: 'bottom left',
          fontFamily: 'Outfit, sans-serif',
          fontSize: 200,
          fontWeight: 900,
          lineHeight: '160px',
          letterSpacing: 0.25,
          whiteSpace: 'nowrap',
          color: NetflixColors.textSecondary,
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
  isDesktop = false,
}: {
  title: string;
  items: MediaItem[];
  ranked?: boolean;
  onTapItem: (item: MediaItem) => void;
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
                onTap={() => onTapItem(item)}
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
  onPlay,
  onInfo,
}: {
  items: MediaItem[];
  isDesktop: boolean;
  viewportHeight: number;
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
            {`#${safeIndex + 1} in Top 10`}
          </span>
          {voteAverage > 0 && (
            <span style={{ ...AppTypography.outfitHeading, fontSize: 14, color: NetflixColors.textSecondary }}>
              {`TMDB ${voteAverage.toFixed(1)}/10`}
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

        {isDesktop && synopsis && (
          <p
            className="clamp-3"
            style={{
              margin: '14px 0 0',
              ...AppTypography.outfitMuted,
              fontSize: 14.5,
              color: NetflixColors.textSecondary,
              lineHeight: 1.4,
              textShadow: '0 0 10px rgba(0,0,0,0.6)',
            }}
          >
            {synopsis}
          </p>
        )}

        <div style={{ height: 22 }} />

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
  items,
  onSelect,
  onAnimeTap,
}: {
  currentIndex: number;
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
        height: 62,
        display: 'flex',
      }}
    >
      {items.map((item) => {
        const active = !item.isAnimeLink && item.tab === currentIndex;
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
        height: 56,
        padding: '0 48px',
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
          const active = l.tab === currentIndex && !l.browseOptionId;
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

export function EpisodeDrawerModal({
  item,
  inList,
  onClose,
  onPlay,
  onToggleList,
  onSelectItem,
}: {
  item: MediaItem;
  inList: boolean;
  onClose: () => void;
  onPlay: (item: MediaItem, season?: number, episode?: number) => void;
  onToggleList: (item: MediaItem, add: boolean) => void;
  onSelectItem: (item: MediaItem) => void;
}) {
  const [details, setDetails] = useState<Record<string, unknown> | null>(null);
  const [cast, setCast] = useState<CastMember[]>([]);
  const [similar, setSimilar] = useState<MediaItem[]>([]);
  const [episodes, setEpisodes] = useState<TvEpisode[]>([]);
  const [selectedSeason, setSelectedSeason] = useState(item.currentSeason ?? 1);
  const [loadingDetails, setLoadingDetails] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoadingDetails(true);
    void Promise.all([
      fetchMediaDetails(item.tmdbId, item.mediaType),
      fetchCredits(item.tmdbId, item.mediaType),
      fetchSimilar(item.tmdbId, item.mediaType),
    ]).then(([d, c, s]) => {
      if (!alive) return;
      setDetails(d);
      setCast(c);
      setSimilar(s);
      setLoadingDetails(false);
    });
    return () => {
      alive = false;
    };
  }, [item.tmdbId, item.mediaType]);

  useEffect(() => {
    if (item.mediaType !== 'tv') return;
    let alive = true;
    void fetchSeasonEpisodes(item.tmdbId, selectedSeason).then((eps) => {
      if (alive) setEpisodes(eps);
    });
    return () => {
      alive = false;
    };
  }, [item.tmdbId, item.mediaType, selectedSeason]);

  const backdrop = item.backdropPath ? TmdbImages.backdropFor(item.backdropPath) : TmdbImages.cardFor(item.posterPath);
  const synopsis = (typeof details?.overview === 'string' ? details.overview : '') || item.synopsis;
  const seasons = Array.isArray(details?.seasons)
    ? (details.seasons as Array<{ season_number?: number; name?: string }>).filter((s) => (s.season_number ?? 0) > 0)
    : [{ season_number: 1, name: 'Season 1' }];

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.68)',
        zIndex: 1100,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 16,
      }}
    >
      <div
        className="no-scrollbar"
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 760,
          maxHeight: '90vh',
          overflowY: 'auto',
          borderRadius: 16,
          background: NetflixColors.surface,
          border: `1px solid ${NetflixColors.hairline}`,
        }}
      >
        <div style={{ position: 'relative', height: 260, background: NetflixColors.surfaceElevated }}>
          {backdrop && (
            <img
              src={backdrop}
              alt={item.title}
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
            />
          )}
          <div
            aria-hidden
            style={{
              position: 'absolute',
              inset: 0,
              background: linear(['transparent', NetflixColors.surface], { stops: [0.35, 1] }),
            }}
          />
          <button
            type="button"
            className="bare-button"
            aria-label="Close details"
            onClick={onClose}
            style={{
              position: 'absolute',
              top: 12,
              right: 12,
              width: 36,
              height: 36,
              borderRadius: '50%',
              background: 'rgba(0,0,0,0.65)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="close" size={20} color="#FFFFFF" />
          </button>
          <div style={{ position: 'absolute', left: 20, right: 20, bottom: 16 }}>
            <h2 style={{ margin: 0, ...AppTypography.cormorantBlack, fontSize: 30, color: '#FFFFFF' }}>{item.title}</h2>
          </div>
        </div>

        <div style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
            <button
              type="button"
              className="bare-button"
              onClick={() => onPlay(item, selectedSeason, item.currentEpisode ?? 1)}
              style={{
                height: 42,
                padding: '0 20px',
                borderRadius: 6,
                background: '#FFFFFF',
                color: '#000000',
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                ...AppTypography.outfitHeading,
                fontSize: 14,
              }}
            >
              <Icon name="play_arrow" size={20} color="#000000" />
              <span>Play</span>
            </button>
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                onToggleList(item, !inList);
                showSnackBar(inList ? 'Removed from My List' : 'Added to My List');
              }}
              style={{
                height: 42,
                padding: '0 18px',
                borderRadius: 6,
                background: NetflixColors.surfaceElevated,
                border: `1px solid ${NetflixColors.hairline}`,
                color: '#FFFFFF',
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                ...AppTypography.outfitBold,
                fontSize: 13.5,
              }}
            >
              <Icon name={inList ? 'check' : 'add'} size={18} color="#FFFFFF" />
              <span>{inList ? 'In My List' : 'My List'}</span>
            </button>
          </div>

          {loadingDetails && !synopsis ? (
            <div style={{ height: 40, borderRadius: 8, background: NetflixColors.surfaceElevated }} />
          ) : (
            <p
              style={{
                margin: 0,
                ...AppTypography.outfitWhite,
                fontSize: 13.5,
                lineHeight: 1.5,
                color: NetflixColors.textSecondary,
              }}
            >
              {synopsis || 'No overview available.'}
            </p>
          )}

          {cast.length > 0 && (
            <div style={{ ...AppTypography.outfitWhite, fontSize: 12, color: NetflixColors.textMuted }}>
              {`Cast: ${cast
                .slice(0, 6)
                .map((c) => c.name)
                .join(', ')}`}
            </div>
          )}

          {item.mediaType === 'tv' && (
            <div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
                <span style={{ ...AppTypography.outfitHeading, fontSize: 16, color: '#FFFFFF' }}>Episodes</span>
                {seasons.length > 1 && (
                  <select
                    value={selectedSeason}
                    onChange={(e) => setSelectedSeason(Number(e.target.value))}
                    style={{
                      background: NetflixColors.surfaceElevated,
                      color: '#FFFFFF',
                      border: `1px solid ${NetflixColors.hairline}`,
                      borderRadius: 6,
                      padding: '4px 10px',
                      fontSize: 12.5,
                    }}
                  >
                    {seasons.map((s) => (
                      <option key={s.season_number} value={s.season_number}>
                        {s.name ?? `Season ${s.season_number}`}
                      </option>
                    ))}
                  </select>
                )}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {episodes.map((ep) => (
                  <button
                    key={ep.id}
                    type="button"
                    className="bare-button"
                    onClick={() => onPlay(item, ep.seasonNumber, ep.episodeNumber)}
                    style={{
                      padding: 12,
                      borderRadius: 8,
                      background: NetflixColors.surfaceElevated,
                      display: 'flex',
                      alignItems: 'center',
                      gap: 12,
                      textAlign: 'left',
                    }}
                  >
                    <span style={{ ...AppTypography.outfitHeading, fontSize: 16, color: NetflixColors.textSecondary, width: 24 }}>
                      {ep.episodeNumber}
                    </span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ ...AppTypography.outfitBold, fontSize: 13.5, color: '#FFFFFF' }}>{ep.name}</div>
                      {ep.overview && (
                        <div
                          className="clamp-2"
                          style={{ ...AppTypography.outfitWhite, fontSize: 12, color: NetflixColors.textMuted }}
                        >
                          {ep.overview}
                        </div>
                      )}
                    </div>
                    <Icon name="play_circle_outline" size={24} color="#FFFFFF" />
                  </button>
                ))}
              </div>
            </div>
          )}

          {similar.length > 0 && (
            <div>
              <div style={{ ...AppTypography.outfitHeading, fontSize: 16, color: '#FFFFFF', marginBottom: 10 }}>
                More Like This
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(110px, 1fr))', gap: 10 }}>
                {similar.slice(0, 6).map((sim) => (
                  <NetflixPosterCard key={sim.tmdbId} item={sim} compact onTap={() => onSelectItem(sim)} />
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
