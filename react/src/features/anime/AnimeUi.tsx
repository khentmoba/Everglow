import { Fragment, useCallback, useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { Align, boxShadow, linear, sigma } from '../../core/theme/paint';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { useViewport } from '../../core/system/viewport';
import { reduceAmbientMotion } from '../../core/system/device';
import { motionReduced } from '../../core/theme/motion';
import { useController } from '../../core/anim/controller';
import { clearOnLogout, setBoundedCache } from '../../core/utils/boundedCache';
import { Icon, type IconStyle } from '../../shared/widgets/Icon';
import { MediaSectionMenuButton } from '../cinema/NetflixUi';
import type { MediaItem } from '../cinema/cinemaTypes';
import { fetchAniListDetails, type AnimexPageKind } from './animeService';
import { TrailerPlayer } from '../cinema/TrailerPlayer';
import { AnimeXTokens, bebasStyle, dmSansStyle, interBodyStyle } from './animeTokens';

export type AnimeBadgeKind = 'sub' | 'dub' | 'episodes' | 'rating' | 'airing' | 'finished' | 'upcoming' | 'newBadge';

export function AnimeXBadge({
  label,
  kind = 'episodes',
  dot = false,
  icon,
}: {
  label: string;
  kind?: AnimeBadgeKind;
  dot?: boolean;
  icon?: string;
}) {
  const a = withAlpha;
  const palette: Record<AnimeBadgeKind, { fg: string; bg: string; border: string }> = {
    sub: { fg: AnimeXTokens.success, bg: a(AnimeXTokens.success, 0.18), border: a(AnimeXTokens.success, 0.35) },
    dub: { fg: AnimeXTokens.dubBlue, bg: a(AnimeXTokens.dubBlue, 0.18), border: a(AnimeXTokens.dubBlue, 0.35) },
    rating: { fg: AnimeXTokens.gold, bg: '#1A1408B3', border: a(AnimeXTokens.gold, 0.35) },
    airing: { fg: AnimeXTokens.success, bg: '#0B1A12B3', border: a(AnimeXTokens.success, 0.3) },
    finished: { fg: AnimeXTokens.textSecondary, bg: '#16161DB3', border: AnimeXTokens.glassBorder },
    upcoming: { fg: AnimeXTokens.accentWarm, bg: a(AnimeXTokens.accent, 0.22), border: a(AnimeXTokens.accent, 0.4) },
    newBadge: { fg: '#FFFFFF', bg: a(AnimeXTokens.accent, 0.85), border: a('#FFFFFF', 0.25) },
    episodes: { fg: '#FFFFFF', bg: '#0E0E13B3', border: AnimeXTokens.glassBorder },
  };
  const { fg, bg, border } = palette[kind];
  const viewport = useViewport();
  const reduceAmbient = reduceAmbientMotion(viewport);
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        padding: '4px 8px',
        background: bg,
        borderRadius: AnimeXTokens.radiusMd,
        border: `1px solid ${border}`,
        boxShadow: reduceAmbient ? undefined : boxShadow([{ color: '#00000066', blur: 8, offset: [0, 2] }]),
      }}
    >
      {icon ? (
        <>
          <Icon name={icon} size={11} color={fg} />
          <div style={{ width: 4 }} />
        </>
      ) : dot ? (
        <div style={{ paddingRight: 5 }}>
          <PulsingDot color={fg} still={reduceAmbient} />
        </div>
      ) : null}
      <div style={dmSansStyle({ size: 10.5, color: fg, weight: 700, letterSpacing: 0.07 })}>{label.toUpperCase()}</div>
    </div>
  );
}

function PulsingDot({ color, still }: { color: string; still: boolean }) {
  const controller = useController(1500);
  useEffect(() => {
    if (still) return void controller.stop();
    controller.repeat({ reverse: true });
  }, [controller, still]);
  const opacity = still ? 1 : 1 - 0.55 * controller.value;
  return <div style={{ width: 6, height: 6, borderRadius: '50%', background: color, opacity }} />;
}

// animex_buttons.dart: every button sits in a 44x44 minimum tap box (the
// `_HoverTap`), content centred vertically, with a 150ms hover change.
function HoverTap({
  onClick,
  label,
  children,
  style,
}: {
  onClick?: () => void;
  label?: string;
  children: (hover: boolean) => ReactNode;
  style?: (hover: boolean) => CSSProperties;
}) {
  const [hover, setHover] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      title={label}
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onFocus={() => setHover(true)}
      onBlur={() => setHover(false)}
      style={{
        minWidth: 44,
        minHeight: 44,
        display: 'flex',
        alignItems: 'center',
        borderRadius: AnimeXTokens.radiusMd,
        transition: 'background-color 150ms, border-color 150ms, transform 150ms, box-shadow 150ms',
        ...style?.(hover),
      }}
    >
      {children(hover)}
    </button>
  );
}

export function AnimeXPrimaryButton({
  label,
  icon,
  onClick,
  fullWidth,
}: {
  label: string;
  icon?: string;
  onClick?: () => void;
  fullWidth?: boolean;
}) {
  return (
    <HoverTap
      onClick={onClick}
      style={(hover) => ({
        padding: '10px 24px',
        width: fullWidth ? '100%' : undefined,
        justifyContent: 'center',
        transform: hover ? 'translateY(-1px)' : undefined,
        background: hover ? AnimeXTokens.accentHover : AnimeXTokens.accent,
        boxShadow: hover ? boxShadow([{ color: withAlpha(AnimeXTokens.accent, 0.35), blur: 20, offset: [0, 6] }]) : undefined,
      })}
    >
      {() => (
        <>
          {icon && (
            <>
              <Icon name={icon} size={15} color="#FFFFFF" />
              <div style={{ width: 8 }} />
            </>
          )}
          <div
            className="ellipsis"
            style={{ ...dmSansStyle({ size: 14, color: '#FFFFFF', weight: 600, letterSpacing: 0.02 }), minWidth: 0 }}
          >
            {label}
          </div>
        </>
      )}
    </HoverTap>
  );
}

export function AnimeXWatchNowButton({ label, onClick }: { label: string; onClick?: () => void }) {
  return (
    <HoverTap
      onClick={onClick}
      style={(hover) => ({
        padding: '9px 18px',
        transform: hover ? 'translateY(-1px)' : undefined,
        background: hover ? '#E8E8E8' : '#FFFFFF',
      })}
    >
      {() => (
        <>
          <Icon name="play_arrow" size={16} color={AnimeXTokens.bg} />
          <div style={{ width: 7 }} />
          <div style={dmSansStyle({ size: 13.5, color: AnimeXTokens.bg, weight: 700 })}>{label}</div>
        </>
      )}
    </HoverTap>
  );
}

export function AnimeXSecondaryButton({ label, icon, onClick }: { label: string; icon?: string; onClick?: () => void }) {
  return (
    <HoverTap
      onClick={onClick}
      style={(hover) => ({
        padding: '10px 20px',
        background: withAlpha('#FFFFFF', hover ? 0.13 : 0.08),
        border: `1px solid ${withAlpha('#FFFFFF', hover ? 0.2 : 0.12)}`,
      })}
    >
      {() => (
        <>
          {icon && (
            <>
              <Icon name={icon} size={15} color={AnimeXTokens.textPrimary} />
              <div style={{ width: 8 }} />
            </>
          )}
          <div style={dmSansStyle({ size: 14, color: AnimeXTokens.textPrimary, weight: 600 })}>{label}</div>
        </>
      )}
    </HoverTap>
  );
}

export function AnimeXGhostButton({
  label,
  icon,
  iconNode,
  color = AnimeXTokens.textSecondary,
  onClick,
}: {
  label: string;
  icon?: string;
  iconNode?: ReactNode;
  color?: string;
  onClick?: () => void;
}) {
  return (
    <HoverTap
      onClick={onClick}
      style={(hover) => ({
        padding: '6px 10px',
        borderRadius: AnimeXTokens.radiusSm,
        background: hover ? withAlpha('#FFFFFF', 0.06) : 'transparent',
      })}
    >
      {(hover) => (
        <>
          {iconNode ? (
            <>
              {iconNode}
              <div style={{ width: 6 }} />
            </>
          ) : icon ? (
            <>
              <Icon name={icon} size={14} color={hover ? '#FFFFFF' : color} />
              <div style={{ width: 6 }} />
            </>
          ) : null}
          <div style={dmSansStyle({ size: 13, color: hover ? AnimeXTokens.textPrimary : color, weight: 600 })}>{label}</div>
        </>
      )}
    </HoverTap>
  );
}

