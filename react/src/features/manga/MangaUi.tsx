import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent as ReactKeyboardEvent, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { reduceAmbientMotion } from '../../core/system/device';
import { useViewport } from '../../core/system/viewport';
import { withAlpha } from '../../core/theme/colors';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { KatanaFonts as Fonts } from './katanaTokens';
import { Icon } from '../../shared/widgets/Icon';
import { MediaSectionMenuButton } from '../cinema/NetflixUi';
import {
  chapterDisplayTitle,
  clearRecentMangaSearches,
  fetchKatanaSuggestions,
  formatCompactNumber,
  formatKatanaTime,
  getRecentMangaSearches,
  katanaCdnFallback,
  proxyKatanaImageUrl,
  pushRecentMangaSearch,
  removeRecentMangaSearch,
  type KatanaGenre,
  type KatanaManga,
} from './katanaService';
import {
  getSeriesVisualAccent,
  KATANA_BREAKPOINTS,
  KatanaColors,
  KatanaType,
  type KatanaThemeMode,
} from './katanaTokens';
import { getPrimaryVerifiedOfficialLink, getSourceBadgeInfo } from './mangaSearchAndTrust';

export type KatanaNavKey = 'home' | 'latest' | 'directory' | 'newManga' | 'genres' | 'reading' | 'history' | 'downloads' | 'bookmarks';

const white = '#FFFFFF';
const ellipsis: CSSProperties = { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' };

function bodyText(size: number, weight: number, color: string, height = 1.35): CSSProperties {
  return { fontFamily: Fonts.body, fontWeight: weight, color, fontSize: size, lineHeight: lineHeight(size, height) };
}

function onActivateKey(fn: () => void) {
  return (e: ReactKeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      fn();
    }
  };
}

export function KatanaCard({
  children,
  style,
  padding = 0,
  radius = 12,
}: {
  children: ReactNode;
  style?: CSSProperties;
  padding?: number | string;
  radius?: number;
}) {
  return (
    <div
      style={{
        background: KatanaColors.surface,
        borderRadius: radius,
        border: `1px solid ${withAlpha(KatanaColors.border, 0.55)}`,
        boxShadow: boxShadow([{ color: '#00000044', blur: 16, offset: [0, 5] }]),
        padding,
        boxSizing: 'border-box',
        ...style,
      }}
    >
      {children}
    </div>
  );
}

export function KatanaSectionHeader({
  title,
  badge,
  trailing,
  underline = KatanaColors.borderStrong,
}: {
  title: string;
  badge?: string;
  trailing?: ReactNode;
  underline?: string;
}) {
  const { width } = useViewport();
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div
        style={{
          width: 3,
          height: 19,
          flexShrink: 0,
          borderRadius: 4,
          background: underline === KatanaColors.borderStrong
            ? linear([KatanaColors.textMuted, KatanaColors.borderStrong], { begin: Align.topCenter, end: Align.bottomCenter })
            : linear([underline, withAlpha(underline, 0.45)], { begin: Align.topCenter, end: Align.bottomCenter }),
        }}
      />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 8, flexWrap: width < 380 ? 'wrap' : 'nowrap' }}>
        <span aria-hidden="true" style={{ color: KatanaColors.accent, fontSize: 12, lineHeight: 1, flexShrink: 0 }}>✦</span>
        <h2 style={{ ...KatanaType.section, margin: 0, flexShrink: 0, whiteSpace: 'nowrap' }}>{title}</h2>
        <span
          aria-hidden="true"
          style={{
            flex: '1 1 24px',
            minWidth: 0,
            height: 1,
            background: linear([withAlpha(KatanaColors.accent, 0.55), withAlpha(KatanaColors.accent, 0)], {
              begin: Align.centerLeft,
              end: Align.centerRight,
            }),
          }}
        />
        {badge && width >= 430 && (
          <span
            style={{
              flexShrink: 0,
              whiteSpace: 'nowrap',
              padding: '2px 9px',
              borderRadius: 99,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.borderStrong}`,
              ...bodyText(11, 700, KatanaColors.textMuted, 1.2),
              letterSpacing: 0.4,
            }}
          >
            {badge}
          </span>
        )}
      </div>
      {trailing}
    </div>
  );
}

export function KatanaButton({
  label,
  icon,
  onClick,
  filled = true,
  color = KatanaColors.accent,
  disabled = false,
  size = 'md',
}: {
  label: string;
  icon?: string;
  onClick?: () => void;
  filled?: boolean;
  color?: string;
  disabled?: boolean;
  size?: 'sm' | 'md';
}) {
  const isPrimary = color === KatanaColors.accent && filled;
  const fg = filled ? (isPrimary ? KatanaColors.accentInk : white) : color;
  const pad = size === 'sm' ? '7px 13px' : '10px 18px';
  const minH = size === 'sm' ? 40 : 44;
  const fontSize = size === 'sm' ? 12.5 : 13.5;
  return (
    <button
      type="button"
      className="bare-button"
      disabled={disabled}
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 6,
        padding: pad,
        minHeight: minH,
        borderRadius: 99,
        opacity: disabled ? 0.45 : 1,
        cursor: disabled ? 'not-allowed' : 'pointer',
        background: isPrimary
          ? linear([KatanaColors.accentSoft, KatanaColors.accent], { begin: Align.topLeft, end: Align.bottomRight })
          : filled
            ? color
            : withAlpha(color, 0.1),
        border: `1px solid ${filled ? color : withAlpha(color, 0.45)}`,
        transition: 'opacity 160ms ease, transform 160ms ease',
      }}
    >
      {icon && <Icon name={icon} size={size === 'sm' ? 14 : 16} color={fg} />}
      <span style={bodyText(fontSize, 700, fg, 1.2)}>{label}</span>
    </button>
  );
}

export function KatanaEmptyState({
  icon,
  title,
  subtitle,
  actionLabel,
  actionIcon,
  onAction,
}: {
  icon: string;
  title: string;
  subtitle: string;
  actionLabel?: string;
  actionIcon?: string;
  onAction?: () => void;
}) {
  return (
    <KatanaCard padding={28} style={{ textAlign: 'center' }}>
      <div
        style={{
          width: 56,
          height: 56,
          borderRadius: 16,
          margin: '0 auto 12px',
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${KatanaColors.borderStrong}`,
          display: 'grid',
          placeItems: 'center',
        }}
      >
        <Icon name={icon} size={28} color={KatanaColors.accent} />
      </div>
      <div style={{ ...KatanaType.title, fontSize: 16 }}>{title}</div>
      <div style={{ ...KatanaType.body, fontSize: 13.5, marginTop: 6, maxWidth: 380, marginInline: 'auto' }}>{subtitle}</div>
      {actionLabel && onAction && (
        <div style={{ marginTop: 16, display: 'flex', justifyContent: 'center' }}>
          <KatanaButton label={actionLabel} icon={actionIcon} onClick={onAction} />
        </div>
      )}
    </KatanaCard>
  );
}

export function KatanaErrorBanner({
  message,
  onRetry,
}: {
  message: string;
  onRetry?: () => void;
}) {
  return (
    <div
      role="status"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: '10px 14px',
        borderRadius: 10,
        background: withAlpha(KatanaColors.orange, 0.12),
        border: `1px solid ${withAlpha(KatanaColors.orange, 0.4)}`,
        marginBottom: 14,
      }}
    >
      <Icon name="cloud_off" size={18} color={KatanaColors.orange} />
      <span style={{ ...bodyText(13, 500, KatanaColors.text), flex: 1, minWidth: 0 }}>{message}</span>
      {onRetry && <KatanaButton label="Retry" icon="refresh" size="sm" filled={false} color={KatanaColors.accentSoft} onClick={onRetry} />}
    </div>
  );
}

// Header & navigation --------------------------------------------------------

function NavItem({
  label,
  icon,
  active,
  compact = false,
  onClick,
}: {
  label: string;
  icon: string;
  active: boolean;
  compact?: boolean;
  onClick: () => void;
}) {
  const [hover, setHover] = useState(false);
  const highlight = active || hover;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        flexShrink: 0,
        margin: compact ? '0 1px' : '0 2px',
        minHeight: 40,
        padding: compact ? '0 9px' : '0 12px',
        borderRadius: 99,
        display: 'inline-flex',
        alignItems: 'center',
        background: active ? withAlpha(KatanaColors.accent, 0.14) : hover ? KatanaColors.surfaceAlt : 'transparent',
        boxShadow: active ? `inset 0 0 0 1px ${withAlpha(KatanaColors.accent, 0.45)}` : undefined,
        position: 'relative',
        transition: 'background 160ms ease',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: compact ? 4 : 6 }}>
        <Icon name={icon} size={compact ? 14 : 15} color={highlight ? KatanaColors.accentSoft : KatanaColors.textLight} />
        <span
          style={{
            ...bodyText(compact ? 12 : 13, active ? 700 : 600, highlight ? KatanaColors.text : KatanaColors.textMuted, 1.2),
            whiteSpace: 'nowrap',
          }}
        >
          {label}
        </span>
      </div>
    </button>
  );
}

