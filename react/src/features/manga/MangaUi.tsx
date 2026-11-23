import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent as ReactKeyboardEvent, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { reduceAmbientMotion } from '../../core/system/device';
import { useViewport } from '../../core/system/viewport';
import { withAlpha } from '../../core/theme/colors';
import { Align, boxShadow, linear, lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
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
        border: `1px solid ${KatanaColors.border}`,
        boxShadow: boxShadow([{ color: '#00000055', blur: 18, offset: [0, 6] }]),
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
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 8 }}>
        <h2 style={{ ...KatanaType.section, margin: 0, ...ellipsis, minWidth: 0 }}>{title}</h2>
        {badge && width >= 430 && (
          <span
            style={{
              flexShrink: 0,
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
  const minH = size === 'sm' ? 38 : 44;
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
        margin: compact ? '2px 1px' : '2px 2px',
        padding: compact ? '7px 8px' : '8px 12px',
        borderRadius: 99,
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
          <Icon name="local_offer" size={18} color={active || open ? KatanaColors.accent : KatanaColors.textMuted} />
        </button>
      ) : (
        <NavItem
          label="Genres"
          icon="local_offer"
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
  const [searchBy, setSearchBy] = useState<'m_name' | 'author' | 'alt_theme'>('m_name');
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

  useEffect(() => {
    if (syncedRecentSearches && syncedRecentSearches.length > 0) {
      setRecentSearches(syncedRecentSearches);
    }
  }, [syncedRecentSearches]);

  useEffect(() => {
    if (!themeMenuOpen) return;
    const onDown = (e: PointerEvent) => {
      if (!themeMenuRef.current?.contains(e.target as Node | null)) setThemeMenuOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setThemeMenuOpen(false);
    };
    window.addEventListener('pointerdown', onDown);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('pointerdown', onDown);
      window.removeEventListener('keydown', onKey);
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
        width: 42,
        height: 42,
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
      <span style={{ fontFamily: Fonts.body, fontWeight: 800, fontSize: logoFont, letterSpacing: -0.45, color: KatanaColors.text, whiteSpace: 'nowrap', lineHeight: 1 }}>
        Manga<span style={{ color: KatanaColors.accent }}>Celestia</span>
      </span>
    </button>
  );

  const searchField = (
    <div
      className="katana-input-shell"
      style={{
        height: desktop ? 40 : 42,
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
          placeholder="Search manga, manhwa, manhua..."
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
          padding: '5px 10px',
          borderRadius: 7,
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${KatanaColors.borderStrong}`,
          display: 'inline-flex',
          alignItems: 'center',
          gap: 4,
        }}
      >
        <span style={bodyText(12, 600, KatanaColors.textMuted, 1.1)}>
          {searchBy === 'm_name' ? 'Title' : searchBy === 'author' ? 'Author' : 'Alt / Theme'}
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
    themeMode === 'light'
      ? { icon: 'light_mode', label: 'Light' }
      : themeMode === 'sepia'
        ? { icon: 'auto_stories', label: 'Sepia' }
        : { icon: 'dark_mode', label: 'Dark' };

  const themeOptions: Array<{ id: KatanaThemeMode; icon: string; label: string }> = [
    { id: 'dark', icon: 'dark_mode', label: 'Dark' },
    { id: 'sepia', icon: 'auto_stories', label: 'Sepia' },
    { id: 'light', icon: 'light_mode', label: 'Light' },
  ];

  const themeButton = onSelectTheme || onCycleTheme ? (
    <div ref={themeMenuRef} style={{ position: 'relative', flexShrink: 0 }}>
      <button
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
          height: desktop ? 36 : 40,
          minWidth: desktop ? 36 : 40,
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
        <div style={{ maxWidth: 1240, margin: '0 auto', padding: '10px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
          {backButton}
          {logo}
          <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>{searchField}</div>
          {themeButton}
          {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
          {desktopLibraryButton}
        </div>
      ) : phoneCompact ? (
        <div style={{ padding: '8px 12px' }}>
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
              aria-label={phoneSearchOpen ? 'Close search' : 'Search manga'}
              aria-expanded={phoneSearchOpen}
              onClick={() => {
                setPhoneSearchOpen((open) => {
                  const next = !open;
                  if (next) {
                    setFocused(true);
                    window.setTimeout(() => searchInputRef.current?.focus(), 20);
                  } else {
                    setFocused(false);
                  }
                  return next;
                });
              }}
              style={{
                height: 40,
                minWidth: 40,
                padding: '0 9px',
                borderRadius: 10,
                background: phoneSearchOpen || hasText ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                border: `1px solid ${phoneSearchOpen || hasText ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 5,
                flexShrink: 0,
              }}
            >
              <Icon name={phoneSearchOpen ? 'close' : 'search'} size={18} color={phoneSearchOpen || hasText ? KatanaColors.accentSoft : KatanaColors.textMuted} />
              {!phoneSearchOpen && !narrow && <span style={bodyText(12.5, 600, KatanaColors.textMuted, 1)}>Search</span>}
            </button>
            {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
          </div>
          {phoneSearchOpen && <div style={{ marginTop: 8 }}>{searchField}</div>}
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
        <div style={{ maxWidth: 1240, margin: '0 auto', padding: '0 16px 10px' }}>
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
                          width: 24,
                          height: 24,
                          display: 'grid',
                          placeItems: 'center',
                          marginRight: 2,
                        }}
                      >
                        <Icon name="close" size={13} color={KatanaColors.textLight} />
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
        <div style={{ maxWidth: 1240, margin: '0 auto', padding: '0 16px 10px' }}>
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
              maxWidth: 1240,
              margin: '0 auto',
              overflowX: 'auto',
              padding: '4px 12px',
              display: 'flex',
              alignItems: 'center',
              gap: 2,
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
    const initial = cleanTitle.charAt(0).toUpperCase();
    const palette = getSeriesVisualAccent(cleanTitle || 'manga');
    return (
      <div
        role={cleanTitle ? 'img' : undefined}
        aria-label={cleanTitle ? `${cleanTitle} cover artwork` : undefined}
        aria-hidden={!cleanTitle ? true : undefined}
        style={{
          position: 'absolute',
          inset: 0,
          backgroundColor: fill,
          background: `linear-gradient(150deg, ${palette.bgStart} 0%, ${palette.bgEnd} 100%)`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 6,
          padding: 8,
          textAlign: 'center',
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
            width: 4,
            background: `linear-gradient(180deg, ${palette.accent}, ${palette.secondary})`,
          }}
        />
        <div
          aria-hidden="true"
          style={{
            position: 'absolute',
            inset: 0,
            opacity: 0.14,
            backgroundImage: `radial-gradient(${palette.accent} 1px, transparent 1px)`,
            backgroundSize: '10px 10px',
            pointerEvents: 'none',
          }}
        />
        {initial ? (
          <div
            style={{
              position: 'relative',
              width: Math.max(32, iconSize + 10),
              height: Math.max(32, iconSize + 10),
              borderRadius: 10,
              background: withAlpha(palette.accent, 0.2),
              border: `1px solid ${withAlpha(palette.accent, 0.55)}`,
              display: 'grid',
              placeItems: 'center',
              fontFamily: Fonts.body,
              fontWeight: 800,
              fontSize: Math.max(15, Math.round(iconSize * 0.65)),
              color: palette.accent,
            }}
          >
            {initial}
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
          title={`${unreadCount} unread chapters`}
          style={{
            padding: '2px 6px',
            borderRadius: 6,
            background: KatanaColors.accent,
            color: KatanaColors.accentInk,
            fontFamily: Fonts.body,
            fontSize: 10,
            fontWeight: 800,
            lineHeight: 1.2,
            boxShadow: '0 2px 6px rgba(0,0,0,0.45)',
          }}
        >
          {unreadCount > 99 ? '99+' : unreadCount}
        </span>
      )}
      {downloadedCount != null && downloadedCount > 0 && (
        <span
          title={`${downloadedCount} downloaded chapters`}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 2,
            padding: '2px 5px',
            borderRadius: 6,
            background: KatanaColors.green,
            color: KatanaColors.accentInk,
            fontFamily: Fonts.body,
            fontSize: 10,
            fontWeight: 800,
            lineHeight: 1.2,
            boxShadow: '0 2px 6px rgba(0,0,0,0.45)',
          }}
        >
          <Icon name="download_done" size={11} color={KatanaColors.accentInk} />
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
  unreadCount,
  downloadedCount,
}: {
  url: string;
  title?: string;
  width: number;
  height: number;
  status: string;
  unreadCount?: number;
  downloadedCount?: number;
}) {
  const completed = status === 'completed';
  return (
    <div style={{ border: `1px solid ${KatanaColors.borderStrong}`, borderRadius: 9, flexShrink: 0, overflow: 'hidden' }}>
      <div style={{ position: 'relative', width, height, background: KatanaColors.surfaceAlt }}>
        <KatanaCoverImage url={url} title={title} emptyIcon="menu_book" iconSize={26} fill={KatanaColors.surfaceAlt} />
        <div
          style={{
            position: 'absolute',
            left: 6,
            top: 6,
            padding: '2px 7px',
            background: completed ? withAlpha(KatanaColors.green, 0.92) : withAlpha(KatanaColors.background, 0.86),
            border: `1px solid ${completed ? KatanaColors.green : KatanaColors.borderStrong}`,
            borderRadius: 6,
            ...bodyText(10, 700, completed ? KatanaColors.accentInk : KatanaColors.text, 1.2),
            whiteSpace: 'nowrap',
          }}
        >
          {completed ? 'Completed' : 'Ongoing'}
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
        border: `1px solid ${lit ? KatanaColors.borderStrong : KatanaColors.border}`,
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
                        background: KatanaColors.crimson,
                        color: white,
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
  const interactive = !reduceAmbientMotion(viewport);
  const lit = interactive && hovered;
  const completed = manga.status === 'completed';
  const totalCh = manga.chapterCount ?? (manga.chapters.length > 0 ? manga.chapters.length : undefined);

  return (
    <article
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        flexDirection: 'column',
        borderRadius: 12,
        background: KatanaColors.surface,
        border: `1px solid ${lit ? KatanaColors.borderStrong : KatanaColors.border}`,
        overflow: 'hidden',
        transform: lit ? 'translateY(-3px)' : undefined,
        boxShadow: lit ? boxShadow([{ color: '#00000080', blur: 18, offset: [0, 8] }]) : undefined,
        transition: interactive ? 'transform 180ms ease, border-color 180ms ease, box-shadow 180ms ease' : undefined,
      }}
    >
      <div
        role="button"
        tabIndex={0}
        aria-label={`Open ${manga.title}`}
        onClick={onSelect}
        onKeyDown={onActivateKey(onSelect)}
        style={{ position: 'relative', width: '100%', aspectRatio: '2 / 3', background: KatanaColors.surfaceAlt, cursor: 'pointer', overflow: 'hidden' }}
      >
        <KatanaCoverImage url={manga.coverUrl} title={manga.title} iconSize={28} />
        <div
          style={{
            position: 'absolute',
            inset: 'auto 0 0 0',
            height: '45%',
            background: `linear-gradient(to top, ${withAlpha(KatanaColors.background, 0.92)}, transparent)`,
            pointerEvents: 'none',
          }}
        />
        <div style={{ position: 'absolute', top: 8, left: 8, display: 'inline-flex', alignItems: 'center', gap: 4, flexWrap: 'wrap', maxWidth: 'calc(100% - 62px)' }}>
          <span
            style={{
              padding: '2px 7px',
              borderRadius: 6,
              background: completed ? withAlpha(KatanaColors.green, 0.92) : withAlpha(KatanaColors.background, 0.86),
              border: `1px solid ${completed ? KatanaColors.green : KatanaColors.borderStrong}`,
              ...bodyText(10, 700, completed ? KatanaColors.accentInk : KatanaColors.text, 1.2),
            }}
          >
            {completed ? 'Completed' : 'Ongoing'}
          </span>
          {manga.rating != null && (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 2,
                padding: '2px 5px',
                borderRadius: 6,
                background: withAlpha(KatanaColors.background, 0.86),
                border: `1px solid ${KatanaColors.borderStrong}`,
                ...bodyText(10, 700, KatanaColors.text, 1.2),
              }}
            >
              <Icon name="star" size={10} color={KatanaColors.accent} />
              <span>{manga.rating.toFixed(1)}</span>
            </span>
          )}
        </div>
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
              left: 8,
              right: 8,
              bottom: 8,
              padding: '4px 8px',
              borderRadius: 7,
              background: 'rgba(19, 22, 31, 0.92)',
              border: `1px solid ${KatanaColors.borderStrong}`,
              ...bodyText(11.5, 600, KatanaColors.link, 1.2),
              ...ellipsis,
              textAlign: 'left',
            }}
          >
            {chapterDisplayTitle(manga.latestChapter)}
          </button>
        )}
      </div>
      <div style={{ padding: '10px 10px 11px', display: 'flex', flexDirection: 'column', gap: 4 }}>
        <button
          type="button"
          className="bare-button"
          title={manga.title}
          onClick={onSelect}
          style={{ textAlign: 'left', width: '100%' }}
        >
          <div className="clamp-2" style={bodyText(13.5, 600, lit ? KatanaColors.accentSoft : KatanaColors.text, 1.25)}>
            {manga.title}
          </div>
        </button>
        <div className="clamp-2" style={{ ...KatanaType.small, fontSize: 12.5, lineHeight: 1.3 }}>
          {manga.genres.slice(0, 2).map((g) => g.name).join(' · ') || 'Manga'}
          {manga.follows != null && manga.follows > 0
            ? ` · ${formatCompactNumber(manga.follows)}`
            : totalCh != null && totalCh > 0
              ? ` · ${totalCh} ch`
              : ''}
        </div>
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
          borderRadius: 9,
          padding: 0,
          border: `1.5px solid ${lit ? KatanaColors.borderStrong : KatanaColors.border}`,
          boxShadow: lit ? boxShadow([{ color: '#00000070', blur: 12, offset: [0, 4] }]) : undefined,
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
              gap: 2,
              padding: '2px 5px',
              borderRadius: 5,
              background: withAlpha(KatanaColors.background, 0.86),
              ...bodyText(10, 700, KatanaColors.text, 1.15),
            }}
          >
            <Icon name="star" size={10} color={KatanaColors.accent} />
            <span>{manga.rating.toFixed(1)}</span>
          </span>
        )}
      </button>
      <div style={{ height: 7 }} />
      <button type="button" className="bare-button" title={manga.title} onClick={onSelect} style={{ textAlign: 'left' }}>
        <div className="clamp-2" style={bodyText(13, 600, lit ? KatanaColors.accentSoft : KatanaColors.text, 1.25)}>
          {manga.title}
        </div>
      </button>
      {reason && (
        <div style={{ ...KatanaType.small, fontSize: 11, color: KatanaColors.textMuted, marginTop: 2, ...ellipsis }} title={reason}>
          {reason}
        </div>
      )}
      <div style={{ height: 3 }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <div style={{ width: 6, height: 6, borderRadius: '50%', flexShrink: 0, background: completed ? KatanaColors.green : KatanaColors.textMuted }} />
        <span style={{ ...KatanaType.small, fontSize: 11.5 }}>{completed ? 'Completed' : 'Ongoing'}</span>
        {manga.follows != null && manga.follows > 0 && (
          <span style={{ ...KatanaType.small, fontSize: 11, marginLeft: 'auto' }}>{formatCompactNumber(manga.follows)}</span>
        )}
      </div>
      {manga.latestChapter && (
        <button
          type="button"
          className="bare-button"
          onClick={() => onOpenChapter?.(manga, manga.latestChapter!.id)}
          style={{ textAlign: 'left', marginTop: 2, ...bodyText(12, 600, KatanaColors.link, 1.2), ...ellipsis }}
        >
          {chapterDisplayTitle(manga.latestChapter)}
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