export function AnimeXIconButton({
  icon,
  iconNode,
  tooltip,
  onClick,
  size = 34,
}: {
  icon?: string;
  iconNode?: ReactNode;
  tooltip: string;
  onClick?: () => void;
  size?: number;
}) {
  return (
    <HoverTap onClick={onClick} label={tooltip}>
      {(hover) => (
        <div
          style={{
            // The 44px ConstrainedBox stretches the smaller box.
            width: Math.max(size, 44),
            height: Math.max(size, 44),
            borderRadius: AnimeXTokens.radiusSm,
            background: hover ? withAlpha('#FFFFFF', 0.08) : 'transparent',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            transition: 'background-color 150ms',
          }}
        >
          {iconNode ?? <Icon name={icon ?? ''} size={18} color={hover ? '#FFFFFF' : AnimeXTokens.textSecondary} />}
        </div>
      )}
    </HoverTap>
  );
}

// animex_nav.dart
export function AnimeXTopHeader({
  page,
  hasDetail,
  isDesktop,
  width,
  isCoupleUser,
  isCinemaOnlyUser,
  userName,
  titleJapanese,
  onToggleJapanese,
  onGoBack,
  onNavigate,
  onSearch,
  onMotchiToggle,
  isMotchiOpen = false,
}: {
  page: AnimexPageKind;
  hasDetail: boolean;
  isDesktop: boolean;
  width: number;
  isCoupleUser: boolean;
  isCinemaOnlyUser: boolean;
  userName: string;
  titleJapanese: boolean;
  onToggleJapanese: (jp: boolean) => void;
  onGoBack: () => void;
  onNavigate: (p: AnimexPageKind) => void;
  onSearch: () => void;
  onMotchiToggle?: () => void;
  isMotchiOpen?: boolean;
}) {
  const navItems: [AnimexPageKind, string][] = [
    ['home', 'Home'],
    ['schedule', 'Schedule'],
    ['browse', 'Browse'],
    ['downloads', 'Downloads'],
    ['history', 'History'],
  ];
  const logoSize = isDesktop ? 26 : 22;
  return (
    <header
      style={{
        height: `calc(${AnimeXTokens.headerHeight}px + var(--safe-top, env(safe-area-inset-top, 0px)))`,
        paddingTop: 'var(--safe-top, env(safe-area-inset-top, 0px))',
        paddingLeft: 'var(--safe-left, env(safe-area-inset-left, 0px))',
        paddingRight: 'var(--safe-right, env(safe-area-inset-right, 0px))',
        flexShrink: 0,
        position: 'relative',
        zIndex: 50,
        background: linear([withAlpha(AnimeXTokens.surface, 0.96), withAlpha(AnimeXTokens.bg, 0.94)], {
          begin: Align.topCenter,
          end: Align.bottomCenter,
        }),
        borderBottom: `1px solid ${AnimeXTokens.border}`,
        boxShadow: boxShadow([{ color: '#00000066', blur: 18, offset: [0, 4] }]),
        display: 'flex',
        justifyContent: 'center',
        boxSizing: 'border-box',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: AnimeXTokens.pageMaxWidth,
          padding: `0 ${isDesktop ? 16 : 12}px`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        {(isCoupleUser || isCinemaOnlyUser) && (
          <>
            <AnimeXIconButton icon="arrow_back" tooltip={isCoupleUser ? 'Dashboard' : 'Cinema'} onClick={onGoBack} />
            <div style={{ width: 4 }} />
          </>
        )}
        <button
          type="button"
          className="bare-button"
          onClick={() => onNavigate('home')}
          style={{ display: 'flex', flexShrink: 0, whiteSpace: 'nowrap' }}
        >
          <span style={bebasStyle({ size: logoSize, letterSpacing: 0.06 })}>EVER</span>
          <span
            style={{
              ...bebasStyle({ size: logoSize, color: AnimeXTokens.accent, letterSpacing: 0.06 }),
              textShadow: `0 0 ${(2 * sigma(14)).toFixed(2)}px ${withAlpha(AnimeXTokens.accent, 0.55)}`,
            }}
          >
            GLOW
          </span>
        </button>
        {isDesktop && (
          <>
            <div style={{ width: 8 }} />
            {navItems.map(([key, label]) => (
              <NavItem key={key} label={label} active={page === key && !hasDetail} onClick={() => onNavigate(key)} />
            ))}
          </>
        )}
        <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
          {isCinemaOnlyUser && <MediaSectionMenuButton currentRoute="/anime" />}
          <AnimeXIconButton icon="search" tooltip="Search" onClick={onSearch} />
          {isCoupleUser && hasDetail && onMotchiToggle && (
            <>
              <div style={{ width: isDesktop ? 4 : 2 }} />
              {isDesktop ? (
                <AnimeXGhostButton
                  label="Motchi"
                  iconNode={<MotchiHeaderAvatar size={20} open={isMotchiOpen} glow={0.4} />}
                  color={isMotchiOpen ? AppColors.blushGold : AnimeXTokens.textPrimary}
                  onClick={onMotchiToggle}
                />
              ) : (
                <AnimeXIconButton
                  iconNode={<MotchiHeaderAvatar size={22} open={isMotchiOpen} glow={0.45} />}
                  tooltip="Motchi Chat"
                  onClick={onMotchiToggle}
                />
              )}
            </>
          )}
          {isDesktop && (
            <>
              <div style={{ width: 4 }} />
              <AnimeXGhostButton
                label="My List"
                icon="bookmark_add"
                color={AnimeXTokens.textPrimary}
                onClick={() => onNavigate('myList')}
              />
            </>
          )}
          {width >= 768 ? (
            <>
              <div style={{ width: 10 }} />
              <SegmentedPill labels={['EN', 'JP']} selected={titleJapanese ? 1 : 0} onSelect={(i) => onToggleJapanese(i === 1)} />
              <div style={{ width: 10 }} />
            </>
          ) : (
            <div style={{ width: 4 }} />
          )}
          <div style={{ minWidth: 0, maxWidth: 180, display: 'flex' }}>
            <HoverTap
              onClick={() => onNavigate('myList')}
              style={(hover) => ({
                padding: '8px 16px',
                minWidth: 0,
                maxWidth: '100%',
                background: hover ? '#FFFFFF' : withAlpha('#FFFFFF', 0.9),
                border: `1px solid ${withAlpha('#FFFFFF', 0.2)}`,
              })}
            >
              {() => (
                <>
                  <Icon name="person_outline" size={14} color={AnimeXTokens.bg} />
                  <div style={{ width: 6 }} />
                  <div
                    className="ellipsis"
                    style={{ ...dmSansStyle({ size: 13.5, color: '#0F0F13', weight: 600 }), minWidth: 0 }}
                  >
                    {userName || 'Login'}
                  </div>
                </>
              )}
            </HoverTap>
          </div>
        </div>
      </div>
    </header>
  );
}

function MotchiHeaderAvatar({ size, open, glow }: { size: number; open: boolean; glow: number }) {
  return (
    <div
      style={{
        width: size,
        height: size,
        boxSizing: 'border-box',
        borderRadius: '50%',
        border: `1.2px solid ${open ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.6)}`,
        boxShadow: open ? boxShadow([{ color: withAlpha(AppColors.blushGold, glow), blur: 8 }]) : undefined,
        overflow: 'hidden',
      }}
    >
      <img
        src="/images/motchi_avatar.webp"
        alt=""
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
      />
    </div>
  );
}

function NavItem({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  const [hover, setHover] = useState(false);
  const [focused, setFocused] = useState(false);
  const lit = active || hover || focused;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={{
        margin: '8px 2px',
        padding: '7px 14px',
        borderRadius: AnimeXTokens.radiusMd,
        background: active
          ? withAlpha(AnimeXTokens.accent, 0.14)
          : focused
            ? withAlpha(AnimeXTokens.accent, 0.22)
            : hover
              ? withAlpha('#FFFFFF', 0.06)
              : 'transparent',
        border: `1.5px solid ${focused || active ? AnimeXTokens.accent : 'transparent'}`,
        boxShadow: focused ? boxShadow([{ color: withAlpha(AnimeXTokens.accent, 0.45), blur: 10, spread: 1 }]) : undefined,
        transition: 'background-color 160ms, border-color 160ms, box-shadow 160ms',
      }}
    >
      <div
        style={dmSansStyle({
          size: 14,
          color: lit ? AnimeXTokens.textPrimary : AnimeXTokens.textSecondary,
          weight: focused || active ? 700 : 600,
        })}
      >
        {label}
      </div>
    </button>
  );
}

function SegmentedPill({ labels, selected, onSelect }: { labels: string[]; selected: number; onSelect: (i: number) => void }) {
  return (
    <div
      style={{
        display: 'flex',
        padding: 2,
        borderRadius: 999,
        background: withAlpha('#FFFFFF', 0.05),
        border: `1px solid ${withAlpha('#FFFFFF', 0.1)}`,
      }}
    >
      {labels.map((label, i) => (
        <button
          key={label}
          type="button"
          className="bare-button"
          onClick={() => onSelect(i)}
          style={{
            padding: '4px 10px',
            borderRadius: 999,
            background: i === selected ? AnimeXTokens.accent : 'transparent',
            boxShadow: i === selected ? boxShadow([{ color: withAlpha(AnimeXTokens.accent, 0.25), blur: 12 }]) : undefined,
            transition: 'background-color 150ms, box-shadow 150ms',
          }}
        >
          <div style={dmSansStyle({ size: 11, color: i === selected ? '#FFFFFF' : '#94A3B8', weight: 700 })}>{label}</div>
        </button>
      ))}
    </div>
  );
}

export function AnimeXMobileBottomNav({
  page,
  hasDetail,
  onNavigate,
  onSearch,
}: {
  page: AnimexPageKind;
  hasDetail: boolean;
  onNavigate: (p: AnimexPageKind) => void;
  onSearch: () => void;
}) {
  const items: { key: AnimexPageKind; label: string; icon: [string, IconStyle]; activeIcon: [string, IconStyle] }[] = [
    { key: 'home', label: 'Home', icon: ['home', 'outlined'], activeIcon: ['home', 'round'] },
    { key: 'browse', label: 'Browse', icon: ['compass_calibration', 'outlined'], activeIcon: ['compass_calibration', 'round'] },
    { key: 'schedule', label: 'Schedule', icon: ['calendar_month', 'outlined'], activeIcon: ['calendar_month', 'round'] },
    { key: 'search', label: 'Search', icon: ['search', 'round'], activeIcon: ['search', 'round'] },
    { key: 'myList', label: 'My List', icon: ['bookmark_add', 'outlined'], activeIcon: ['bookmark_add', 'round'] },
    {
      key: 'downloads',
      label: 'Downloads',
      icon: ['download_for_offline', 'outlined'],
      activeIcon: ['download_for_offline', 'round'],
    },
    { key: 'history', label: 'History', icon: ['history', 'round'], activeIcon: ['history', 'round'] },
  ];
  return (
    <nav
      style={{
        flexShrink: 0,
        background: AnimeXTokens.surface,
        position: 'relative',
        zIndex: 50,
        paddingBottom: 'var(--safe-bottom, env(safe-area-inset-bottom, 0px))',
      }}
    >
      <div
        style={{
          height: AnimeXTokens.mobileNavHeight,
          boxSizing: 'border-box',
          borderTop: `1px solid ${AnimeXTokens.border}`,
          display: 'flex',
        }}
      >
        {items.map((item) => {
          const current = page === item.key;
          const active = current && !hasDetail;
          const [name, variant] = current ? item.activeIcon : item.icon;
          return (
            <button
              key={item.key}
              type="button"
              className="bare-button"
              aria-selected={active}
              onClick={() => (item.key === 'search' ? onSearch() : onNavigate(item.key))}
              style={{
                flex: 1,
                minWidth: 0,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <div
                style={{
                  width: 44,
                  height: 30,
                  flexShrink: 0,
                  borderRadius: AnimeXTokens.radiusLg,
                  background: active ? withAlpha(AnimeXTokens.accent, 0.2) : 'transparent',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  transition: 'background-color 160ms',
                }}
              >
                <Icon
                  name={name}
                  variant={variant}
                  size={22}
                  color={active ? AnimeXTokens.accentWarm : AnimeXTokens.textSecondary}
                />
              </div>
              <div style={{ height: 4, flexShrink: 0 }} />
              <div
                className="ellipsis"
                style={{
                  ...dmSansStyle({
                    size: 11,
                    color: active ? AnimeXTokens.textPrimary : AnimeXTokens.textSecondary,
                    weight: active ? 700 : 500,
                  }),
                  maxWidth: '100%',
                }}
              >
                {item.label}
              </div>
            </button>
          );
        })}
      </div>
    </nav>
  );
}

// animex_spotlight.dart: the hero carousel. Each slide holds 20s (30s once
// its muted trailer is playing); the trailer arms 350ms after scrolling
// settles and fades in when YouTube reports play (2.5s fallback).
const STILL_HOLD = 20000;
const TRAILER_HOLD = 30000;
const cacheKeyOf = (item: MediaItem) => `${item.anilistId ?? item.tmdbId}`;

export function AnimeXSpotlight({
  items,
  loading,
  width,
  height,
  onWatch,
  onMoreInfo,
  onTrailer,
}: {
  items: MediaItem[];
  loading: boolean;
  width: number;
  height: number;
  onWatch: (item: MediaItem) => void;
  onMoreInfo: (item: MediaItem) => void;
  onTrailer: (item: MediaItem) => void;
}) {
  const phone = width < 600;
  const heroHeight = Math.min(phone ? 620 : 660, Math.max(phone ? 500 : 440, height * (phone ? 0.68 : 0.58)));

  const [index, setIndex] = useState(0);
  const [muted, setMuted] = useState(true);
  const [playing, setPlaying] = useState(true);
  const [armed, setArmed] = useState(false);
  const [ready, setReady] = useState(false);
  const [trailerCache, setTrailerCache] = useState<Map<string, string | null>>(() => new Map());

  const timer = useRef<number | undefined>(undefined);
  const armTimer = useRef<number | undefined>(undefined);
  const fallbackTimer = useRef<number | undefined>(undefined);
  const mountedRef = useRef(true);
  const lastScrollAt = useRef(0);
  const isScrolling = () => performance.now() - lastScrollAt.current < 150;
  const state = useRef({ items, index, muted, playing, armed, ready, trailerCache });
  state.current = { items, index, muted, playing, armed, ready, trailerCache };

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  useEffect(() => {
    if (typeof document === 'undefined') return;
    const onScroll = () => {
      lastScrollAt.current = performance.now();
    };
    document.addEventListener('scroll', onScroll, { capture: true, passive: true });
    return () => document.removeEventListener('scroll', onScroll, { capture: true });
  }, []);

  const resolveKey = (item: MediaItem, cache = state.current.trailerCache) =>
    item.trailerYoutubeId ? item.trailerYoutubeId : (cache.get(cacheKeyOf(item)) ?? null);
  const currentItem = () => {
    const s = state.current;
    return s.items.length ? s.items[s.index % s.items.length] : null;
  };

  const startTimer = (hold?: number) => {
    window.clearTimeout(timer.current);
    if (!mountedRef.current || (typeof document !== 'undefined' && document.hidden)) return;
    const s = state.current;
    if (!s.muted || !s.playing) return;
    const item = currentItem();
    const ms = hold ?? (item && resolveKey(item) && s.ready ? TRAILER_HOLD : STILL_HOLD);
    timer.current = window.setTimeout(() => {
      if (!mountedRef.current || (typeof document !== 'undefined' && document.hidden)) return;
      const n = state.current.items.length;
      if (n < 2) return;
      select((state.current.index + 1) % n);
    }, ms);
  };

  const onTrailerLoaded = () => {
    if (!mountedRef.current) return;
    window.clearTimeout(fallbackTimer.current);
    setReady(true);
    state.current.ready = true;
    if (state.current.muted && state.current.playing) startTimer(TRAILER_HOLD);
  };

  const resolveTrailer = async (item: MediaItem) => {
    if (item.source === 'tmdb') return;
    const key = cacheKeyOf(item);
    if (state.current.trailerCache.has(key)) return;
    let ytId: string | null = null;
    try {
      const detail = await fetchAniListDetails({ anilistId: item.anilistId, malId: item.tmdbId || undefined });
      ytId = detail?.trailerYoutubeId ?? null;
    } catch {
      ytId = null;
    }
    if (!mountedRef.current) return;
    setTrailerCache((m) => new Map(m).set(key, ytId));
    if (ytId && (typeof document === 'undefined' || !document.hidden)) {
      window.clearTimeout(fallbackTimer.current);
      fallbackTimer.current = window.setTimeout(() => {
        if (mountedRef.current && !state.current.ready) onTrailerLoaded();
      }, 2500);
    }
  };

  const armTrailer = (immediate = false) => {
    window.clearTimeout(armTimer.current);
    window.clearTimeout(fallbackTimer.current);
    if (!mountedRef.current || (typeof document !== 'undefined' && document.hidden)) return;
    const item = currentItem();
    if (!item) return;
    if (!item.trailerYoutubeId && !state.current.trailerCache.has(cacheKeyOf(item))) void resolveTrailer(item);
    const arm = () => {
      if (!mountedRef.current || (typeof document !== 'undefined' && document.hidden)) return;
      setArmed(true);
      state.current.armed = true;
      fallbackTimer.current = window.setTimeout(() => {
        if (mountedRef.current && !state.current.ready) onTrailerLoaded();
      }, 2500);
    };
    const whenSettled = () => {
      window.clearTimeout(armTimer.current);
      armTimer.current = window.setTimeout(() => (isScrolling() ? whenSettled() : arm()), 350);
    };
    if (immediate && !isScrolling()) arm();
    else whenSettled();
  };

  const select = (i: number) => {
    const n = state.current.items.length;
    if (!n) return;
    window.clearTimeout(fallbackTimer.current);
    const next = i % n;
    setIndex(next);
    setArmed(false);
    setReady(false);
    setPlaying(true);
    Object.assign(state.current, { index: next, ready: false, playing: true });
    startTimer();
    armTrailer();
  };

  const pauseTrailer = () => {
    window.clearTimeout(timer.current);
    window.clearTimeout(armTimer.current);
    window.clearTimeout(fallbackTimer.current);
    setPlaying(false);
    setMuted(true);
  };

  const toggleMute = () => {
    state.current.muted = !state.current.muted;
    setMuted(state.current.muted);
    startTimer();
  };
  const togglePlay = () => {
    state.current.playing = !state.current.playing;
    setPlaying(state.current.playing);
    startTimer();
  };

  // didUpdateWidget: a new item list restarts the hold and arms at once.
  const itemsKey = items.map((it) => it.tmdbId).join(',');
  useEffect(() => {
    const n = state.current.items.length;
    const next = n ? state.current.index % n : 0;
    setIndex(next);
    setArmed(false);
    setReady(false);
    Object.assign(state.current, { index: next, ready: false });
    window.clearTimeout(fallbackTimer.current);
    startTimer();
    armTrailer(true);
    const onVisibility = () => {
      if (document.hidden) {
        window.clearTimeout(timer.current);
        window.clearTimeout(armTimer.current);
        window.clearTimeout(fallbackTimer.current);
      } else {
        startTimer();
        if (!state.current.armed) armTrailer();
      }
    };
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      document.removeEventListener('visibilitychange', onVisibility);
      window.clearTimeout(timer.current);
      window.clearTimeout(armTimer.current);
      window.clearTimeout(fallbackTimer.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [itemsKey]);

  // AnimatedSwitcher (700ms): the outgoing slide fades out under the new one.
  const activeIndex = items.length ? index % items.length : 0;
  const active = items[activeIndex];
  const activeKey = active ? cacheKeyOf(active) : '';
  const [slides, setSlides] = useState<{ key: string; item: MediaItem; leaving: boolean }[]>([]);
  useEffect(() => {
    if (!active) return;
    setSlides((prev) => [
      ...prev.filter((s) => s.key !== activeKey).map((s) => ({ ...s, leaving: true })),
      { key: activeKey, item: active, leaving: false },
    ]);
    const t = window.setTimeout(() => setSlides((prev) => prev.filter((s) => !s.leaving)), 700);
    return () => window.clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeKey]);

  if (loading || !active) return <AnimeXSpotlightSkeleton height={heroHeight} />;

  const trailerKey = resolveKey(active, trailerCache);
  const hasTrailer = !!trailerKey;
  const isAiring =
    active.airingStatus.toUpperCase().includes('RELEASING') || active.airingStatus.toUpperCase().includes('AIRING');
  const meta = (label: string) => <div style={dmSansStyle({ size: 13, color: AnimeXTokens.white85 })}>{label}</div>;

  return (
    <section
      style={{
        position: 'relative',
        minHeight: heroHeight,
        overflow: 'hidden',
        background: AnimeXTokens.bg,
        display: 'flex',
        alignItems: 'flex-end',
      }}
    >
      <div style={{ position: 'absolute', inset: 0 }}>
        {slides.map((s) => (
          <SlideLayer key={s.key} item={s.item} leaving={s.leaving} />
        ))}
      </div>

      {hasTrailer && armed && (
        <div
          key={`hero-trailer-layer-${trailerKey}`}
          style={{
            position: 'absolute',
            inset: 0,
            pointerEvents: 'none',
            opacity: ready && playing ? 1 : 0,
            transition: 'opacity 600ms ease-in-out',
          }}
        >
          <TrailerPlayer key={trailerKey} videoKey={trailerKey} muted={muted} playing={playing} onLoaded={onTrailerLoaded} />
        </div>
      )}

      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: linear(['#00000059', 'transparent', '#D90A0A0F', AnimeXTokens.bg, AnimeXTokens.bg], {
            begin: Align.topCenter,
            end: Align.bottomCenter,
            stops: [0, 0.4, 0.8, 0.95, 1],
          }),
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: linear(['#E6000000', '#8C000000', 'transparent'], {
            begin: Align.centerLeft,
            end: Align.centerRight,
            stops: [0, 0.35, 0.7],
          }),
        }}
      />

      <div
        style={{ position: 'relative', width: '100%', boxSizing: 'border-box', padding: `80px 24px 80px ${phone ? 24 : 48}px` }}
      >
        <div key={active.tmdbId} style={{ maxWidth: 640, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <div className="clamp-2" style={bebasStyle({ size: phone ? 38 : 60 })}>
            {active.title}
          </div>
          <div style={{ height: 12 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: '8px 14px' }}>
            <div style={dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm, weight: 700 })}>#{activeIndex + 1} TRENDING</div>
            {isAiring && <div style={dmSansStyle({ size: 12, color: AnimeXTokens.success, weight: 600 })}>Airing Now</div>}
            {active.score != null && active.score > 0 && (
              <div style={{ display: 'flex', alignItems: 'center' }}>
                <Icon name="star" size={15} color={AnimeXTokens.gold} />
                <div style={{ width: 4 }} />
                <div style={dmSansStyle({ size: 13, weight: 700 })}>{active.score.toFixed(1)}</div>
              </div>
            )}
            {active.year && meta(active.year)}
            {active.format && meta(active.format)}
            {active.episodeCount != null && active.episodeCount > 0 && meta(`${active.episodeCount} episodes`)}
          </div>
          {active.genres.length > 0 && (
            <>
              <div style={{ height: 10 }} />
              <div className="clamp-2" style={dmSansStyle({ size: 13, color: AnimeXTokens.white85 })}>
                {active.genres.slice(0, 3).join(' · ')}
              </div>
            </>
          )}
          {active.synopsis && (
            <>
              <div style={{ height: 14 }} />
              <div
                className="clamp-3"
                style={{ ...interBodyStyle({ size: 14, height: 1.55, color: AnimeXTokens.white85 }), whiteSpace: 'pre-wrap' }}
              >
                {active.synopsis}
              </div>
            </>
          )}
          <div style={{ height: 22 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 10 }}>
            <AnimeXWatchNowButton
              label="Watch Now"
              onClick={() => {
                pauseTrailer();
                onWatch(active);
              }}
            />
            <AnimeXSecondaryButton
              label="More Info"
              icon="info_outline"
              onClick={() => {
                pauseTrailer();
                onMoreInfo(active);
              }}
            />
            <AnimeXGhostButton
              label={hasTrailer && !muted ? 'Full Trailer' : 'Trailer'}
              icon={hasTrailer ? (muted ? 'volume_off' : 'volume_up') : 'play_circle_outline'}
              color={AnimeXTokens.white85}
              onClick={() => {
                if (hasTrailer && muted) toggleMute();
                else {
                  pauseTrailer();
                  onTrailer(active);
                }
              }}
            />
          </div>
        </div>
      </div>

      {items.length > 1 && (
        <div style={{ position: 'absolute', left: phone ? 18 : 42, bottom: 16, display: 'flex' }}>
          {items.map((it, i) => {
            const on = i === activeIndex;
            return (
              <button
                key={`${cacheKeyOf(it)}-${i}`}
                type="button"
                className="bare-button"
                aria-label={`Show ${it.title}`}
                aria-selected={on}
                title={`Show ${it.title}`}
                onClick={() => select(i)}
                // IconButton: 44 minimum, padded to a 48px tap target.
                style={{
                  minWidth: 48,
                  height: 48,
                  padding: '0 6px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxSizing: 'border-box',
                }}
              >
                <div
                  style={{
                    width: on ? 28 : 8,
                    height: 4,
                    borderRadius: 2,
                    background: on ? AnimeXTokens.textPrimary : AnimeXTokens.textSecondary,
                    transition: 'width 160ms, background-color 160ms',
                  }}
                />
              </button>
            );
          })}
        </div>
      )}

      {hasTrailer && (
        <div
          style={{
            position: 'absolute',
            right: 24,
            top: 16,
            display: 'flex',
            padding: '5px 6px',
            borderRadius: 999,
            background: withAlpha('#000000', 0.52),
            border: `1px solid ${withAlpha('#FFFFFF', 0.14)}`,
            boxShadow: boxShadow([{ color: withAlpha('#000000', 0.4), blur: 12, offset: [0, 2] }]),
          }}
        >
          <HeroControlButton
            icon={playing ? 'pause' : 'play_arrow'}
            tooltip={playing ? 'Pause trailer' : 'Play trailer'}
            onClick={togglePlay}
          />
          <div style={{ width: 4 }} />
          <HeroControlButton
            icon={muted ? 'volume_off' : 'volume_up'}
            tooltip={muted ? 'Unmute trailer' : 'Mute trailer'}
            highlighted={!muted}
            onClick={toggleMute}
          />
        </div>
      )}
    </section>
  );
}

function SlideLayer({ item, leaving }: { item: MediaItem; leaving: boolean }) {
  const url = item.backdropPath || item.posterPath;
  const [failed, setFailed] = useState(false);
  return (
    <div className={leaving ? 'anx-fade-out' : 'anx-fade-in'} style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      <div className="anx-hero-zoom" style={{ position: 'absolute', inset: 0, background: AnimeXTokens.surfaceRaised }}>
        {url && !failed && (
          <img
            src={url}
            alt=""
            onError={() => setFailed(true)}
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        )}
      </div>
    </div>
  );
}

function HeroControlButton({
  icon,
  tooltip,
  onClick,
  highlighted = false,
}: {
  icon: string;
  tooltip: string;
  onClick: () => void;
  highlighted?: boolean;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={tooltip}
      title={tooltip}
      onClick={onClick}
      style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
    >
      {/* 44px stadium inside the padded 48px tap target. */}
      <div
        style={{
          width: 44,
          height: 44,
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: highlighted ? withAlpha(AnimeXTokens.accent, 0.3) : 'transparent',
        }}
      >
        <Icon name={icon} size={20} color={AnimeXTokens.textPrimary} />
      </div>
    </button>
  );
}

// animex_skeleton.dart
export function AnimeXSkeletonBox({
  width,
  height,
  radius = AnimeXTokens.radiusLg,
}: {
  width?: number;
  height: number;
  radius?: number;
}) {
  return (
    <div
      className="anx-shimmer"
      style={{ width, maxWidth: '100%', height, flexShrink: 0, borderRadius: radius, background: AnimeXTokens.surfaceRaised }}
    />
  );
}

function AnimeXSpotlightSkeleton({ height }: { height: number }) {
  return (
    <div style={{ height, position: 'relative', background: AnimeXTokens.surface }}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: linear(['#33000000', '#8C000000'], { begin: Align.topCenter, end: Align.bottomCenter }),
        }}
      />
      <div style={{ position: 'absolute', inset: 0, padding: '12px 16px 64px', display: 'flex', alignItems: 'flex-end' }}>
        <div
          style={{
            padding: '0 16px',
            width: 520,
            maxWidth: '100%',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-start',
          }}
        >
          <AnimeXSkeletonBox width={120} height={20} radius={4} />
          <div style={{ height: 12 }} />
          <AnimeXSkeletonBox width={380} height={60} radius={4} />
          <div style={{ height: 12 }} />
          <AnimeXSkeletonBox width={280} height={14} radius={4} />
          <div style={{ height: 8 }} />
          <AnimeXSkeletonBox width={210} height={14} radius={4} />
          <div style={{ height: 24 }} />
          <div style={{ display: 'flex' }}>
            <AnimeXSkeletonBox width={130} height={42} radius={6} />
            <div style={{ width: 12 }} />
            <AnimeXSkeletonBox width={100} height={42} radius={AnimeXTokens.radiusMd} />
          </div>
        </div>
      </div>
    </div>
  );
}

// animex_ticker.dart: a 40s marquee of airing shows. It stands still (a
// plain scrollable row) when ambient motion is reduced, and pauses on hover.
export function AnimeXTicker({
  items,
  narrow,
  onSelect,
}: {
  items: MediaItem[];
  narrow: boolean;
  onSelect: (item: MediaItem) => void;
}) {
  const viewport = useViewport();
  const still = reduceAmbientMotion(viewport);
  const controller = useController(40000);
  useEffect(() => {
    if (still || !items.length) controller.stop();
    else if (!controller.isAnimating) controller.repeat();
  }, [controller, still, items.length]);
  if (!items.length) return null;

  // Flutter moves by this estimate, not the measured track width.
  const trackWidth = items.length * 230 + 120;
  const tickerItem = (it: MediaItem, key: string) => (
    <button
      key={key}
      type="button"
      className="bare-button"
      onClick={() => onSelect(it)}
      style={{ display: 'flex', alignItems: 'center', flexShrink: 0, padding: '0 14px', cursor: 'pointer' }}
    >
      <div
        style={{ width: 5, height: 5, borderRadius: '50%', background: withAlpha(AnimeXTokens.accentWarm, 0.7), flexShrink: 0 }}
      />
      <div style={{ width: 10 }} />
      <div
        className="ellipsis"
        style={{ ...dmSansStyle({ size: 12.5, color: AnimeXTokens.textSecondary, weight: 600 }), maxWidth: 190 }}
      >
        {it.title}
      </div>
      <div style={{ width: 8 }} />
      <div
        style={{
          flexShrink: 0,
          padding: '2px 7px',
          borderRadius: AnimeXTokens.radiusSm,
          background: withAlpha(AnimeXTokens.accent, 0.16),
          border: `1px solid ${withAlpha(AnimeXTokens.accent, 0.3)}`,
          ...dmSansStyle({ size: 10.5, color: AnimeXTokens.accentWarm, weight: 800, letterSpacing: 0.04 }),
          whiteSpace: 'nowrap',
        }}
      >
        EP {it.currentEpisode ?? 1}
      </div>
    </button>
  );
  const once = (pass: number) => (
    <div key={pass} style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>
      <div style={{ width: 24, flexShrink: 0 }} />
      {items.map((it, i) => tickerItem(it, `${pass}-${i}`))}
    </div>
  );

  return (
    <div
      onMouseEnter={() => controller.stop()}
      onMouseLeave={() => {
        if (!still) controller.repeat();
      }}
      style={{
        height: 40,
        boxSizing: 'border-box',
        display: 'flex',
        alignItems: 'stretch',
        background: linear([AnimeXTokens.bg, withAlpha(AnimeXTokens.surface, 0.72), AnimeXTokens.bg], {
          begin: Align.topCenter,
          end: Align.bottomCenter,
          stops: [0, 0.45, 1],
        }),
        borderBottom: `1px solid ${AnimeXTokens.border}`,
        overflow: 'hidden',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', padding: '0 16px', flexShrink: 0 }}>
        <div
          style={{
            width: 7,
            height: 7,
            borderRadius: '50%',
            background: AnimeXTokens.success,
            boxShadow: still ? undefined : boxShadow([{ color: AnimeXTokens.success, blur: 8 }]),
          }}
        />
        <div style={{ width: 8 }} />
        <div style={dmSansStyle({ size: 11, color: AnimeXTokens.textPrimary, weight: 800, letterSpacing: 0.1 })}>
          {narrow ? 'AIRING' : 'AIRING TODAY'}
        </div>
      </div>
      {still ? (
        <div className="no-scrollbar" style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'stretch', overflowX: 'auto' }}>
          {items.map((it, i) => tickerItem(it, `s-${i}`))}
        </div>
      ) : (
        <div
          style={{
            flex: 1,
            minWidth: 0,
            overflow: 'hidden',
            display: 'flex',
            alignItems: 'stretch',
            // ShaderMask: 24px fade in on the left, 32px fade out on the right.
            maskImage:
              'linear-gradient(to right, transparent 0, #fff min(24px, 20%), #fff max(calc(100% - 32px), 80%), transparent 100%)',
            WebkitMaskImage:
              'linear-gradient(to right, transparent 0, #fff min(24px, 20%), #fff max(calc(100% - 32px), 80%), transparent 100%)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'stretch', transform: `translateX(${-controller.value * trackWidth}px)` }}>
            {once(0)}
            {once(1)}
          </div>
        </div>
      )}
    </div>
  );
}

export function AnimeXSectionHeader({
  icon,
  title,
  onViewAll,
  viewAllLabel = 'View All',
}: {
  icon: string;
  title: string;
  onViewAll?: () => void;
  viewAllLabel?: string;
}) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', paddingBottom: 14 }}>
      <Icon name={icon} size={20} color={AnimeXTokens.textSecondary} />
      <div style={{ width: 10 }} />
      <div className="clamp-2" style={{ ...dmSansStyle({ size: 20, weight: 700, height: 1.2 }), flex: 1, minWidth: 0 }}>
        {title}
      </div>
      {onViewAll && (
        <button
          type="button"
          className="bare-button"
          onClick={onViewAll}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 4,
            // TextButton: 44 minimum, padded to a 48px tap target.
            minHeight: 48,
            minWidth: 48,
            padding: '0 8px',
            marginLeft: 8,
          }}
        >
          {/* Button text uses only its own style: no inherited spacing or height. */}
          <span
            style={{
              ...dmSansStyle({ size: 12, color: AnimeXTokens.textSecondary, weight: 600 }),
              letterSpacing: 0,
              lineHeight: 'normal',
            }}
          >
            {viewAllLabel}
          </span>
          <Icon name="chevron_right" size={16} color={AnimeXTokens.textSecondary} />
        </button>
      )}
    </div>
  );
}