function GenresDropdown({
  genres,
  active,
  iconOnly = false,
  compact = false,
  onSelectGenre,
  onOpenGenresPage,
}: {
  genres: KatanaGenre[];
  active: boolean;
  iconOnly?: boolean;
  compact?: boolean;
  onSelectGenre: (genre: KatanaGenre) => void;
  onOpenGenresPage: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [pos, setPos] = useState<{ top: number; left: number; width: number }>({ top: 96, left: 16, width: 340 });
  const triggerRef = useRef<HTMLDivElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const updatePos = () => {
      const rect = triggerRef.current?.getBoundingClientRect();
      if (!rect) return;
      const w = Math.min(360, Math.max(240, window.innerWidth - 24));
      const left = Math.min(Math.max(12, rect.left), window.innerWidth - w - 12);
      setPos({ top: rect.bottom + 6, left, width: w });
    };
    updatePos();
    const onDown = (e: PointerEvent) => {
      const target = e.target as Node | null;
      if (triggerRef.current?.contains(target) || menuRef.current?.contains(target)) return;
      setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    window.addEventListener('resize', updatePos);
    window.addEventListener('pointerdown', onDown);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('resize', updatePos);
      window.removeEventListener('pointerdown', onDown);
      window.removeEventListener('keydown', onKey);
    };
  }, [open]);

  return (
    <div ref={triggerRef} style={{ display: 'flex', flexDirection: 'column', flexShrink: 0 }}>
      {iconOnly ? (
        <button
          type="button"
          className="bare-button"
          aria-label="Genres"
          title="Browse Genres"
          aria-expanded={open}
          onClick={() => {
            if (genres.length === 0) {
              setOpen(false);
              onOpenGenresPage();
            } else {
              setOpen((o) => !o);
            }
          }}
          style={{
            height: 40,
            minWidth: 40,
            padding: '0 8px',
            borderRadius: 10,
            background: active || open ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
            border: `1px solid ${active || open ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <Icon name="category" size={18} color={active || open ? KatanaColors.accent : KatanaColors.textMuted} />
        </button>
      ) : (
        <NavItem
          label="Genres"
          icon="category"
          active={active}
          compact={compact}
          onClick={() => {
            if (genres.length === 0) {
              setOpen(false);
              onOpenGenresPage();
            } else {
              setOpen((o) => !o);
            }
          }}
        />
      )}
      {open &&
        createPortal(
          <div
            ref={menuRef}
            className="no-scrollbar"
            style={{
              position: 'fixed',
              top: pos.top,
              left: pos.left,
              width: pos.width,
              maxHeight: 360,
              overflowY: 'auto',
              zIndex: 1200,
              background: KatanaColors.surface,
              border: `1px solid ${KatanaColors.borderStrong}`,
              borderRadius: 12,
              boxShadow: boxShadow([{ color: '#000000B3', blur: 24, offset: [0, 12] }]),
              padding: 12,
              boxSizing: 'border-box',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
              <span style={bodyText(13, 700, KatanaColors.text)}>Genres</span>
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  setOpen(false);
                  onOpenGenresPage();
                }}
                style={{ padding: '4px 8px', borderRadius: 6, background: KatanaColors.surfaceAlt }}
              >
                <span style={KatanaType.accent}>Browse all genres</span>
              </button>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {genres.map((g) => (
                <button
                  key={g.slug}
                  type="button"
                  className="bare-button"
                  onClick={() => {
                    setOpen(false);
                    onSelectGenre(g);
                  }}
                  style={{
                    padding: '6px 10px',
                    borderRadius: 8,
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${KatanaColors.border}`,
                    whiteSpace: 'nowrap',
                  }}
                >
                  <span style={bodyText(12.5, 600, KatanaColors.text, 1.2)}>{g.name}</span>
                  {g.count > 0 && <span style={{ ...KatanaType.small, fontSize: 11 }}> ({g.count})</span>}
                </button>
              ))}
            </div>
          </div>,
          document.body,
        )}
    </div>
  );
}

export function KatanaHeader({
  active,
  width,
  userName,
  showBack = true,
  genres = [],
  themeMode = 'dark',
  initialSearchBy = 'm_name',
  syncedRecentSearches,
  onCycleTheme,
  onSelectTheme,
  onBack,
  onSelectNav,
  onSubmitSearch,
  onSelectManga,
  onSelectGenre,
}: {
  active: KatanaNavKey;
  width: number;
  userName: string;
  showBack?: boolean;
  genres?: KatanaGenre[];
  themeMode?: KatanaThemeMode;
  initialSearchBy?: 'm_name' | 'author' | 'alt_theme';
  syncedRecentSearches?: string[];
  onCycleTheme?: () => void;
  onSelectTheme?: (mode: KatanaThemeMode) => void;
  onBack: () => void;
  onSelectNav: (nav: KatanaNavKey) => void;
  onSubmitSearch: (q: string, searchBy: 'm_name' | 'author' | 'alt_theme') => void;
  onSelectManga: (slug: string) => void;
  onSelectGenre: (genre: KatanaGenre) => void;
}) {
  const [queryText, setQueryText] = useState('');
  const [searchBy, setSearchBy] = useState<'m_name' | 'author' | 'alt_theme'>(initialSearchBy);
  const [suggestions, setSuggestions] = useState<KatanaManga[]>([]);
  const [searching, setSearching] = useState(false);
  const [searched, setSearched] = useState(false);
  const [focused, setFocused] = useState(false);
  const [phoneSearchOpen, setPhoneSearchOpen] = useState(false);
  const [themeMenuOpen, setThemeMenuOpen] = useState(false);
  const [highlightIdx, setHighlightIdx] = useState(-1);
  const [recentSearches, setRecentSearches] = useState<string[]>(() => getRecentMangaSearches());
  const searchWrapRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const themeMenuRef = useRef<HTMLDivElement>(null);
  const themeTriggerRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    setSearchBy(initialSearchBy);
  }, [initialSearchBy]);

  useEffect(() => {
    if (syncedRecentSearches && syncedRecentSearches.length > 0) {
      setRecentSearches(syncedRecentSearches);
    }
  }, [syncedRecentSearches]);

  useEffect(() => {
    if (!themeMenuOpen) return;
    const prevFocus = document.activeElement as HTMLElement | null;
    const menuEl = themeMenuRef.current?.querySelector<HTMLElement>('[role="menu"]');
    const getItems = () =>
      Array.from(menuEl?.querySelectorAll<HTMLButtonElement>('[role="menuitemradio"]') ?? []);
    const items = getItems();
    const checkedIdx = items.findIndex((el) => el.getAttribute('aria-checked') === 'true');
    (items[checkedIdx >= 0 ? checkedIdx : 0] ?? items[0])?.focus();

    const onDown = (e: PointerEvent) => {
      if (!themeMenuRef.current?.contains(e.target as Node | null)) setThemeMenuOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        setThemeMenuOpen(false);
        return;
      }
      const list = getItems();
      if (list.length === 0) return;
      const curIdx = list.indexOf(document.activeElement as HTMLButtonElement);
      if (e.key === 'Tab') {
        e.preventDefault();
        const nextIdx = e.shiftKey
          ? (curIdx <= 0 ? list.length - 1 : curIdx - 1)
          : (curIdx + 1) % list.length;
        list[nextIdx]?.focus();
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        list[(curIdx + 1) % list.length]?.focus();
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        list[curIdx <= 0 ? list.length - 1 : curIdx - 1]?.focus();
      }
    };
    window.addEventListener('pointerdown', onDown);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('pointerdown', onDown);
      window.removeEventListener('keydown', onKey);
      (themeTriggerRef.current ?? prevFocus)?.focus?.();
    };
  }, [themeMenuOpen]);

  const phoneCompact = width < KATANA_BREAKPOINTS.tablet;
  const tabletOrDesktop = width >= KATANA_BREAKPOINTS.tablet;
  const desktop = width >= KATANA_BREAKPOINTS.desktop;
  const narrow = width < 500;
  const hasText = queryText !== '';
  const canSubmit = queryText.trim().length >= 2;

  useEffect(() => {
    const onPointerDown = (e: PointerEvent) => {
      if (!searchWrapRef.current?.contains(e.target as Node | null)) {
        setFocused(false);
      }
    };
    window.addEventListener('pointerdown', onPointerDown);
    return () => window.removeEventListener('pointerdown', onPointerDown);
  }, []);

  useEffect(() => {
    const q = queryText.trim();
    setHighlightIdx(-1);
    if (q.length < 2) {
      setSuggestions([]);
      setSearching(false);
      setSearched(false);
      return;
    }
    setSearching(true);
    setSearched(false);
    const t = window.setTimeout(async () => {
      const res = await fetchKatanaSuggestions(q, searchBy);
      setSuggestions(res);
      setSearching(false);
      setSearched(true);
    }, 320);
    return () => window.clearTimeout(t);
  }, [queryText, searchBy]);

  const submit = (override?: string) => {
    const q = (override ?? queryText).trim();
    if (q.length < 2) return;
    setRecentSearches(pushRecentMangaSearch(q, userName));
    setSuggestions([]);
    setSearched(false);
    setFocused(false);
    setQueryText(q);
    onSubmitSearch(q, searchBy);
  };

  const backButton = showBack && (
    <button
      type="button"
      className="bare-button"
      onClick={onBack}
      title="Back to Everglow"
      aria-label="Back to Everglow"
      style={{
        width: 44,
        height: 44,
        flexShrink: 0,
        borderRadius: 10,
        background: KatanaColors.surfaceAlt,
        border: `1px solid ${KatanaColors.border}`,
        display: 'grid',
        placeItems: 'center',
        marginRight: 8,
      }}
    >
      <Icon name="arrow_back_ios_new" size={16} color={KatanaColors.textMuted} />
    </button>
  );

  const logoSize = narrow ? 30 : 34;
  const logoFont = narrow ? 19 : 22;
  const logo = (
    <button
      type="button"
      className="bare-button"
      onClick={() => onSelectNav('home')}
      style={{ display: 'flex', alignItems: 'center', minWidth: 0, gap: 9 }}
    >
      <div
        style={{
          width: logoSize,
          height: logoSize,
          flexShrink: 0,
          boxSizing: 'border-box',
          borderRadius: 9,
          background: linear([KatanaColors.accentSoft, KatanaColors.accentDark], { begin: Align.topLeft, end: Align.bottomRight }),
          display: 'grid',
          placeItems: 'center',
        }}
      >
        <Icon name="auto_stories" size={narrow ? 17 : 19} color={KatanaColors.accentInk} />
      </div>
      <span style={{ fontFamily: Fonts.display, fontWeight: 400, fontSize: logoFont + 6, letterSpacing: 1.2, color: KatanaColors.text, whiteSpace: 'nowrap', lineHeight: 1 }}>
        Manga<span style={{ color: KatanaColors.accent }}>Celestia</span>
      </span>
    </button>
  );

  const searchField = (
    <div
      className="katana-input-shell"
      style={{
        height: 44,
        width: '100%',
        maxWidth: 620,
        boxSizing: 'border-box',
        borderRadius: 10,
        background: KatanaColors.background,
        border: `1px solid ${focused || hasText ? KatanaColors.accent : KatanaColors.border}`,
        display: 'flex',
        alignItems: 'center',
        transition: 'border-color 160ms ease',
      }}
    >
      <div style={{ width: 12, flexShrink: 0 }} />
      <Icon name="search" size={18} color={focused || hasText ? KatanaColors.accent : KatanaColors.textLight} />
      <div style={{ width: 8, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center' }}>
        <input
          ref={searchInputRef}
          role="combobox"
          aria-autocomplete="list"
          aria-expanded={focused && queryText.trim().length >= 2 && (searching || searched)}
          aria-controls="katana-search-listbox"
          aria-activedescendant={highlightIdx >= 0 && suggestions[highlightIdx] ? `katana-suggestion-${highlightIdx}` : undefined}
          value={queryText}
          onFocus={() => setFocused(true)}
          onChange={(e) => setQueryText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'ArrowDown' && suggestions.length > 0) {
              e.preventDefault();
              setHighlightIdx((i) => Math.min(suggestions.length - 1, i + 1));
            } else if (e.key === 'ArrowUp' && suggestions.length > 0) {
              e.preventDefault();
              setHighlightIdx((i) => Math.max(-1, i - 1));
            } else if (e.key === 'Escape') {
              setFocused(false);
            } else if (e.key === 'Enter') {
              if (highlightIdx >= 0 && suggestions[highlightIdx]) {
                const picked = suggestions[highlightIdx];
                setQueryText('');
                setSuggestions([]);
                setSearched(false);
                setFocused(false);
                onSelectManga(picked.slug);
              } else {
                submit();
              }
            }
          }}
          enterKeyHint="search"
          placeholder={
            phoneCompact
              ? searchBy === 'm_name'
                ? 'Search titles…'
                : searchBy === 'author'
                  ? 'Search authors…'
                  : 'Search themes…'
              : 'Search manga, manhwa, manhua...'
          }
          aria-label="Search manga, manhwa, manhua..."
          style={{
            width: '100%',
            padding: 0,
            margin: 0,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            ...bodyText(13.5, 500, KatanaColors.text, 1.4),
            caretColor: KatanaColors.accent,
          }}
        />
        {hasText && (
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              setQueryText('');
              setSuggestions([]);
              setSearched(false);
            }}
            title="Clear"
            aria-label="Clear search"
            style={{ width: 30, height: 30, flexShrink: 0, display: 'grid', placeItems: 'center' }}
          >
            <Icon name="clear" size={16} color={KatanaColors.textLight} />
          </button>
        )}
      </div>
      <button
        type="button"
        className="bare-button"
        onClick={() =>
          setSearchBy((s) => (s === 'm_name' ? 'author' : s === 'author' ? 'alt_theme' : 'm_name'))
        }
        title={
          searchBy === 'm_name'
            ? 'Searching by title — click for author'
            : searchBy === 'author'
              ? 'Searching by author — click for alt names & themes'
              : 'Searching by alt names & themes — click for title'
        }
        style={{
          flexShrink: 0,
          marginRight: 4,
          padding: phoneCompact ? '4px 7px' : '5px 10px',
          borderRadius: 7,
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${withAlpha(KatanaColors.borderStrong, 0.7)}`,
          display: 'inline-flex',
          alignItems: 'center',
          gap: 3,
        }}
      >
        <span style={bodyText(phoneCompact ? 11.5 : 12, 600, KatanaColors.textMuted, 1.1)}>
          {searchBy === 'm_name' ? 'Title' : searchBy === 'author' ? 'Author' : phoneCompact ? 'Theme' : 'Alt / Theme'}
        </span>
        <Icon name="swap_vert" size={13} color={KatanaColors.textLight} />
      </button>
      <button
        type="button"
        className="bare-button"
        onClick={() => submit()}
        title={canSubmit ? 'Search' : 'Type at least 2 letters'}
        aria-label="Search"
        style={{ width: desktop ? 36 : 44, height: desktop ? 36 : 44, flexShrink: 0, borderRadius: 8, display: 'grid', placeItems: 'center', marginRight: 2 }}
      >
        <Icon name="arrow_forward" size={18} color={canSubmit ? KatanaColors.accent : KatanaColors.textLight} />
      </button>
    </div>
  );

  const themeMeta =
    themeMode === 'oled'
      ? { icon: 'contrast', label: 'OLED Black' }
      : themeMode === 'light'
        ? { icon: 'light_mode', label: 'Light' }
        : themeMode === 'sepia'
          ? { icon: 'auto_stories', label: 'Sepia' }
          : { icon: 'dark_mode', label: 'Dark' };

  const themeOptions: Array<{ id: KatanaThemeMode; icon: string; label: string }> = [
    { id: 'dark', icon: 'dark_mode', label: 'Dark' },
    { id: 'oled', icon: 'contrast', label: 'OLED Black' },
    { id: 'sepia', icon: 'auto_stories', label: 'Sepia' },
    { id: 'light', icon: 'light_mode', label: 'Light' },
  ];

  const themeButton = onSelectTheme || onCycleTheme ? (
    <div ref={themeMenuRef} style={{ position: 'relative', flexShrink: 0 }}>
      <button
        ref={themeTriggerRef}
        type="button"
        className="bare-button"
        onClick={() => {
          if (onSelectTheme) {
            setThemeMenuOpen((o) => !o);
          } else {
            onCycleTheme?.();
          }
        }}
        title={`Theme: ${themeMeta.label}`}
        aria-label={`Choose theme (current: ${themeMeta.label})`}
        aria-haspopup={onSelectTheme ? 'menu' : undefined}
        aria-expanded={onSelectTheme ? themeMenuOpen : undefined}
        style={{
          height: 44,
          minWidth: 44,
          padding: desktop ? '0 10px' : '0 8px',
          borderRadius: 10,
          background: themeMenuOpen ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
          border: `1px solid ${themeMenuOpen ? KatanaColors.chipSelectedBorder : KatanaColors.borderStrong}`,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 5,
          flexShrink: 0,
        }}
      >
        <Icon name={themeMeta.icon} size={17} color={KatanaColors.accentSoft} />
        {desktop && <span style={bodyText(12, 600, KatanaColors.textMuted, 1)}>{themeMeta.label}</span>}
      </button>
      {themeMenuOpen && onSelectTheme && (
        <div
          role="menu"
          aria-label="Theme options"
          style={{
            position: 'absolute',
            right: 0,
            top: 'calc(100% + 6px)',
            minWidth: 138,
            padding: 6,
            borderRadius: 11,
            background: KatanaColors.surface,
            border: `1px solid ${KatanaColors.borderStrong}`,
            boxShadow: '0 12px 28px rgba(0,0,0,0.5)',
            zIndex: 60,
            display: 'flex',
            flexDirection: 'column',
            gap: 2,
          }}
        >
          {themeOptions.map((opt) => {
            const activeOpt = themeMode === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                role="menuitemradio"
                aria-checked={activeOpt}
                className="bare-button"
                onClick={() => {
                  onSelectTheme(opt.id);
                  setThemeMenuOpen(false);
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '8px 10px',
                  borderRadius: 8,
                  background: activeOpt ? KatanaColors.chipSelectedBg : 'transparent',
                  textAlign: 'left',
                }}
              >
                <Icon name={opt.icon} size={16} color={activeOpt ? KatanaColors.accent : KatanaColors.textMuted} />
                <span style={{ ...bodyText(12.5, activeOpt ? 700 : 600, activeOpt ? KatanaColors.text : KatanaColors.textMuted, 1.2), flex: 1 }}>
                  {opt.label}
                </span>
                {activeOpt && <Icon name="check" size={15} color={KatanaColors.accent} />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  ) : null;

  const desktopLibraryButton = (
    <button
      type="button"
      className="bare-button"
      onClick={() => onSelectNav('bookmarks')}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '7px 13px',
        borderRadius: 10,
        background: active === 'bookmarks' ? withAlpha(KatanaColors.accent, 0.16) : KatanaColors.surfaceAlt,
        border: `1px solid ${active === 'bookmarks' ? KatanaColors.accent : KatanaColors.borderStrong}`,
      }}
    >
      <Icon name="bookmarks" size={16} color={active === 'bookmarks' ? KatanaColors.accent : KatanaColors.accentSoft} />
      <span style={bodyText(13, 600, KatanaColors.text, 1.2)}>Library</span>
    </button>
  );

  const nav = (key: KatanaNavKey, label: string, icon: string) => (
    <NavItem key={key} label={label} icon={icon} active={active === key} compact={!desktop} onClick={() => onSelectNav(key)} />
  );

  const showRecentDropdown = focused && queryText.trim().length < 2 && (recentSearches.length > 0 || genres.length > 0);
  const showSuggestionDropdown = focused && queryText.trim().length >= 2 && (searching || searched);

  return (
    <header
      ref={searchWrapRef}
      data-user={userName}
      style={{
        background: KatanaColors.headerDark,
        borderBottom: `1px solid ${KatanaColors.border}`,
        paddingTop: 'var(--safe-top, env(safe-area-inset-top, 0px))',
        paddingLeft: 'var(--safe-left, env(safe-area-inset-left, 0px))',
        paddingRight: 'var(--safe-right, env(safe-area-inset-right, 0px))',
        flexShrink: 0,
        position: 'relative',
        zIndex: 20,
      }}
    >
      {desktop ? (
        <div style={{ maxWidth: 1380, margin: '0 auto', padding: '10px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
          {backButton}
          {logo}
          <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>{searchField}</div>
          {themeButton}
          {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
          {desktopLibraryButton}
        </div>
      ) : phoneCompact ? (
        <div style={{ padding: '8px 12px' }}>
          {phoneSearchOpen ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <button
                type="button"
                className="bare-button"
                aria-label="Close search"
                onClick={() => {
                  setPhoneSearchOpen(false);
                  setFocused(false);
                }}
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: 10,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  display: 'grid',
                  placeItems: 'center',
                  flexShrink: 0,
                }}
              >
                <Icon name="arrow_back" size={19} color={KatanaColors.text} />
              </button>
              <div style={{ flex: 1, minWidth: 0 }}>{searchField}</div>
            </div>
          ) : (
            <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
              {backButton}
              <div style={{ minWidth: 0, flexShrink: 1 }}>{logo}</div>
              <div style={{ flex: 1, minWidth: 4 }} />
              <GenresDropdown
                genres={genres}
                active={active === 'genres'}
                iconOnly
                onSelectGenre={onSelectGenre}
                onOpenGenresPage={() => onSelectNav('genres')}
              />
              {themeButton}
              <button
                type="button"
                className="bare-button"
                aria-label="Search manga"
                aria-expanded={false}
                onClick={() => {
                  setPhoneSearchOpen(true);
                  setFocused(true);
                  window.setTimeout(() => searchInputRef.current?.focus(), 20);
                }}
                style={{
                  height: 40,
                  minWidth: 40,
                  padding: '0 9px',
                  borderRadius: 10,
                  background: hasText ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                  border: `1px solid ${hasText ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 5,
                  flexShrink: 0,
                }}
              >
                <Icon name="search" size={18} color={hasText ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                {!narrow && <span style={bodyText(12.5, 600, KatanaColors.textMuted, 1)}>Search</span>}
              </button>
              {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
            </div>
          )}
        </div>
      ) : (
        <div style={{ padding: '10px 14px 10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {backButton}
            {logo}
            <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end' }}>{searchField}</div>
            {themeButton}
            {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
            {desktopLibraryButton}
          </div>
        </div>
      )}

      {showRecentDropdown && (
        <div style={{ maxWidth: 1380, margin: '0 auto', padding: '0 16px 10px' }}>
          <KatanaCard radius={10} padding={12}>
            {recentSearches.length > 0 && (
              <div style={{ marginBottom: genres.length > 0 ? 10 : 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span style={bodyText(12, 700, KatanaColors.textMuted)}>Recent searches</span>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => {
                      clearRecentMangaSearches(userName);
                      setRecentSearches([]);
                    }}
                    style={{ ...KatanaType.small, color: KatanaColors.textLight }}
                  >
                    Clear
                  </button>
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {recentSearches.map((q) => (
                    <div
                      key={q}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        borderRadius: 99,
                        background: KatanaColors.surfaceAlt,
                        border: `1px solid ${KatanaColors.border}`,
                        overflow: 'hidden',
                      }}
                    >
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => submit(q)}
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 5,
                          padding: '5px 6px 5px 10px',
                          ...bodyText(12.5, 500, KatanaColors.text, 1.2),
                        }}
                      >
                        <Icon name="history" size={13} color={KatanaColors.textLight} />
                        <span>{q}</span>
                      </button>
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Remove ${q} from recent searches`}
                        onClick={() => setRecentSearches(removeRecentMangaSearch(q, userName))}
                        style={{
                          width: desktop ? 36 : 40,
                          height: desktop ? 36 : 40,
                          display: 'grid',
                          placeItems: 'center',
                          marginRight: 2,
                        }}
                      >
                        <Icon name="close" size={14} color={KatanaColors.textLight} />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
            {genres.length > 0 && (
              <div>
                <div style={{ ...bodyText(12, 700, KatanaColors.textMuted), marginBottom: 8 }}>Popular genres</div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {genres.slice(0, 8).map((g) => (
                    <button
                      key={g.slug}
                      type="button"
                      className="bare-button"
                      onClick={() => {
                        setFocused(false);
                        onSelectGenre(g);
                      }}
                      style={{
                        padding: '4px 10px',
                        borderRadius: 99,
                        background: withAlpha(KatanaColors.link, 0.1),
                        border: `1px solid ${withAlpha(KatanaColors.link, 0.3)}`,
                        ...bodyText(12, 600, KatanaColors.link, 1.2),
                      }}
                    >
                      {g.name}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </KatanaCard>
        </div>
      )}

      {showSuggestionDropdown && (
        <div style={{ maxWidth: 1380, margin: '0 auto', padding: '0 16px 10px' }}>
          <KatanaCard radius={10} style={{ overflow: 'hidden' }}>
            {searching ? (
              <div style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
                <div
                  className="spin"
                  style={{
                    width: 16,
                    height: 16,
                    borderRadius: '50%',
                    border: `2px solid ${KatanaColors.accent}`,
                    borderRightColor: 'transparent',
                    boxSizing: 'border-box',
                  }}
                />
                <span style={KatanaType.small}>Searching...</span>
              </div>
            ) : suggestions.length === 0 ? (
              <div style={{ padding: 14, ...KatanaType.small }}>No matches found for “{queryText.trim()}”.</div>
            ) : (
              <div id="katana-search-listbox" role="listbox" aria-label="Search suggestions">
                {suggestions.map((it, idx) => (
                  <button
                    key={it.slug}
                    id={`katana-suggestion-${idx}`}
                    type="button"
                    role="option"
                    aria-selected={idx === highlightIdx}
                    className="bare-button"
                    onClick={() => {
                      setQueryText('');
                      setSuggestions([]);
                      setSearched(false);
                      setFocused(false);
                      onSelectManga(it.slug);
                    }}
                    style={{
                      width: '100%',
                      display: 'flex',
                      alignItems: 'center',
                      padding: '8px 12px',
                      gap: 10,
                      textAlign: 'left',
                      background: idx === highlightIdx ? KatanaColors.surfaceGlow : 'transparent',
                    }}
                  >
                    <div style={{ position: 'relative', width: 38, height: 52, borderRadius: 5, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                      <KatanaCoverImage url={it.coverUrl} iconSize={16} />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ ...bodyText(13.5, 600, KatanaColors.text), ...ellipsis }}>{it.title}</div>
                      {it.latestChapter && (
                        <div style={{ ...KatanaType.small, ...ellipsis }}>{chapterDisplayTitle(it.latestChapter)}</div>
                      )}
                    </div>
                    <Icon name="north_east" size={15} color={KatanaColors.textLight} />
                  </button>
                ))}
                <div style={{ height: 1, background: KatanaColors.border }} />
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => submit()}
                  style={{ width: '100%', padding: 11, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, background: KatanaColors.surfaceAlt }}
                >
                  <Icon name="search" size={15} color={KatanaColors.accent} />
                  <span style={KatanaType.accent}>View all results for “{queryText.trim()}”</span>
                </button>
              </div>
            )}
          </KatanaCard>
        </div>
      )}

      {tabletOrDesktop && (
        <div style={{ background: KatanaColors.surface, borderTop: `1px solid ${KatanaColors.border}` }}>
          <div
            className="no-scrollbar"
            style={{
              maxWidth: 1380,
              margin: '0 auto',
              overflowX: 'auto',
              padding: '4px 12px',
              display: 'flex',
              alignItems: 'center',
              gap: 2,
              ...(!desktop
                ? {
                    maskImage: 'linear-gradient(to right, black 0%, black 92%, transparent 100%)',
                    WebkitMaskImage: 'linear-gradient(to right, black 0%, black 92%, transparent 100%)',
                  }
                : {}),
            }}
          >
            {nav('home', 'Home', 'home')}
            {nav('directory', 'Browse', 'explore')}
            {nav('latest', 'Latest', 'bolt')}
            {nav('newManga', desktop ? 'New Releases' : 'New', 'new_releases')}
            <GenresDropdown
              genres={genres}
              active={active === 'genres'}
              compact={!desktop}
              onSelectGenre={onSelectGenre}
              onOpenGenresPage={() => onSelectNav('genres')}
            />
            {nav('reading', desktop ? 'Currently Reading' : 'Reading', 'auto_stories')}
            {nav('history', 'History', 'history')}
            {nav('downloads', 'Downloads', 'download_done')}
          </div>
        </div>
      )}
    </header>
  );
}

/** Fixed bottom tab bar for phone and tablet (< KATANA_BREAKPOINTS.desktop). */
export function KatanaBottomBar({
  active,
  readingCount = 0,
  downloadsCount = 0,
  onSelectNav,
}: {
  active: KatanaNavKey;
  readingCount?: number;
  downloadsCount?: number;
  onSelectNav: (nav: KatanaNavKey) => void;
}) {
  const tabs: Array<{ key: KatanaNavKey; label: string; ariaLabel: string; icon: string; badge?: number }> = [
    { key: 'home', label: 'Home', ariaLabel: 'Home', icon: 'home' },
    { key: 'directory', label: 'Browse', ariaLabel: 'Browse catalog', icon: 'explore' },
    { key: 'reading', label: 'Reading', ariaLabel: 'Currently Reading', icon: 'auto_stories', badge: readingCount },
    { key: 'downloads', label: 'Downloads', ariaLabel: 'Downloads', icon: 'download_done', badge: downloadsCount },
    { key: 'bookmarks', label: 'Library', ariaLabel: 'Library and Bookmarks', icon: 'bookmarks' },
  ];

  const isBrowseActive = active === 'directory' || active === 'latest' || active === 'newManga' || active === 'genres';

  return (
    <nav
      aria-label="Manga navigation"
      style={{
        flexShrink: 0,
        background: KatanaColors.headerDark,
        borderTop: `1px solid ${KatanaColors.border}`,
        paddingBottom: 'var(--safe-bottom, env(safe-area-inset-bottom, 0px))',
        display: 'grid',
        gridTemplateColumns: `repeat(${tabs.length}, minmax(0, 1fr))`,
        zIndex: 30,
      }}
    >
      {tabs.map((t) => {
        const isActive =
          t.key === 'directory'
            ? isBrowseActive
            : t.key === 'reading'
              ? active === 'reading' || active === 'history'
              : active === t.key;
        return (
          <button
            key={t.key}
            type="button"
            className="bare-button"
            aria-label={t.ariaLabel}
            aria-current={isActive ? 'page' : undefined}
            onClick={() => onSelectNav(t.key)}
            style={{
              padding: '8px 4px 7px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 3,
              position: 'relative',
            }}
          >
            <div
              style={{
                position: 'relative',
                padding: '3px 14px',
                borderRadius: 99,
                background: isActive ? withAlpha(KatanaColors.accent, 0.16) : 'transparent',
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <Icon name={t.icon} size={20} color={isActive ? KatanaColors.accent : KatanaColors.textLight} />
              {t.badge != null && t.badge > 0 && (
                <span
                  style={{
                    position: 'absolute',
                    top: -2,
                    right: 4,
                    minWidth: 16,
                    height: 16,
                    padding: '0 4px',
                    borderRadius: 99,
                    background: KatanaColors.accent,
                    color: KatanaColors.accentInk,
                    fontFamily: Fonts.body,
                    fontSize: 10,
                    fontWeight: 800,
                    display: 'grid',
                    placeItems: 'center',
                  }}
                >
                  {t.badge > 99 ? '99+' : t.badge}
                </span>
              )}
            </div>
            <span style={bodyText(11, isActive ? 700 : 500, isActive ? KatanaColors.accentSoft : KatanaColors.textLight, 1.15)}>
              {t.label}
            </span>
          </button>
        );
      })}
    </nav>
  );
}

// Covers & cards -------------------------------------------------------------

export function KatanaCoverImage({
  url,
  title,
  emptyIcon = 'menu_book',
  iconSize = 32,
  fill = KatanaColors.surfaceAlt,
}: {
  url: string;
  title?: string;
  emptyIcon?: string;
  errorIcon?: string;
  iconSize?: number;
  fill?: string;
}) {
  const [step, setStep] = useState(0);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setStep(0);
    setFailed(false);
  }, [url]);

  const resolved = url ? proxyKatanaImageUrl(katanaCdnFallback(url, step)) : '';
  if (!resolved || failed) {
    const cleanTitle = (title ?? '').trim();
    const words = cleanTitle.split(/\s+/).filter(Boolean);
    const monogram =
      words.length >= 2
        ? `${words[0].charAt(0)}${words[1].charAt(0)}`.toUpperCase()
        : cleanTitle.slice(0, 2).toUpperCase();
    const palette = getSeriesVisualAccent(cleanTitle || 'manga');
    let hash = 0;
    for (let i = 0; i < cleanTitle.length; i++) hash = (hash * 31 + cleanTitle.charCodeAt(i)) >>> 0;
    const motifIdx = hash % 6;
    return (
      <div
        role={cleanTitle ? 'img' : undefined}
        aria-label={cleanTitle ? `${cleanTitle} cover artwork${failed ? ' (cover unavailable)' : ''}` : undefined}
        aria-hidden={!cleanTitle ? true : undefined}
        style={{
          position: 'absolute',
          inset: 0,
          backgroundColor: fill,
          background: `linear-gradient(${135 + (hash % 45)}deg, ${palette.bgStart} 0%, ${palette.bgEnd} 100%)`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          justifyContent: 'space-between',
          padding: '10px 10px 10px 14px',
          textAlign: 'left',
          overflow: 'hidden',
        }}
      >
        <div
          aria-hidden="true"
          style={{
            position: 'absolute',
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            background: `linear-gradient(180deg, ${palette.accent}, ${palette.secondary})`,
          }}
        />
        <div
          aria-hidden="true"
          style={{
            position: 'absolute',
            left: 5,
            top: 0,
            bottom: 0,
            width: 2,
            background: 'rgba(0,0,0,0.38)',
          }}
        />
        {/* Hash-varied geometric SVG artwork motif so fallback covers never look identical */}
        <svg
          aria-hidden="true"
          viewBox="0 0 200 300"
          preserveAspectRatio="xMidYMid slice"
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.24, pointerEvents: 'none' }}
        >
          {motifIdx === 0 && (
            <>
              <polygon points="100,24 172,150 100,276 28,150" fill="none" stroke={palette.accent} strokeWidth="3" />
              <circle cx="100" cy="150" r="46" fill={palette.secondary} fillOpacity="0.28" stroke={palette.accent} strokeWidth="2" />
              <line x1="20" y1="260" x2="180" y2="40" stroke={palette.accent} strokeWidth="2" strokeDasharray="6 6" />
            </>
          )}
          {motifIdx === 1 && (
            <>
              <polygon points="18,280 95,70 170,280" fill={palette.accent} fillOpacity="0.24" stroke={palette.accent} strokeWidth="2.5" />
              <polygon points="65,280 138,105 192,280" fill={palette.secondary} fillOpacity="0.28" />
              <circle cx="62" cy="72" r="24" fill={palette.accent} fillOpacity="0.55" />
            </>
          )}
          {motifIdx === 2 && (
            <>
              <path d="M132,48 A62,62 0 1,0 156,162 A48,48 0 1,1 132,48 Z" fill={palette.accent} fillOpacity="0.5" />
              <line x1="24" y1="210" x2="176" y2="210" stroke={palette.secondary} strokeWidth="2.5" />
              <line x1="42" y1="232" x2="158" y2="232" stroke={palette.accent} strokeWidth="2" />
            </>
          )}
          {motifIdx === 3 && (
            <>
              <rect x="28" y="34" width="144" height="106" rx="8" fill="none" stroke={palette.accent} strokeWidth="2.5" />
              <rect x="28" y="152" width="68" height="114" rx="8" fill={palette.secondary} fillOpacity="0.22" stroke={palette.secondary} strokeWidth="2" />
              <rect x="106" y="152" width="66" height="114" rx="8" fill={palette.accent} fillOpacity="0.22" stroke={palette.accent} strokeWidth="2" />
            </>
          )}
          {motifIdx === 4 && (
            <>
              <polygon points="100,36 168,196 32,196" fill="none" stroke={palette.accent} strokeWidth="3" />
              <polygon points="100,244 168,84 32,84" fill="none" stroke={palette.secondary} strokeWidth="2.5" />
              <circle cx="100" cy="140" r="22" fill={palette.accent} fillOpacity="0.45" />
            </>
          )}
          {motifIdx === 5 && (
            <>
              <path d="M20,220 Q100,60 180,140" fill="none" stroke={palette.accent} strokeWidth="5" strokeLinecap="round" />
              <path d="M20,255 Q100,115 180,185" fill="none" stroke={palette.secondary} strokeWidth="3" strokeLinecap="round" />
              <circle cx="144" cy="78" r="28" fill="none" stroke={palette.accent} strokeWidth="2.5" />
            </>
          )}
        </svg>
        <div style={{ position: 'relative', width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 4 }}>
          <div
            aria-hidden="true"
            style={{
              minWidth: Math.max(26, iconSize),
              height: Math.max(26, iconSize),
              padding: '0 6px',
              borderRadius: 7,
              background: withAlpha(palette.accent, 0.22),
              border: `1px solid ${withAlpha(palette.accent, 0.55)}`,
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: Fonts.display,
              fontWeight: 400,
              fontSize: Math.max(12, Math.round(iconSize * 0.46)),
              letterSpacing: 0.6,
              color: palette.accent,
            }}
          >
            {monogram || <Icon name={emptyIcon} size={Math.max(14, iconSize - 10)} color={palette.accent} />}
          </div>
          {iconSize >= 24 && (
            <span
              style={{
                padding: '2px 5px',
                borderRadius: 4,
                background: withAlpha(KatanaColors.background, 0.78),
                border: `1px solid ${withAlpha(palette.accent, 0.35)}`,
                fontFamily: Fonts.body,
                fontSize: 9.5,
                fontWeight: 700,
                color: KatanaColors.textMuted,
                whiteSpace: 'nowrap',
              }}
            >
              {failed ? 'Cover offline' : 'Edition'}
            </span>
          )}
        </div>
        {cleanTitle ? (
          <div
            className="clamp-3"
            style={{
              position: 'relative',
              fontFamily: Fonts.heading,
              fontWeight: 800,
              fontSize: iconSize >= 30 ? 12.5 : 11,
              lineHeight: 1.2,
              letterSpacing: -0.2,
              color: KatanaColors.text,
              textShadow: '0 1px 6px rgba(0,0,0,0.65)',
            }}
          >
            {cleanTitle}
          </div>
        ) : (
          <Icon name={emptyIcon} size={iconSize} color={KatanaColors.textLight} />
        )}
      </div>
    );
  }
  return (
    <img
      src={resolved}
      alt={title ? `${title} cover` : ''}
      loading="lazy"
      onError={() => {
        const currentUrl = katanaCdnFallback(url, step);
        const nextUrl = step < 4 ? katanaCdnFallback(url, step + 1) : currentUrl;
        if (step < 4 && nextUrl !== currentUrl) setStep((s) => s + 1);
        else setFailed(true);
      }}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
    />
  );
}

/** Skeleton placeholders so loading states preserve page layout instead of a bare spinner. */
export function KatanaSkeletonGrid({ count = 6, columns = 3 }: { count?: number; columns?: number }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`, gap: 14 }} aria-busy="true" aria-label="Loading catalog">
      {Array.from({ length: count }).map((_, i) => (
        <div
          key={i}
          style={{
            borderRadius: 12,
            background: KatanaColors.surface,
            border: `1px solid ${KatanaColors.border}`,
            overflow: 'hidden',
          }}
        >
          <div style={{ width: '100%', aspectRatio: '2 / 3', background: KatanaColors.surfaceAlt }} />
          <div style={{ padding: 10, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <div style={{ height: 13, width: '82%', borderRadius: 4, background: KatanaColors.surfaceGlow }} />
            <div style={{ height: 10, width: '54%', borderRadius: 4, background: KatanaColors.surfaceAlt }} />
          </div>
        </div>
      ))}
    </div>
  );
}

export function KatanaSkeletonList({ count = 4 }: { count?: number }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }} aria-busy="true" aria-label="Loading list">
      {Array.from({ length: count }).map((_, i) => (
        <div
          key={i}
          style={{
            display: 'flex',
            gap: 12,
            padding: 12,
            borderRadius: 12,
            background: KatanaColors.surface,
            border: `1px solid ${KatanaColors.border}`,
          }}
        >
          <div style={{ width: 88, height: 126, borderRadius: 8, background: KatanaColors.surfaceAlt, flexShrink: 0 }} />
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8, paddingTop: 4 }}>
            <div style={{ height: 15, width: '70%', borderRadius: 4, background: KatanaColors.surfaceGlow }} />
            <div style={{ height: 11, width: '42%', borderRadius: 4, background: KatanaColors.surfaceAlt }} />
            <div style={{ display: 'flex', gap: 6 }}>
              <div style={{ height: 20, width: 54, borderRadius: 6, background: KatanaColors.surfaceAlt }} />
              <div style={{ height: 20, width: 64, borderRadius: 6, background: KatanaColors.surfaceAlt }} />
            </div>
            <div style={{ height: 28, width: '100%', borderRadius: 7, background: KatanaColors.surfaceAlt, marginTop: 4 }} />
          </div>
        </div>
      ))}
    </div>
  );
}