const POPOVER_CACHE_MAX = 60;
const animePopoverCache = new Map<string, MediaItem>();
clearOnLogout(animePopoverCache);
let closeActiveAnimePopover: (() => void) | null = null;

function animeCacheKey(item: MediaItem): string | null {
  if (item.anilistId && item.anilistId > 0) return `al:${item.anilistId}`;
  if (item.tmdbId > 0) return `mal:${item.tmdbId}`;
  return null;
}

function AnimeXCardPopover({
  item,
  anchor,
  loadingDetails,
  onClick,
  onPointerEnter,
  onPointerLeave,
}: {
  item: MediaItem;
  anchor: DOMRect;
  loadingDetails: boolean;
  onClick: () => void;
  onPointerEnter: () => void;
  onPointerLeave: () => void;
}) {
  const width = 290;
  const vw = typeof window !== 'undefined' ? window.innerWidth : 1200;
  const vh = typeof window !== 'undefined' ? window.innerHeight : 800;
  const placeLeft = anchor.right + width + 24 > vw && anchor.left - width - 16 >= 8;
  const left = placeLeft ? Math.max(8, anchor.left - width - 12) : Math.min(vw - width - 8, anchor.right + 12);
  const top = Math.max(12, Math.min(vh - 280, anchor.top));
  const airing = item.airingStatus.toUpperCase().includes('RELEASING') || item.airingStatus.toUpperCase().includes('AIRING');
  const metaParts = [
    item.year,
    item.format,
    item.episodeCount != null && item.episodeCount > 0 ? `${item.episodeCount} EP` : '',
    item.studio,
  ].filter(Boolean);

  return createPortal(
    <div
      onMouseEnter={onPointerEnter}
      onMouseLeave={onPointerLeave}
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
      style={{
        position: 'fixed',
        left,
        top,
        width,
        zIndex: 1300,
        padding: 14,
        borderRadius: AnimeXTokens.radiusLg,
        background: AnimeXTokens.surfaceRaised,
        border: `1px solid ${withAlpha(AnimeXTokens.accent, 0.38)}`,
        boxShadow: '0 18px 42px rgba(0,0,0,0.75)',
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
        animation: 'shelf-entrance 160ms cubic-bezier(0.215, 0.61, 0.355, 1) both',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
        <div className="clamp-2" style={{ ...dmSansStyle({ size: 15, weight: 700, color: '#FFFFFF', height: 1.25 }), flex: 1 }}>
          {item.title}
        </div>
        {item.score != null && item.score > 0 && (
          <AnimeXBadge label={item.score.toFixed(1)} kind="rating" icon="star" />
        )}
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 6 }}>
        {airing ? <AnimeXBadge label="Airing" kind="airing" dot /> : item.airingStatus ? <AnimeXBadge label={item.airingStatus} kind="finished" /> : null}
        {metaParts.length > 0 && (
          <span style={dmSansStyle({ size: 11.5, color: AnimeXTokens.textSecondary, weight: 500 })}>
            {metaParts.join(' · ')}
          </span>
        )}
      </div>

      {item.genres.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
          {item.genres.slice(0, 3).map((g) => (
            <span
              key={g}
              style={{
                padding: '3px 8px',
                borderRadius: 999,
                background: withAlpha('#FFFFFF', 0.06),
                border: `1px solid ${AnimeXTokens.glassBorder}`,
                ...dmSansStyle({ size: 10.5, color: AnimeXTokens.textPrimary, weight: 600 }),
              }}
            >
              {g}
            </span>
          ))}
        </div>
      )}

      {item.synopsis ? (
        <div
          className="clamp-4"
          style={interBodyStyle({ size: 12, height: 1.45, color: AnimeXTokens.textSecondary })}
        >
          {item.synopsis.replace(/<[^>]+>/g, '')}
        </div>
      ) : loadingDetails ? (
        <div style={dmSansStyle({ size: 12, color: AnimeXTokens.textMuted })}>Loading details…</div>
      ) : null}

      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
        <Icon name="play_circle_filled" size={16} color={AnimeXTokens.accentWarm} />
        <span style={dmSansStyle({ size: 12, color: AnimeXTokens.accentWarm, weight: 700 })}>Watch / More Info</span>
      </div>
    </div>,
    document.body,
  );
}