export function KatanaCoverBadges({
  unreadCount,
  downloadedCount,
}: {
  unreadCount?: number;
  downloadedCount?: number;
}) {
  if (!unreadCount && !downloadedCount) return null;
  return (
    <div style={{ position: 'absolute', top: 6, right: 6, display: 'flex', flexDirection: 'column', gap: 4, alignItems: 'flex-end', zIndex: 2 }}>
      {unreadCount != null && unreadCount > 0 && (
        <span
          title={`${unreadCount} new ${unreadCount === 1 ? 'chapter' : 'chapters'}`}
          aria-label={`${unreadCount} new ${unreadCount === 1 ? 'chapter' : 'chapters'}`}
          style={{
            padding: '2px 7px',
            borderRadius: 6,
            background: KatanaColors.accent,
            color: KatanaColors.accentInk,
            border: `1px solid ${withAlpha(KatanaColors.background, 0.35)}`,
            fontFamily: Fonts.body,
            fontSize: 12,
            fontWeight: 800,
            lineHeight: 1.2,
            boxShadow: '0 2px 8px rgba(0,0,0,0.65)',
          }}
        >
          +{unreadCount > 99 ? '99+' : unreadCount}
        </span>
      )}
      {downloadedCount != null && downloadedCount > 0 && (
        <span
          title={`${downloadedCount} ${downloadedCount === 1 ? 'chapter' : 'chapters'} offline`}
          aria-label={`${downloadedCount} ${downloadedCount === 1 ? 'chapter' : 'chapters'} offline`}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 2,
            padding: '2px 6px',
            borderRadius: 6,
            background: KatanaColors.green,
            color: KatanaColors.accentInk,
            border: `1px solid ${withAlpha(KatanaColors.background, 0.35)}`,
            fontFamily: Fonts.body,
            fontSize: 12,
            fontWeight: 800,
            lineHeight: 1.2,
            boxShadow: '0 2px 8px rgba(0,0,0,0.65)',
          }}
        >
          <Icon name="download_done" size={12} color={KatanaColors.accentInk} />
          <span>{downloadedCount}</span>
        </span>
      )}
    </div>
  );
}

export function KatanaBreadcrumb({ items, onHome }: { items: string[]; onHome: () => void }) {
  return (
    <nav aria-label="Breadcrumb" style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
      <button type="button" className="bare-button" aria-label="Manga Home" onClick={onHome} style={{ display: 'inline-flex', alignItems: 'center' }}>
        <Icon name="home" size={15} color={KatanaColors.textMuted} />
      </button>
      {items.map((label, i) => (
        <span key={`${label}-${i}`} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <Icon name="chevron_right" size={14} color={KatanaColors.textLight} />
          <span style={bodyText(12.5, i === items.length - 1 ? 600 : 500, i === items.length - 1 ? KatanaColors.text : KatanaColors.textMuted)}>
            {label}
          </span>
        </span>
      ))}
    </nav>
  );
}

function ItemCover({
  url,
  title,
  width,
  height,
  status,
  source,
  unreadCount,
  downloadedCount,
}: {
  url: string;
  title?: string;
  width: number;
  height: number;
  status: string;
  source?: 'mangakatana' | 'mangadex' | 'comick' | 'bato';
  unreadCount?: number;
  downloadedCount?: number;
}) {
  const completed = status === 'completed';
  const srcCode =
    source === 'mangadex'
      ? 'MD · MangaDex'
      : source === 'comick'
        ? 'CK · ComicK'
        : source === 'bato'
          ? 'BT · Bato'
          : source === 'mangakatana'
            ? 'MK · Katana'
            : null;
  const srcColor =
    source === 'mangadex'
      ? KatanaColors.teal
      : source === 'comick'
        ? KatanaColors.link
        : source === 'bato'
          ? KatanaColors.green
          : KatanaColors.accentSoft;
  return (
    <div style={{ border: `1px solid ${KatanaColors.borderStrong}`, borderRadius: 9, flexShrink: 0, overflow: 'hidden' }}>
      <div style={{ position: 'relative', width, height, background: KatanaColors.surfaceAlt }}>
        <KatanaCoverImage url={url} title={title} emptyIcon="menu_book" iconSize={26} fill={KatanaColors.surfaceAlt} />
        <div
          style={{
            position: 'absolute',
            left: 6,
            top: 6,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 4,
            flexWrap: 'wrap',
          }}
        >
          <span
            style={{
              padding: '2px 7px',
              background: completed ? withAlpha(KatanaColors.green, 0.92) : withAlpha(KatanaColors.background, 0.86),
              border: `1px solid ${completed ? KatanaColors.green : KatanaColors.borderStrong}`,
              borderRadius: 6,
              ...bodyText(10, 700, completed ? KatanaColors.accentInk : KatanaColors.text, 1.2),
              whiteSpace: 'nowrap',
            }}
          >
            {completed ? 'Completed' : 'Ongoing'}
          </span>
          {srcCode && (
            <span
              title={
                source === 'mangadex'
                  ? 'Catalog Source: MangaDex'
                  : source === 'comick'
                    ? 'Catalog Source: ComicK'
                    : source === 'bato'
                      ? 'Catalog Source: Bato.to'
                      : 'Catalog Source: MangaKatana'
              }
              style={{
                padding: '2px 6px',
                borderRadius: 5,
                background: withAlpha(KatanaColors.background, 0.9),
                border: `1px solid ${withAlpha(srcColor, 0.55)}`,
                ...bodyText(10, 800, srcColor, 1.2),
              }}
            >
              {srcCode}
            </span>
          )}
        </div>
        <KatanaCoverBadges unreadCount={unreadCount} downloadedCount={downloadedCount} />
      </div>
    </div>
  );
}