export function AnimeXPosterCard({
  item,
  width = AnimeXTokens.rowPosterWidthDesktop,
  onClick,
  progress,
  episodeLabel,
  hoverAction,
}: {
  item: MediaItem;
  width?: number;
  onClick: () => void;
  progress?: number;
  episodeLabel?: string;
  hoverAction?: ReactNode;
}) {
  const [hover, setHover] = useState(false);
  const [popoverRect, setPopoverRect] = useState<DOMRect | null>(null);
  const [resolvedItem, setResolvedItem] = useState<MediaItem | null>(() => {
    const key = animeCacheKey(item);
    return key ? (animePopoverCache.get(key) ?? null) : null;
  });
  const [resolving, setResolving] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);
  const showTimerRef = useRef<number | undefined>(undefined);
  const hideTimerRef = useRef<number | undefined>(undefined);
  const viewport = useViewport();
  // Phones and slow devices get the still card: border drawn over the
  // poster, no shadow, lift or zoom.
  const interactive = !reduceAmbientMotion(viewport);
  const hoverDetails = viewport.width >= 768 && !motionReduced();
  const activeItem = resolvedItem ?? item;
  const lit = interactive && hover;
  const airing = activeItem.airingStatus.toUpperCase().includes('RELEASING') || activeItem.airingStatus.toUpperCase().includes('AIRING');
  const epCount = activeItem.episodeCount;
  const metaParts = [activeItem.year, activeItem.format].filter(Boolean);
  const metaLine = metaParts.length ? metaParts.join(' · ') : 'Anime';
  const borderColor = lit ? AnimeXTokens.accent : withAlpha('#FFFFFF', 0.08);

  const closePopover = useCallback(() => {
    window.clearTimeout(showTimerRef.current);
    window.clearTimeout(hideTimerRef.current);
    setHover(false);
    setPopoverRect(null);
  }, []);

  useEffect(() => {
    if (!popoverRect) return;
    const onScroll = () => closePopover();
    window.addEventListener('scroll', onScroll, { capture: true, passive: true });
    return () => window.removeEventListener('scroll', onScroll, { capture: true });
  }, [popoverRect]);

  useEffect(() => {
    return () => {
      window.clearTimeout(showTimerRef.current);
      window.clearTimeout(hideTimerRef.current);
    };
  }, []);

  const maybeResolveDetails = () => {
    if (item.synopsis && item.genres.length > 0) return;
    const key = animeCacheKey(item);
    if (!key) return;
    const cached = animePopoverCache.get(key);
    if (cached) {
      setResolvedItem(cached);
      return;
    }
    if (resolving) return;
    setResolving(true);
    void fetchAniListDetails({ anilistId: item.anilistId, malId: item.tmdbId || undefined })
      .then((detail) => {
        if (!detail) return;
        const enriched: MediaItem = {
          ...item,
          synopsis: item.synopsis || detail.synopsis,
          genres: item.genres.length ? item.genres : detail.genres,
          episodeCount: item.episodeCount ?? detail.episodeCount,
          airingStatus: item.airingStatus || detail.airingStatus,
          format: item.format || detail.format,
          studio: item.studio || detail.studios[0] || '',
          score: item.score ?? detail.averageScore,
          year: item.year || (detail.seasonYear ? String(detail.seasonYear) : ''),
          anilistId: item.anilistId ?? (detail.id || undefined),
        };
        setBoundedCache(animePopoverCache, key, enriched, POPOVER_CACHE_MAX);
        setResolvedItem(enriched);
      })
      .finally(() => setResolving(false));
  };

  const handleEnter = () => {
    window.clearTimeout(hideTimerRef.current);
    setHover(true);
    if (!hoverDetails) return;
    maybeResolveDetails();
    window.clearTimeout(showTimerRef.current);
    showTimerRef.current = window.setTimeout(() => {
      const rect = cardRef.current?.getBoundingClientRect();
      if (!rect) return;
      if (closeActiveAnimePopover && closeActiveAnimePopover !== closePopover) {
        closeActiveAnimePopover();
      }
      closeActiveAnimePopover = closePopover;
      setPopoverRect(rect);
    }, 160);
  };

  const handleLeave = () => {
    window.clearTimeout(showTimerRef.current);
    setHover(false);
    hideTimerRef.current = window.setTimeout(() => {
      setPopoverRect(null);
    }, 90);
  };

  const posterStack = (
    <div
      style={{
        position: 'relative',
        aspectRatio: '2 / 3',
        borderRadius: AnimeXTokens.radiusCard - (interactive ? 1 : 0),
        overflow: 'hidden',
      }}
    >
      {item.posterPath && (
        <img
          src={item.posterPath}
          alt={item.title}
          loading="lazy"
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block',
            transform: lit ? 'scale(1.06)' : undefined,
            transition: interactive ? 'transform 450ms cubic-bezier(0.215, 0.61, 0.355, 1)' : undefined,
          }}
        />
      )}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: interactive
            ? linear([withAlpha('#000000', 0.12), 'transparent', '#00000066', AnimeXTokens.posterScrimBottom], {
                begin: Align.topCenter,
                end: Align.bottomCenter,
                stops: [0, 0.4, 0.78, 1],
              })
            : linear(['transparent', AnimeXTokens.posterScrimBottom], { begin: [0, 0.25], end: Align.bottomCenter }),
          pointerEvents: 'none',
        }}
      />
      <div style={{ position: 'absolute', top: 8, left: 8, display: 'flex', alignItems: 'center' }}>
        {epCount != null && epCount > 0 && (
          <AnimeXBadge label={episodeLabel ?? (epCount >= 100 ? `${epCount} EP` : `EP ${epCount}`)} kind="episodes" />
        )}
        {airing && (
          <>
            <div style={{ width: 6 }} />
            <AnimeXBadge label="NEW" kind="newBadge" />
          </>
        )}
      </div>
      {activeItem.score != null && activeItem.score > 0 && !hoverAction && (
        <div style={{ position: 'absolute', top: 8, right: 8 }}>
          <AnimeXBadge label={activeItem.score.toFixed(1)} kind="rating" icon="star" />
        </div>
      )}
      {hoverAction && hover && (
        <div style={{ position: 'absolute', top: 8, right: 8 }} onClick={(e) => e.stopPropagation()}>
          {hoverAction}
        </div>
      )}
      <div
        style={{
          position: 'absolute',
          left: 10,
          right: 10,
          bottom: 10,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
        }}
      >
        {airing && (
          <div style={{ paddingBottom: 8 }}>
            <AnimeXBadge label="Airing" kind="airing" dot />
          </div>
        )}
        {progress != null && (
          <div
            style={{
              alignSelf: 'stretch',
              height: 4,
              borderRadius: 4,
              background: withAlpha('#FFFFFF', 0.18),
              overflow: 'hidden',
            }}
          >
            <div
              style={{ width: `${Math.min(100, Math.max(0, progress * 100))}%`, height: '100%', background: AnimeXTokens.accent }}
            />
          </div>
        )}
      </div>
    </div>
  );

  return (
    <div
      ref={cardRef}
      data-animex-card="poster"
      style={{ width, flexShrink: 0, cursor: 'pointer' }}
      onClick={() => {
        closePopover();
        onClick();
      }}
      onMouseEnter={handleEnter}
      onMouseLeave={handleLeave}
    >
      {interactive ? (
        // AnimatedContainer: the border pads the poster in by 1px.
        <div
          style={{
            borderRadius: AnimeXTokens.radiusCard,
            border: `1px solid ${borderColor}`,
            transform: lit ? 'translateY(-4px)' : undefined,
            boxShadow: lit
              ? boxShadow([
                  { color: '#00000066', blur: 28, offset: [0, 14] },
                  { color: withAlpha(AnimeXTokens.accent, 0.28), blur: 28, offset: [0, 8] },
                ])
              : boxShadow([{ color: '#00000066', blur: 14, offset: [0, 6] }]),
            transition: 'transform 220ms cubic-bezier(0.215, 0.61, 0.355, 1), border-color 220ms, box-shadow 220ms',
          }}
        >
          {posterStack}
        </div>
      ) : (
        // DecoratedBox: the border paints over the poster's edge.
        <div style={{ position: 'relative' }}>
          {posterStack}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: AnimeXTokens.radiusCard,
              border: `1px solid ${borderColor}`,
              pointerEvents: 'none',
            }}
          />
        </div>
      )}
      <div style={{ height: 10 }} />
      <div
        className="clamp-2"
        style={dmSansStyle({
          size: 13.5,
          color: hover ? '#FFFFFF' : AnimeXTokens.textPrimary,
          weight: 700,
          height: 1.3,
        })}
      >
        {item.title}
      </div>
      <div style={{ height: 4 }} />
      <div
        style={{
          ...dmSansStyle({ size: 11.5, color: AnimeXTokens.textSecondary, weight: 500, height: 1.3 }),
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
        }}
      >
        {metaLine}
      </div>
      {popoverRect && (
        <AnimeXCardPopover
          item={activeItem}
          anchor={popoverRect}
          loadingDetails={resolving && !resolvedItem}
          onClick={() => {
            closePopover();
            onClick();
          }}
          onPointerEnter={() => window.clearTimeout(hideTimerRef.current)}
          onPointerLeave={handleLeave}
        />
      )}
    </div>
  );
}

// animex_poster_row.dart: a fixed-height scroller with 48px edge fades and,
// where hover exists, arrows that page three posters at a time.
export function AnimeXPosterRow({
  items,
  cardWidth,
  onSelect,
  progressByIndex,
  episodeLabels,
}: {
  items: MediaItem[];
  cardWidth: number;
  onSelect: (item: MediaItem) => void;
  progressByIndex?: Record<number, number>;
  episodeLabels?: Record<number, string>;
}) {
  const scrollerRef = useRef<HTMLDivElement | null>(null);
  const [hover, setHover] = useState(false);
  const viewport = useViewport();
  const reduceAmbient = reduceAmbientMotion(viewport);
  if (!items.length) return null;
  const page = cardWidth * 3 + 32;

  // animateTo: 450ms easeOutCubic, clamped to the scroll range.
  const scrollBy = (dx: number) => {
    const el = scrollerRef.current;
    if (!el) return;
    const from = el.scrollLeft;
    const to = Math.min(Math.max(from + dx, 0), el.scrollWidth - el.clientWidth);
    const start = performance.now();
    const step = (now: number) => {
      const t = Math.min(1, (now - start) / 450);
      el.scrollLeft = from + (to - from) * (1 - Math.pow(1 - t, 3));
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };

  const edgeFade = (left: boolean) => (
    <div
      style={{
        position: 'absolute',
        top: 0,
        bottom: 0,
        [left ? 'left' : 'right']: 0,
        width: 48,
        background: linear([AnimeXTokens.bg, withAlpha(AnimeXTokens.bg, 0)], {
          begin: left ? Align.centerLeft : Align.centerRight,
          end: left ? Align.centerRight : Align.centerLeft,
        }),
        pointerEvents: 'none',
      }}
    />
  );
  const arrow = (left: boolean) => (
    <div
      style={{
        position: 'absolute',
        [left ? 'left' : 'right']: 8,
        top: 0,
        bottom: AnimeXTokens.posterDetailsHeight,
        display: 'flex',
        alignItems: 'center',
        opacity: hover ? 1 : 0,
        transition: 'opacity 200ms',
        pointerEvents: hover ? 'auto' : 'none',
      }}
    >
      <button
        type="button"
        className="bare-button"
        aria-label={left ? 'Scroll left' : 'Scroll right'}
        onClick={() => scrollBy(left ? -page : page)}
        style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          background: '#14141CCC',
          border: `1px solid ${withAlpha('#FFFFFF', 0.14)}`,
          boxShadow: boxShadow([{ color: '#00000099', blur: 16, offset: [0, 4] }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
        }}
      >
        <Icon name={left ? 'chevron_left' : 'chevron_right'} size={24} color="#FFFFFF" />
      </button>
    </div>
  );

  return (
    <div
      style={{ position: 'relative', height: cardWidth * 1.5 + AnimeXTokens.posterDetailsHeight }}
      onMouseEnter={reduceAmbient ? undefined : () => setHover(true)}
      onMouseLeave={reduceAmbient ? undefined : () => setHover(false)}
    >
      <div
        ref={scrollerRef}
        className="no-scrollbar"
        style={{
          height: '100%',
          display: 'flex',
          alignItems: 'flex-start',
          overflowX: 'auto',
          overflowY: 'hidden',
          padding: '0 24px',
        }}
      >
        {items.map((item, i) => (
          <Fragment key={`${item.anilistId ?? item.tmdbId}-${i}`}>
            {i > 0 && <div style={{ width: 16, flexShrink: 0 }} />}
            <AnimeXPosterCard
              item={item}
              width={cardWidth}
              onClick={() => onSelect(item)}
              progress={progressByIndex?.[i]}
              episodeLabel={episodeLabels?.[i]}
            />
          </Fragment>
        ))}
      </div>
      {edgeFade(true)}
      {edgeFade(false)}
      {!reduceAmbient && (
        <>
          {arrow(true)}
          {arrow(false)}
        </>
      )}
    </div>
  );
}

export function AnimeXGrid({
  items,
  width,
  onSelect,
  cardHoverAction,
}: {
  items: MediaItem[];
  width: number;
  onSelect: (item: MediaItem) => void;
  cardHoverAction?: (item: MediaItem) => ReactNode;
}) {
  const { cols, tileWidth } = useMemo(() => {
    const contentWidth = Math.max(240, width - 48);
    const count = Math.min(8, Math.max(2, Math.floor(contentWidth / 140)));
    const w = Math.floor((contentWidth - 14 * (count - 1)) / count);
    return { cols: count, tileWidth: w };
  }, [width]);

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
        columnGap: 14,
        rowGap: 28,
      }}
    >
      {items.map((item) => (
        <div key={`${item.anilistId ?? item.tmdbId}-${item.title}`} style={{ minWidth: 0 }}>
          <AnimeXPosterCard
            item={item}
            width={tileWidth}
            onClick={() => onSelect(item)}
            hoverAction={cardHoverAction?.(item)}
          />
        </div>
      ))}
    </div>
  );
}