export function KatanaItemCard({
  manga,
  compact,
  dense = false,
  unreadCount,
  downloadedCount,
  onSelectManga,
  onSelectGenre,
  onOpenChapter,
}: {
  manga: KatanaManga;
  compact: boolean;
  dense?: boolean;
  unreadCount?: number;
  downloadedCount?: number;
  onSelectManga: (slug: string) => void;
  onSelectGenre?: (genre: KatanaGenre) => void;
  onOpenChapter?: (manga: KatanaManga, chapterId: string) => void;
}) {
  const viewport = useViewport();
  const [hovered, setHovered] = useState(false);
  const interactive = !reduceAmbientMotion(viewport);
  const lit = interactive && hovered;

  const coverW = compact ? 92 : 114;
  const coverH = compact ? 132 : 162;
  const genres = manga.genres.slice(0, compact ? 3 : 5);
  const chapters = manga.recentChapters.slice(0, 2);
  const totalCh = manga.chapterCount ?? (manga.chapters.length > 0 ? manga.chapters.length : undefined);

  return (
    <article
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        gap: compact ? 12 : 16,
        padding: compact ? 12 : 14,
        borderRadius: 12,
        background: lit ? KatanaColors.surfaceGlow : KatanaColors.surface,
        border: `1px solid ${lit ? KatanaColors.borderStrong : withAlpha(KatanaColors.border, 0.5)}`,
        transition: interactive ? 'background 160ms ease, border-color 160ms ease' : undefined,
        alignItems: 'flex-start',
      }}
    >
      <button
        type="button"
        className="bare-button"
        aria-label={`Open ${manga.title}`}
        onClick={() => onSelectManga(manga.slug)}
        style={{ flexShrink: 0, textAlign: 'left' }}
      >
        <ItemCover
          url={manga.coverUrl}
          title={manga.title}
          width={coverW}
          height={coverH}
          status={manga.status}
          source={manga.source}
          unreadCount={unreadCount}
          downloadedCount={downloadedCount}
        />
      </button>

      <div style={{ flex: 1, minWidth: 0 }}>
        <button
          type="button"
          className="bare-button"
          onClick={() => onSelectManga(manga.slug)}
          style={{ width: '100%', textAlign: 'left' }}
        >
          <div className="clamp-2" style={bodyText(15.5, 700, lit ? KatanaColors.accentSoft : KatanaColors.text, 1.3)}>
            {manga.title}
          </div>
        </button>

        <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 12, rowGap: 4, alignItems: 'center', marginTop: 5 }}>
          {manga.rating != null && (
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
              <Icon name="star" size={13} color={KatanaColors.accent} />
              <span style={bodyText(12, 700, KatanaColors.text, 1.2)}>{manga.rating.toFixed(1)}</span>
            </span>
          )}
          {manga.follows != null && manga.follows > 0 && (
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
              <Icon name="bookmark_border" size={13} color={KatanaColors.textLight} />
              <span style={KatanaType.small}>{formatCompactNumber(manga.follows)}</span>
            </span>
          )}
          {totalCh != null && totalCh > 0 && (
            <span style={KatanaType.small}>{totalCh} ch</span>
          )}
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="schedule" size={13} color={KatanaColors.textLight} />
            <span style={KatanaType.small}>{manga.updateText || 'Recently updated'}</span>
          </span>
        </div>

        {genres.length > 0 && (
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5, marginTop: 8 }}>
            {genres.map((g) => (
              <button
                key={g.slug}
                type="button"
                className="bare-button"
                onClick={() => onSelectGenre?.(g)}
                style={{
                  padding: '3px 9px',
                  borderRadius: 6,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  ...bodyText(11.5, 600, KatanaColors.textMuted, 1.2),
                  whiteSpace: 'nowrap',
                }}
              >
                {g.name}
              </button>
            ))}
          </div>
        )}

        {!compact && manga.summary && !dense && (
          <div className="clamp-2" style={{ ...KatanaType.body, fontSize: 13, marginTop: 8 }}>
            {manga.summary}
          </div>
        )}

        {chapters.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 5, marginTop: 9 }}>
            {chapters.map((ch, i) => {
              const first = i === 0;
              return (
                <button
                  key={ch.id}
                  type="button"
                  className="bare-button"
                  onClick={() => onOpenChapter?.(manga, ch.id)}
                  style={{
                    width: '100%',
                    padding: '6px 10px',
                    borderRadius: 8,
                    background: first ? withAlpha(KatanaColors.accent, 0.1) : KatanaColors.surfaceAlt,
                    border: `1px solid ${first ? withAlpha(KatanaColors.accent, 0.35) : KatanaColors.border}`,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                    textAlign: 'left',
                  }}
                >
                  <Icon name={first ? 'bolt' : 'menu_book'} size={14} color={first ? KatanaColors.accent : KatanaColors.textLight} />
                  <span style={{ ...bodyText(12.5, 600, first ? KatanaColors.text : KatanaColors.textMuted, 1.2), ...ellipsis, flex: 1, minWidth: 0 }}>
                    {chapterDisplayTitle(ch)}
                  </span>
                  {ch.isNew && (
                    <span
                      style={{
                        padding: '1px 6px',
                        borderRadius: 4,
                        background: KatanaColors.accent,
                        color: KatanaColors.accentInk,
                        fontFamily: Fonts.body,
                        fontSize: 10,
                        fontWeight: 800,
                      }}
                    >
                      NEW
                    </span>
                  )}
                  {ch.updateAt && (
                    <span style={{ ...KatanaType.small, fontSize: 11.5, whiteSpace: 'nowrap' }}>
                      {formatKatanaTime(ch.updateAt)}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        ) : manga.latestChapter ? (
          <button
            type="button"
            className="bare-button"
            onClick={() => onOpenChapter?.(manga, manga.latestChapter!.id)}
            style={{ marginTop: 8, ...KatanaType.accent, ...ellipsis }}
          >
            Latest: {chapterDisplayTitle(manga.latestChapter)}
          </button>
        ) : null}
      </div>
    </article>
  );
}

/** Responsive poster card for tablet & desktop discovery grids. */
export function KatanaPosterCard({
  manga,
  unreadCount,
  downloadedCount,
  onSelect,
  onOpenChapter,
}: {
  manga: KatanaManga;
  unreadCount?: number;
  downloadedCount?: number;
  onSelect: () => void;
  onOpenChapter?: (manga: KatanaManga, chapterId: string) => void;
}) {
  const viewport = useViewport();
  const [hovered, setHovered] = useState(false);
  const [sourceDetailOpen, setSourceDetailOpen] = useState(false);
  const interactive = !reduceAmbientMotion(viewport);
  const lit = interactive && hovered;
  const completed = manga.status === 'completed';
  const totalCh = manga.chapterCount ?? (manga.chapters.length > 0 ? manga.chapters.length : undefined);
  const verifiedOfficial = getPrimaryVerifiedOfficialLink(manga);
  const srcInfo = manga.source ? getSourceBadgeInfo(manga.source, manga.slug) : null;

  return (
    <article
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        flexDirection: 'column',
        borderRadius: 12,
        background: 'transparent',
        transform: lit ? 'translateY(-3px)' : undefined,
        transition: interactive ? 'transform 180ms ease' : undefined,
      }}
    >
      <div
        role="button"
        tabIndex={0}
        aria-label={`Open ${manga.title}`}
        onClick={onSelect}
        onKeyDown={onActivateKey(onSelect)}
        style={{
          position: 'relative',
          width: '100%',
          aspectRatio: '2 / 3',
          borderRadius: 11,
          background: KatanaColors.surfaceAlt,
          cursor: 'pointer',
          overflow: 'hidden',
          boxShadow: lit
            ? boxShadow([{ color: '#00000088', blur: 20, offset: [0, 8] }])
            : boxShadow([{ color: '#00000048', blur: 12, offset: [0, 4] }]),
          outline: lit ? `1.5px solid ${withAlpha(KatanaColors.accent, 0.55)}` : 'none',
          transition: interactive ? 'box-shadow 180ms ease, outline-color 180ms ease' : undefined,
        }}
      >
        <KatanaCoverImage url={manga.coverUrl} title={manga.title} iconSize={28} />
        <div
          style={{
            position: 'absolute',
            inset: 'auto 0 0 0',
            height: '46%',
            background: `linear-gradient(to top, ${withAlpha(KatanaColors.background, 0.94)} 0%, ${withAlpha(KatanaColors.background, 0.48)} 54%, transparent 100%)`,
            pointerEvents: 'none',
          }}
        />
        <div style={{ position: 'absolute', top: 7, left: 7, display: 'inline-flex', alignItems: 'center', gap: 4, flexWrap: 'wrap', maxWidth: 'calc(100% - 58px)' }}>
          {completed && (
            <span
              style={{
                padding: '2px 7px',
                borderRadius: 6,
                background: withAlpha(KatanaColors.green, 0.96),
                border: `1px solid ${withAlpha(KatanaColors.background, 0.35)}`,
                boxShadow: '0 2px 6px rgba(0,0,0,0.55)',
                ...bodyText(12, 800, KatanaColors.accentInk, 1.2),
              }}
            >
              Completed
            </span>
          )}
          {manga.rating != null && (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 3,
                padding: '2px 7px',
                borderRadius: 6,
                background: withAlpha(KatanaColors.background, 0.92),
                border: `1px solid ${withAlpha(KatanaColors.text, 0.2)}`,
                boxShadow: '0 2px 6px rgba(0,0,0,0.55)',
                ...bodyText(12, 800, KatanaColors.text, 1.2),
              }}
            >
              <Icon name="star" size={11} color={KatanaColors.accent} />
              <span>{manga.rating.toFixed(1)}</span>
            </span>
          )}
        </div>
        {sourceDetailOpen && manga.source && (() => {
          const srcInfo = getSourceBadgeInfo(manga.source, manga.slug);
          return (
            <div
              role="dialog"
              aria-label={`${srcInfo.name} source provenance`}
              onClick={(e) => e.stopPropagation()}
              style={{
                position: 'absolute',
                top: 34,
                left: 6,
                right: 6,
                zIndex: 4,
                padding: '8px 10px',
                borderRadius: 9,
                background: withAlpha(KatanaColors.background, 0.96),
                border: `1px solid ${KatanaColors.borderStrong}`,
                boxShadow: '0 8px 20px rgba(0,0,0,0.75)',
                display: 'flex',
                flexDirection: 'column',
                gap: 4,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6 }}>
                <span style={{ ...bodyText(12, 800, KatanaColors.text, 1.2) }}>
                  {srcInfo.name} ({srcInfo.badge})
                </span>
                <button
                  type="button"
                  className="bare-button"
                  aria-label="Close source info"
                  onClick={(e) => {
                    e.stopPropagation();
                    setSourceDetailOpen(false);
                  }}
                  style={{ padding: 2, color: KatanaColors.textLight, display: 'inline-flex' }}
                >
                  <Icon name="close" size={13} color={KatanaColors.textLight} />
                </button>
              </div>
              <span style={{ ...bodyText(11, 600, '#CBD5E1', 1.3) }}>{srcInfo.signals.provenance}</span>
              <span style={{ ...bodyText(10.5, 500, KatanaColors.textLight, 1.3) }}>{srcInfo.signals.specialty}</span>
              {verifiedOfficial && (
                <a
                  href={verifiedOfficial.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={(e) => e.stopPropagation()}
                  style={{
                    marginTop: 2,
                    padding: '4px 8px',
                    borderRadius: 6,
                    background: withAlpha(KatanaColors.green, 0.18),
                    border: `1px solid ${withAlpha(KatanaColors.green, 0.55)}`,
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 4,
                    textDecoration: 'none',
                    ...bodyText(11, 700, '#6EE7B7', 1.2),
                  }}
                >
                  <Icon name="verified" size={12} color="#34D399" />
                  <span style={{ ...ellipsis }}>{verifiedOfficial.name}</span>
                  <Icon name="open_in_new" size={11} color="#34D399" />
                </a>
              )}
            </div>
          );
        })()}
        <KatanaCoverBadges unreadCount={unreadCount} downloadedCount={downloadedCount} />
        {manga.latestChapter && (
          <button
            type="button"
            className="bare-button"
            onClick={(e) => {
              e.stopPropagation();
              onOpenChapter?.(manga, manga.latestChapter!.id);
            }}
            style={{
              position: 'absolute',
              left: 7,
              right: 7,
              bottom: 0,
              minHeight: 40,
              padding: '0 0 7px 0',
              display: 'flex',
              alignItems: 'flex-end',
              background: 'transparent',
              textAlign: 'left',
            }}
          >
            <span
              style={{
                width: '100%',
                padding: '4px 8px',
                borderRadius: 7,
                background: withAlpha(KatanaColors.background, 0.92),
                border: '1px solid rgba(255, 255, 255, 0.16)',
                backdropFilter: 'blur(4px)',
                ...bodyText(12, 700, KatanaColors.link, 1.2),
                ...ellipsis,
                display: 'block',
              }}
            >
              {chapterDisplayTitle(manga.latestChapter)}
              {manga.latestChapter.updateAt ? (
                <span style={{ ...bodyText(11, 600, KatanaColors.textLight, 1.2) }}> · {formatKatanaTime(manga.latestChapter.updateAt)}</span>
              ) : null}
            </span>
          </button>
        )}
      </div>
      <div style={{ padding: '6px 2px 2px' }}>
        <button
          type="button"
          className="bare-button"
          title={manga.title}
          onClick={onSelect}
          style={{
            textAlign: 'left',
            width: '100%',
            minHeight: 44,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'flex-start',
            gap: 3,
            padding: '2px 0',
          }}
        >
          <div className="clamp-2" style={bodyText(13.5, 600, lit ? KatanaColors.accentSoft : KatanaColors.text, 1.25)}>
            {manga.title}
          </div>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 5,
              flexWrap: 'wrap',
              ...KatanaType.small,
              fontSize: 11,
            }}
          >
            <span className="clamp-2" style={{ fontSize: 12.5, lineHeight: 1.3 }}>
              {manga.genres.slice(0, 2).map((g) => g.name).join(' · ') || 'Manga'}
            </span>
            {srcInfo && (
              <button
                type="button"
                className="bare-button"
                onClick={(e) => {
                  e.stopPropagation();
                  setSourceDetailOpen((v) => !v);
                }}
                title={srcInfo.tooltip}
                aria-label={`Where this comes from: ${srcInfo.tooltip}`}
                aria-expanded={sourceDetailOpen}
                style={{ display: 'inline-flex', alignItems: 'center', gap: 3, color: KatanaColors.textLight }}
              >
                <span style={{ ...bodyText(11, 700, KatanaColors.textLight, 1.2) }}>{srcInfo.shortLabel}</span>
                {verifiedOfficial && (
                  <span style={{ ...bodyText(11, 700, KatanaColors.green, 1.2) }}>Official</span>
                )}
              </button>
            )}
            {manga.follows != null && manga.follows > 0
              ? ` · ${formatCompactNumber(manga.follows)} readers`
              : totalCh != null && totalCh > 0
                ? ` · ${totalCh} chapters`
                : ''}
          </div>
        </button>
      </div>
    </article>
  );
}

export function KatanaCompactCard({
  manga,
  width,
  reason,
  onSelect,
  onOpenChapter,
}: {
  manga: KatanaManga;
  width: number;
  reason?: string;
  onSelect: () => void;
  onOpenChapter?: (manga: KatanaManga, chapterId: string) => void;
}) {
  const viewport = useViewport();
  const [hovered, setHovered] = useState(false);
  const interactive = !reduceAmbientMotion(viewport);
  const lit = interactive && hovered;
  const completed = manga.status === 'completed';

  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{ width, flexShrink: 0, display: 'flex', flexDirection: 'column' }}
    >
      <button
        type="button"
        className="bare-button"
        aria-label={`Open ${manga.title}`}
        title={manga.title}
        onClick={onSelect}
        style={{
          borderRadius: 10,
          padding: 0,
          border: lit ? `1.5px solid ${withAlpha(KatanaColors.accent, 0.55)}` : '1px solid transparent',
          boxShadow: lit
            ? boxShadow([{ color: '#00000078', blur: 16, offset: [0, 6] }])
            : boxShadow([{ color: '#00000044', blur: 10, offset: [0, 3] }]),
          transform: lit ? 'translateY(-2px)' : undefined,
          transition: interactive ? 'border-color 160ms ease, box-shadow 160ms ease, transform 160ms ease' : undefined,
          overflow: 'hidden',
          width,
          height: Math.round(width * 1.44),
          position: 'relative',
          background: KatanaColors.surfaceAlt,
        }}
      >
        <KatanaCoverImage url={manga.coverUrl} title={manga.title} emptyIcon="menu_book" iconSize={24} fill={KatanaColors.surfaceAlt} />
        {manga.rating != null && (
          <span
            style={{
              position: 'absolute',
              top: 6,
              right: 6,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 3,
              padding: '2px 6px',
              borderRadius: 6,
              background: withAlpha(KatanaColors.background, 0.92),
              border: `1px solid ${withAlpha(KatanaColors.text, 0.2)}`,
              boxShadow: '0 2px 6px rgba(0,0,0,0.55)',
              ...bodyText(12, 800, KatanaColors.text, 1.15),
            }}
          >
            <Icon name="star" size={11} color={KatanaColors.accent} />
            <span>{manga.rating.toFixed(1)}</span>
          </span>
        )}
      </button>
      <div style={{ height: 4 }} />
      <button
        type="button"
        className="bare-button"
        title={manga.title}
        onClick={onSelect}
        style={{ textAlign: 'left', width: '100%', minHeight: 40, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '2px 0' }}
      >
        <div className="clamp-2" style={bodyText(13, 600, lit ? KatanaColors.accentSoft : KatanaColors.text, 1.25)}>
          {manga.title}
        </div>
      </button>
      {reason && (
        <div style={{ ...KatanaType.small, fontSize: 12, color: KatanaColors.textMuted, marginTop: 2, ...ellipsis }} title={reason}>
          {reason}
        </div>
      )}
      <div style={{ height: 2 }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <div style={{ width: 6, height: 6, borderRadius: '50%', flexShrink: 0, background: completed ? KatanaColors.green : KatanaColors.textMuted }} />
        <span style={{ ...KatanaType.small, fontSize: 12 }}>{completed ? 'Completed' : 'Ongoing'}</span>
        {manga.follows != null && manga.follows > 0 && (
          <span style={{ ...KatanaType.small, fontSize: 12, marginLeft: 'auto' }}>{formatCompactNumber(manga.follows)}</span>
        )}
      </div>
      {manga.latestChapter && (
        <button
          type="button"
          className="bare-button"
          onClick={() => onOpenChapter?.(manga, manga.latestChapter!.id)}
          style={{
            textAlign: 'left',
            minHeight: 40,
            display: 'flex',
            alignItems: 'center',
            width: '100%',
            ...bodyText(12, 600, KatanaColors.link, 1.2),
            ...ellipsis,
          }}
        >
          <span style={ellipsis}>{chapterDisplayTitle(manga.latestChapter)}</span>
        </button>
      )}
    </div>
  );
}