export function AnimeXRowSkeleton({ count = 8, cardWidth }: { count?: number; cardWidth: number }) {
  return (
    <div style={{ display: 'flex', gap: 16, overflow: 'hidden', padding: '0 24px' }}>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} style={{ width: cardWidth, flexShrink: 0 }}>
          <div style={{ aspectRatio: '2 / 3', borderRadius: AnimeXTokens.radiusCard, background: AnimeXTokens.surfaceRaised }} />
          <div style={{ height: 12, width: '80%', borderRadius: 4, background: AnimeXTokens.surfaceRaised, marginTop: 10 }} />
          <div style={{ height: 10, width: '50%', borderRadius: 4, background: AnimeXTokens.surfaceRaised, marginTop: 6 }} />
        </div>
      ))}
    </div>
  );
}

export function AnimeXFooter({ onGoHome, onOpenDmca }: { onGoHome: () => void; onOpenDmca: () => void }) {
  const { width } = useViewport();
  const isWide = Math.min(width - 32, AnimeXTokens.pageMaxWidth) >= 840;
  const linkStyle: CSSProperties = {
    ...dmSansStyle({ size: 13, color: AnimeXTokens.textMuted, weight: 600 }),
    cursor: 'pointer',
  };
  const links = (
    <>
      <button type="button" className="bare-button" onClick={onOpenDmca} style={linkStyle}>
        DMCA
      </button>
      <div style={{ width: 20 }} />
      <button type="button" className="bare-button" onClick={onGoHome} style={linkStyle}>
        Home
      </button>
      <div style={{ width: 20 }} />
      <span style={dmSansStyle({ size: 12, color: AnimeXTokens.textMuted })}>© 2026 Everglow. For entertainment purposes only.</span>
    </>
  );
  return (
    <footer
      style={{
        marginTop: 48,
        padding: '32px 16px',
        background: AnimeXTokens.surface,
        borderTop: `1px solid ${AnimeXTokens.border}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'center', gap: '8px 10px' }}>
        <div style={{ display: 'flex' }}>
          <span style={bebasStyle({ size: 19, color: AnimeXTokens.textPrimary })}>EVER</span>
          <span style={bebasStyle({ size: 19, color: AnimeXTokens.accent })}>GLOW</span>
        </div>
        <span style={dmSansStyle({ size: 12, color: AnimeXTokens.textMuted })}>— anime section</span>
      </div>
      <div style={{ height: 16 }} />
      {isWide ? (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{links}</div>
      ) : (
        <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'flex-start', justifyContent: 'center', gap: '8px 16px' }}>{links}</div>
      )}
    </footer>
  );
}