export function KatanaPagination({
  page,
  hasPrev,
  hasNext,
  totalPages,
  totalResults,
  onPageChange,
}: {
  page: number;
  hasPrev: boolean;
  hasNext: boolean;
  totalPages?: number;
  totalResults?: number;
  onPageChange: (next: number) => void;
}) {
  const pageLabel = totalPages && totalPages > 1
    ? `Page ${page} of ${totalPages}`
    : !hasNext && page > 1
      ? `Page ${page} · Last page`
      : !hasNext && totalResults != null
        ? `${totalResults} ${totalResults === 1 ? 'result' : 'results'}`
        : `Page ${page}`;

  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
      <KatanaButton label="Previous" icon="chevron_left" filled={false} disabled={!hasPrev} onClick={() => hasPrev && onPageChange(page - 1)} />
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
        <span style={{ ...KatanaType.small, color: KatanaColors.textMuted, fontWeight: 600 }}>{pageLabel}</span>
        {totalResults != null && totalPages && totalPages > 1 && (
          <span style={{ ...KatanaType.small, fontSize: 11 }}>{totalResults} total</span>
        )}
      </div>
      <KatanaButton label="Next" icon="chevron_right" filled={false} disabled={!hasNext} onClick={() => hasNext && onPageChange(page + 1)} />
    </div>
  );
}
