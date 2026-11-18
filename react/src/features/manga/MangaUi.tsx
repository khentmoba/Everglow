// Ports of lib/features/manga/presentation/katana/ (katana_theme.dart,
// katana_header.dart, katana_item_card.dart): box for box.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
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
  fetchKatanaSuggestions,
  formatKatanaTime,
  katanaCdnFallback,
  proxyKatanaImageUrl,
  type KatanaGenre,
  type KatanaManga,
} from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';

export type KatanaNavKey = 'home' | 'latest' | 'directory' | 'newManga' | 'genres' | 'reading' | 'downloads' | 'bookmarks';

const scrimStrong = '#00000066';
const white = '#FFFFFF';
const ellipsis: CSSProperties = { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' };

/** AppTypography.outfitBold / outfitWhite at a size, merged into bodyMedium. */
function outfit(size: number, weight: number, color: string, height = 20 / 14): CSSProperties {
  return { fontFamily: Fonts.body, fontWeight: weight, color, fontSize: size, lineHeight: lineHeight(size, height) };
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
        boxShadow: boxShadow([{ color: '#00000066', blur: 18, offset: [0, 6] }]),
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
  underline = KatanaColors.accent,
}: {
  title: string;
  badge?: string;
  trailing?: ReactNode;
  underline?: string;
}) {
  const { width } = useViewport();
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 4,
          height: 20,
          flexShrink: 0,
          borderRadius: 4,
          background: linear([underline, KatanaColors.accentSoft], { begin: Align.topCenter, end: Align.bottomCenter }),
        }}
      />
      <div style={{ width: 10, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center' }}>
        <span style={{ ...outfit(18, 600, KatanaColors.text, 1.2), ...ellipsis, minWidth: 0 }}>{title}</span>
        {badge && width >= 430 && (
          <>
            <div style={{ width: 8, flexShrink: 0 }} />
            <span
              style={{
                flexShrink: 0,
                padding: '2px 8px',
                borderRadius: 99,
                background: withAlpha(KatanaColors.accent, 0.14),
                border: `1px solid ${withAlpha(KatanaColors.accent, 0.4)}`,
                ...outfit(10, 600, KatanaColors.accentSoft),
                letterSpacing: 0.8,
              }}
            >
              {badge}
            </span>
          </>
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
}: {
  label: string;
  icon?: string;
  onClick?: () => void;
  filled?: boolean;
  color?: string;
}) {
  const primaryPink = color === KatanaColors.accent && filled;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        padding: '9px 16px',
        borderRadius: 99,
        background: primaryPink
          ? linear([KatanaColors.accent, KatanaColors.accentDark], { begin: Align.topLeft, end: Align.bottomRight })
          : filled
            ? color
            : withAlpha(color, 0.08),
        border: `1px solid ${filled ? color : withAlpha(color, 0.55)}`,
      }}
    >
      {icon && (
        <>
          <Icon name={icon} size={15} color={filled ? white : color} />
          <div style={{ width: 6 }} />
        </>
      )}
      <span style={outfit(13, 600, filled ? white : color)}>{label}</span>
    </button>
  );
}

// katana_header.dart ---------------------------------------------------------

function NavItem({
  label,
  icon,
  active,
  onClick,
}: {
  label: string;
  icon: string;
  active: boolean;
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
        margin: '2px 3px',
        // A 1.5px border: Chrome snaps CSS borders to whole pixels, so it is
        // painted inset and the padding carries its width, as Container does.
        padding: '9.5px 13.5px 6.5px',
        borderRadius: 99,
        background: active ? withAlpha(KatanaColors.accent, 0.14) : 'transparent',
        boxShadow: active ? `inset 0 0 0 1.5px ${withAlpha(KatanaColors.accent, 0.45)}` : undefined,
        position: 'relative',
      }}
    >
      <div style={{ paddingBottom: 5.5, display: 'flex', alignItems: 'center' }}>
        <Icon name={icon} size={14} color={highlight ? KatanaColors.accent : KatanaColors.textLight} />
        <div style={{ width: 5 }} />
        <span
          style={{
            // AnimatedDefaultTextStyle replaces bodyMedium: natural height, no letter spacing.
            ...outfit(13, 600, highlight ? KatanaColors.accent : KatanaColors.text, 1.26),
            letterSpacing: 0,
            whiteSpace: 'nowrap',
            transition: 'color 200ms ease-out',
          }}
        >
          {label}
        </span>
      </div>
      <div
        style={{
          position: 'absolute',
          left: 17.5,
          right: 17.5,
          bottom: 6.5,
          height: 2.5,
          borderRadius: 2,
          background: KatanaColors.accent,
          opacity: active ? 1 : 0,
          transform: `scaleX(${active ? 1 : 0})`,
          transformOrigin: 'left center',
          transition: 'transform 260ms cubic-bezier(0.215, 0.61, 0.355, 1), opacity 260ms cubic-bezier(0.215, 0.61, 0.355, 1)',
        }}
      />
    </button>
  );
}

function GenresDropdown({
  genres,
  active,
  onSelectGenre,
  onOpenGenresPage,
}: {
  genres: KatanaGenre[];
  active: boolean;
  onSelectGenre: (genre: KatanaGenre) => void;
  onOpenGenresPage: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [pos, setPos] = useState<{ top: number; left: number; width: number }>({ top: 96, left: 16, width: 320 });
  const triggerRef = useRef<HTMLDivElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const updatePos = () => {
      const rect = triggerRef.current?.getBoundingClientRect();
      if (!rect) return;
      const w = Math.min(320, Math.max(220, window.innerWidth - 24));
      const left = Math.min(Math.max(12, rect.left), window.innerWidth - w - 12);
      setPos({ top: rect.bottom + 4, left, width: w });
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
      <NavItem
        label="Genres"
        icon="local_offer"
        active={active}
        onClick={() => {
          if (genres.length === 0) {
            setOpen(false);
            onOpenGenresPage();
          } else {
            setOpen((o) => !o);
          }
        }}
      />
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
              maxHeight: Math.min(420, window.innerHeight - pos.top - 16),
              overflowY: 'auto',
              zIndex: 800,
              background: KatanaColors.surface,
              borderRadius: 8,
              border: `1px solid ${KatanaColors.border}`,
              boxShadow: boxShadow([{ color: '#00000044', blur: 16, offset: [0, 6] }]),
              padding: '6px 0',
              boxSizing: 'border-box',
            }}
          >
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                setOpen(false);
                onOpenGenresPage();
              }}
              style={{
                width: '100%',
                padding: '7px 14px',
                display: 'flex',
                alignItems: 'center',
                borderBottom: `1px solid ${KatanaColors.border}`,
              }}
            >
              <span style={{ ...outfit(12.5, 700, KatanaColors.accentSoft), flex: 1 }}>Browse all genres</span>
              <Icon name="grid_view" size={14} color={KatanaColors.accentSoft} />
            </button>
            {genres.map((genre) => (
              <button
                key={genre.slug}
                type="button"
                className="bare-button"
                onClick={() => {
                  setOpen(false);
                  onSelectGenre(genre);
                }}
                style={{ width: '100%', padding: '7px 14px', display: 'flex', alignItems: 'center' }}
              >
                <span style={{ ...outfit(13, 500, KatanaColors.text), flex: 1 }}>{genre.name}</span>
                {genre.count > 0 && <span style={KatanaType.small}>({genre.count})</span>}
              </button>
            ))}
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
  showBack,
  genres,
  onBack,
  onSelectNav,
  onSubmitSearch,
  onSelectManga,
  onSelectGenre,
}: {
  active: KatanaNavKey;
  width: number;
  userName: string;
  showBack: boolean;
  genres: KatanaGenre[];
  onBack: () => void;
  onSelectNav: (nav: KatanaNavKey) => void;
  onSubmitSearch: (q: string, searchBy: 'm_name' | 'author') => void;
  onSelectManga: (slug: string) => void;
  onSelectGenre: (genre: KatanaGenre) => void;
}) {
  const [queryText, setQueryText] = useState('');
  const [searchBy, setSearchBy] = useState<'m_name' | 'author'>('m_name');
  const [suggestions, setSuggestions] = useState<KatanaManga[]>([]);
  const [searching, setSearching] = useState(false);
  const [searched, setSearched] = useState(false);

  const desktop = width >= 900;
  const narrow = width < 500;
  const hasText = queryText !== '';
  const canSubmit = queryText.trim().length >= 3;

  useEffect(() => {
    const q = queryText.trim();
    if (q.length < 3) {
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
    }, 450);
    return () => window.clearTimeout(t);
  }, [queryText, searchBy]);

  const submit = () => {
    if (!canSubmit) return;
    setSuggestions([]);
    setSearched(false);
    onSubmitSearch(queryText.trim(), searchBy);
  };

  // IconButton(visualDensity: compact): a 40px slot around an 18px icon.
  const backButton = showBack && (
    <>
      <button
        type="button"
        className="bare-button"
        onClick={onBack}
        title="Back to Everglow"
        aria-label="Back to Everglow"
        style={{ width: 40, height: 40, flexShrink: 0, borderRadius: '50%', display: 'grid', placeItems: 'center' }}
      >
        <Icon name="arrow_back_ios_new" size={18} color={KatanaColors.accentSoft} />
      </button>
      <div style={{ width: 4, flexShrink: 0 }} />
    </>
  );

  const logoSize = narrow ? 30 : 34;
  const logoFont = narrow ? 19 : 22;
  const logo = (
    <button
      type="button"
      className="bare-button"
      onClick={() => onSelectNav('home')}
      style={{ display: 'flex', alignItems: 'center', minWidth: 0 }}
    >
      <div
        style={{
          width: logoSize,
          height: logoSize,
          flexShrink: 0,
          boxSizing: 'border-box',
          borderRadius: 10,
          background: linear([KatanaColors.accent, KatanaColors.accentDark], { begin: Align.topLeft, end: Align.bottomRight }),
          border: `1px solid ${withAlpha(KatanaColors.accentSoft, 0.5)}`,
          display: 'grid',
          placeItems: 'center',
        }}
      >
        <Icon name="auto_awesome" size={narrow ? 17 : 19} color={white} />
      </div>
      <div style={{ width: 9, flexShrink: 0 }} />
      <span style={{ ...outfit(logoFont, 600, KatanaColors.text, 1), whiteSpace: 'nowrap' }}>
        Manga<span style={{ color: KatanaColors.accent }}>Celestia</span>
      </span>
    </button>
  );

  const searchField = (
    <div
      style={{
        height: desktop ? 40 : 44,
        width: '100%',
        maxWidth: 620,
        boxSizing: 'border-box',
        borderRadius: 99,
        background: KatanaColors.background,
        border: `1px solid ${hasText ? KatanaColors.borderStrong : KatanaColors.border}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <div style={{ width: 14, flexShrink: 0 }} />
      <Icon name="search" size={18} color={hasText ? KatanaColors.accent : KatanaColors.textLight} />
      <div style={{ width: 8, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center' }}>
        {/* The M3 field text is bodyLarge: height 1.5, letterSpacing 0.5. */}
        <div style={{ position: 'relative', flex: 1, minWidth: 0, height: 20 }}>
          <input
            value={queryText}
            onChange={(e) => setQueryText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') submit();
            }}
            enterKeyHint="search"
            aria-label="Search manga, manhwa, manhua..."
            style={{
              position: 'absolute',
              inset: 0,
              width: '100%',
              padding: 0,
              margin: 0,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              ...outfit(13.5, 500, KatanaColors.text, 1.5),
              letterSpacing: 0.5,
              caretColor: KatanaColors.accent,
            }}
          />
          {!hasText && (
            <span
              aria-hidden
              style={{
                position: 'absolute',
                left: 0,
                right: 0,
                top: 0,
                pointerEvents: 'none',
                ...KatanaType.small,
                lineHeight: '20px',
                letterSpacing: 0.5,
                ...ellipsis,
              }}
            >
              Search manga, manhwa, manhua...
            </span>
          )}
        </div>
        {hasText && (
          <button
            type="button"
            className="bare-button"
            onClick={() => setQueryText('')}
            title="Clear"
            aria-label="Clear"
            style={{ width: 32, height: 32, flexShrink: 0, display: 'grid', placeItems: 'center' }}
          >
            <Icon name="clear" size={16} color={KatanaColors.textLight} />
          </button>
        )}
      </div>
      <button
        type="button"
        className="bare-button"
        onClick={() => setSearchBy((s) => (s === 'm_name' ? 'author' : 'm_name'))}
        style={{
          flexShrink: 0,
          marginRight: 4,
          padding: '6px 10px',
          borderRadius: 99,
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${KatanaColors.borderStrong}`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <span style={{ ...KatanaType.small, color: KatanaColors.accentSoft, fontWeight: 600, whiteSpace: 'nowrap' }}>
          {searchBy === 'm_name' ? (narrow ? 'Name' : 'Manga Name') : 'Author'}
        </span>
        <Icon name="arrow_drop_down" size={16} color={KatanaColors.accentSoft} />
      </button>
      <button
        type="button"
        className="bare-button"
        onClick={submit}
        title={canSubmit ? 'Search' : 'Type at least 3 letters'}
        aria-label="Search"
        style={{ width: 34, height: 34, flexShrink: 0, borderRadius: '50%', display: 'grid', placeItems: 'center' }}
      >
        <Icon name="arrow_forward" size={18} color={canSubmit ? KatanaColors.accent : KatanaColors.textLight} />
      </button>
      <div style={{ width: 4, flexShrink: 0 }} />
    </div>
  );

  const bookmarksButton = (
    <button
      type="button"
      className="bare-button"
      onClick={() => onSelectNav('bookmarks')}
      style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}
    >
      <Icon name="bookmark" size={18} color={KatanaColors.accent} />
      <div style={{ width: 4 }} />
      <span style={KatanaType.accent}>Bookmarks</span>
    </button>
  );

  const userChip = (
    <div
      style={{
        padding: '6px 10px',
        borderRadius: 6,
        background: KatanaColors.surfaceAlt,
        border: `1px solid ${KatanaColors.border}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name="person" size={16} color={KatanaColors.textMuted} />
      <div style={{ width: 6 }} />
      <span style={outfit(12.5, 600, KatanaColors.text)}>{userName || 'Guest'}</span>
    </div>
  );

  const nav = (key: KatanaNavKey, label: string, icon: string) => (
    <NavItem key={key} label={label} icon={icon} active={active === key} onClick={() => onSelectNav(key)} />
  );

  return (
    <header style={{ background: KatanaColors.headerDark, borderBottom: `1px solid ${KatanaColors.borderStrong}`, flexShrink: 0 }}>
      {desktop ? (
        <div style={{ padding: '10px 16px', display: 'flex', alignItems: 'center' }}>
          {backButton}
          {logo}
          {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
          <div style={{ width: 16, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0, display: 'flex', justifyContent: 'center' }}>{searchField}</div>
          <div style={{ width: 16, flexShrink: 0 }} />
          <div style={{ width: 210, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
            {showBack && bookmarksButton}
            <div style={{ width: 8 }} />
            {userChip}
          </div>
        </div>
      ) : (
        <div style={{ padding: '10px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            {backButton}
            {logo}
            <div style={{ flex: 1 }} />
            {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
            {showBack && bookmarksButton}
          </div>
          <div style={{ height: 10 }} />
          {searchField}
        </div>
      )}

      {queryText.trim().length >= 3 && (searching || searched) && (
        <div style={{ padding: '0 16px 10px' }}>
          <KatanaCard radius={8} style={{ overflow: 'hidden' }}>
            {searching ? (
              <div style={{ padding: 16, display: 'flex', alignItems: 'center' }}>
                <div className="spin" style={{ width: 16, height: 16, borderRadius: '50%', border: `2px solid ${KatanaColors.accent}`, borderRightColor: 'transparent', boxSizing: 'border-box' }} />
                <div style={{ width: 12 }} />
                <span style={KatanaType.small}>Searching...</span>
              </div>
            ) : suggestions.length === 0 ? (
              <div style={{ padding: 16, ...KatanaType.small }}>No matches found.</div>
            ) : (
              <div>
                {suggestions.map((it) => (
                  <button
                    key={it.slug}
                    type="button"
                    className="bare-button"
                    onClick={() => {
                      setQueryText('');
                      setSuggestions([]);
                      setSearched(false);
                      onSelectManga(it.slug);
                    }}
                    style={{ width: '100%', display: 'flex', alignItems: 'center', padding: '8px 12px' }}
                  >
                    <div style={{ position: 'relative', width: 38, height: 50, borderRadius: 4, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                      <KatanaCoverImage url={it.coverUrl} iconSize={16} />
                    </div>
                    <div style={{ width: 10, flexShrink: 0 }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ ...outfit(13, 600, KatanaColors.text), ...ellipsis }}>{it.title}</div>
                      {it.latestChapter && (
                        <div style={{ ...KatanaType.small, ...ellipsis }}>Latest chapter: {chapterDisplayTitle(it.latestChapter)}</div>
                      )}
                    </div>
                  </button>
                ))}
                <div style={{ height: 1, background: KatanaColors.border }} />
                <button
                  type="button"
                  className="bare-button"
                  onClick={submit}
                  style={{ width: '100%', padding: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  <Icon name="search" size={15} color={KatanaColors.accent} variant="filled" />
                  <div style={{ width: 6 }} />
                  <span style={KatanaType.accent}>View all results</span>
                </button>
              </div>
            )}
          </KatanaCard>
        </div>
      )}

      <div style={{ background: KatanaColors.surface, boxShadow: `inset 0 0.8px 0 ${KatanaColors.border}`, paddingTop: 0.8 }}>
        <div className="no-scrollbar" style={{ overflowX: 'auto', padding: '4px 12px', display: 'flex', alignItems: 'flex-start' }}>
          {nav('home', 'Home', 'home')}
          {nav('latest', 'Latest update', 'bolt')}
          {nav('directory', 'Manga Directory', 'grid_view')}
          {nav('newManga', 'New Manga', 'auto_awesome')}
          <GenresDropdown
            genres={genres}
            active={active === 'genres'}
            onSelectGenre={onSelectGenre}
            onOpenGenresPage={() => onSelectNav('genres')}
          />
          {showBack && nav('reading', 'Currently Reading', 'auto_stories')}
          {nav('downloads', 'Downloads', 'download_done')}
          {!desktop && showBack && (
            <>
              <div style={{ width: 4, flexShrink: 0 }} />
              <NavItem label="Bookmarks" icon="bookmark" active={false} onClick={() => onSelectNav('bookmarks')} />
            </>
          )}
        </div>
      </div>
    </header>
  );
}

// katana_item_card.dart ------------------------------------------------------

export function KatanaCoverImage({ url, emptyIcon = 'menu_book', errorIcon = 'broken_image', iconSize = 32, fill = KatanaColors.surfaceAlt }: { url: string; emptyIcon?: string; errorIcon?: string; iconSize?: number; fill?: string }) {
  const [step, setStep] = useState(0);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setStep(0);
    setFailed(false);
  }, [url]);

  const resolved = url ? proxyKatanaImageUrl(katanaCdnFallback(url, step)) : '';
  if (!resolved || failed) {
    return (
      <div style={{ position: 'absolute', inset: 0, background: fill, display: 'grid', placeItems: 'center' }}>
        <Icon name={url ? errorIcon : emptyIcon} size={iconSize} color={KatanaColors.textLight} />
      </div>
    );
  }
  return (
    <img
      src={resolved}
      alt=""
      loading="lazy"
      onError={() => {
        if (step < 4) setStep((s) => s + 1);
        else setFailed(true);
      }}
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
    />
  );
}

export function KatanaBreadcrumb({ items, onHome }: { items: string[]; onHome: () => void }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
      <button type="button" className="bare-button" onClick={onHome} style={{ display: 'inline-flex', alignItems: 'center' }}>
        <Icon name="home" size={14} color={KatanaColors.textMuted} />
      </button>
      {items.map((label, i) => (
        <span key={`${label}-${i}`} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <Icon name="chevron_right" size={13} color={KatanaColors.textLight} />
          <span style={outfit(12.5, i === items.length - 1 ? 600 : 500, i === items.length - 1 ? KatanaColors.text : KatanaColors.textMuted)}>
            {label}
          </span>
        </span>
      ))}
    </div>
  );
}

const CoverImage = KatanaCoverImage;

function ItemCover({ url, width, height, status }: { url: string; width: number; height: number; status: string }) {
  const completed = status === 'completed';
  return (
    <div style={{ border: `1px solid ${KatanaColors.borderStrong}`, borderRadius: 8, flexShrink: 0 }}>
      <div style={{ position: 'relative', width, height, borderRadius: 7, overflow: 'hidden' }}>
        <CoverImage url={url} emptyIcon="menu_book" errorIcon="broken_image" iconSize={url ? 26 : 28} fill={KatanaColors.surfaceAlt} />
        <div
          style={{
            position: 'absolute',
            left: 0,
            top: 0,
            padding: '3px 7px',
            background: completed ? KatanaColors.green : KatanaColors.accent,
            borderBottomRightRadius: 6,
            ...outfit(9, 600, white),
            whiteSpace: 'nowrap',
          }}
        >
          {completed ? 'Completed' : 'Ongoing'}
        </div>
      </div>
    </div>
  );
}

export function KatanaItemCard({
  manga,
  compact,
  dense = false,
  onSelectManga,
  onSelectGenre,
  onOpenChapter,
}: {
  manga: KatanaManga;
  compact: boolean;
  dense?: boolean;
  onSelectManga: (slug: string) => void;
  onSelectGenre?: (g: KatanaGenre) => void;
  onOpenChapter?: (manga: KatanaManga, chapterId: string) => void;
}) {
  const viewport = useViewport();
  const [hovered, setHovered] = useState(false);
  const interactive = !reduceAmbientMotion(viewport);
  const lit = interactive && hovered;
  const small = dense || compact;
  const genres = compact ? manga.genres.slice(0, 3) : manga.genres;
  const chapters = manga.recentChapters.slice(0, compact ? 2 : 3);
  const stop = (fn: () => void) => (e: { stopPropagation: () => void }) => {
    e.stopPropagation();
    fn();
  };

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onSelectManga(manga.slug)}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') onSelectManga(manga.slug);
      }}
      style={{
        background: KatanaColors.surface,
        borderRadius: 12,
        border: `2px solid ${lit ? withAlpha(KatanaColors.accent, 0.72) : KatanaColors.border}`,
        boxShadow: !interactive
          ? undefined
          : lit
            ? boxShadow([{ color: withAlpha(KatanaColors.accent, 0.25), blur: 20, offset: [0, 8] }])
            : boxShadow([{ color: scrimStrong, blur: 18, offset: [0, 6] }]),
        transform: lit ? 'translateY(-2px)' : undefined,
        transition: interactive ? 'border-color 180ms ease, box-shadow 180ms ease, transform 180ms ease' : undefined,
        padding: 11,
        display: 'flex',
        alignItems: 'flex-start',
        cursor: 'pointer',
        outline: 'none',
      }}
    >
      <ItemCover url={manga.coverUrl} width={small ? 80 : 106} height={small ? 114 : 152} status={manga.status} />
      <div style={{ width: 12, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="clamp-2" style={outfit(15, 600, KatanaColors.text, 1.3)}>
          {manga.latestChapter ? `${manga.title} - Update ${chapterDisplayTitle(manga.latestChapter)}` : manga.title}
        </div>
        <div style={{ height: 6 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 14, rowGap: 4, alignItems: 'flex-start' }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <Icon name="schedule" size={13} color={KatanaColors.textLight} />
            <div style={{ width: 4 }} />
            <span style={KatanaType.small}>{manga.updateText || 'recently'}</span>
          </div>
          {manga.latestChapter && (
            <div onClick={stop(() => onOpenChapter?.(manga, 'fc'))} style={{ display: 'flex', alignItems: 'center' }}>
              <Icon name="double_arrow" size={13} color={KatanaColors.link} />
              <div style={{ width: 4 }} />
              <span style={KatanaType.link}>First Chapter</span>
            </div>
          )}
        </div>
        {genres.length > 0 && (
          <>
            <div style={{ height: 7 }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 6, rowGap: 5 }}>
              {genres.map((g) => (
                <div
                  key={g.slug}
                  onClick={stop(() => onSelectGenre?.(g))}
                  style={{
                    padding: '3px 9px',
                    borderRadius: 99,
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${withAlpha(KatanaColors.link, 0.35)}`,
                    ...outfit(10.5, 600, KatanaColors.link),
                    whiteSpace: 'nowrap',
                  }}
                >
                  {g.name}
                </div>
              ))}
            </div>
          </>
        )}
        {!compact && manga.summary && !dense && (
          <>
            <div style={{ height: 8 }} />
            <div className="clamp-2" style={{ ...KatanaType.small, color: KatanaColors.textMuted, fontSize: 12.5, lineHeight: lineHeight(12.5) }}>
              {manga.summary}
            </div>
          </>
        )}
        {chapters.length > 0 ? (
          <>
            <div style={{ height: 8 }} />
            {chapters.map((ch, i) => {
              const first = i === 0;
              return (
                <div key={ch.id} style={{ paddingBottom: 4 }}>
                  <div
                    onClick={stop(() => onOpenChapter?.(manga, ch.id))}
                    style={{
                      padding: '4.5px 9px',
                      borderRadius: 7,
                      background: first ? withAlpha(KatanaColors.accent, 0.12) : KatanaColors.surfaceAlt,
                      border: `1px solid ${first ? withAlpha(KatanaColors.accent, 0.45) : KatanaColors.border}`,
                      display: 'flex',
                      alignItems: 'center',
                    }}
                  >
                    <Icon name={first ? 'bolt' : 'menu_book'} size={13} color={first ? KatanaColors.accent : KatanaColors.accentSoft} />
                    <div style={{ width: 5, flexShrink: 0 }} />
                    <span style={{ ...outfit(12, 700, first ? KatanaColors.text : KatanaColors.accentSoft), ...ellipsis, flex: 1, minWidth: 0 }}>
                      {chapterDisplayTitle(ch)}
                    </span>
                    {ch.updateAt && (
                      <>
                        <div style={{ width: 8, flexShrink: 0 }} />
                        <span style={{ ...KatanaType.small, fontSize: 10.5, lineHeight: lineHeight(10.5), whiteSpace: 'nowrap' }}>
                          {formatKatanaTime(ch.updateAt)}
                        </span>
                      </>
                    )}
                  </div>
                </div>
              );
            })}
          </>
        ) : manga.latestChapter ? (
          <>
            <div style={{ height: 6 }} />
            <div style={{ ...KatanaType.accent, ...ellipsis }}>Latest: {chapterDisplayTitle(manga.latestChapter)}</div>
          </>
        ) : null}
      </div>
    </div>
  );
}

export function KatanaCompactCard({
  manga,
  width,
  onSelect,
  onOpenChapter,
}: {
  manga: KatanaManga;
  width: number;
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
      onClick={onSelect}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{ width, flexShrink: 0, cursor: 'pointer', display: 'flex', flexDirection: 'column' }}
    >
      <div
        style={{
          borderRadius: 8,
          padding: interactive ? 2.5 : 0,
          border: interactive ? `2px solid ${lit ? KatanaColors.accent : 'transparent'}` : undefined,
          boxShadow: lit ? boxShadow([{ color: withAlpha(KatanaColors.accent, 0.45), blur: 14 }]) : undefined,
          transform: lit ? 'translateY(-2px)' : undefined,
          transition: interactive ? 'border-color 180ms ease, box-shadow 180ms ease, transform 180ms ease' : undefined,
          alignSelf: 'flex-start',
        }}
      >
        <div style={{ position: 'relative', width, height: width * 1.42, borderRadius: 6, overflow: 'hidden' }}>
          <CoverImage url={manga.coverUrl} emptyIcon="menu_book" errorIcon="broken_image" iconSize={24} fill={KatanaColors.border} />
        </div>
      </div>
      <div style={{ height: 7 }} />
      <div className="clamp-2" style={outfit(12.5, 600, lit ? KatanaColors.accent : KatanaColors.text, 1.25)}>
        {manga.title}
      </div>
      <div style={{ height: 3 }} />
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <div style={{ width: 7, height: 7, borderRadius: '50%', flexShrink: 0, background: completed ? KatanaColors.green : KatanaColors.accent }} />
        <div style={{ width: 5, flexShrink: 0 }} />
        <span style={{ ...KatanaType.small, fontSize: 11, lineHeight: lineHeight(11), flex: 1, minWidth: 0 }}>
          {completed ? 'Completed' : 'Ongoing'}
        </span>
      </div>
      {manga.latestChapter && (
        <div
          onClick={(e) => {
            e.stopPropagation();
            onOpenChapter?.(manga, manga.latestChapter!.id);
          }}
          style={{ ...KatanaType.accent, fontSize: 11.5, lineHeight: lineHeight(11.5), ...ellipsis }}
        >
          {chapterDisplayTitle(manga.latestChapter)}
        </div>
      )}
    </div>
  );
}

export function KatanaPagination({
  page,
  hasPrev,
  hasNext,
  onPageChange,
}: {
  page: number;
  hasPrev: boolean;
  hasNext: boolean;
  onPageChange: (next: number) => void;
}) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 12 }}>
      <KatanaButton label="Previous" icon="chevron_left" filled={false} onClick={() => hasPrev && onPageChange(page - 1)} />
      <span style={KatanaType.small}>Page {page}</span>
      <KatanaButton label="Next" icon="chevron_right" filled={false} onClick={() => hasNext && onPageChange(page + 1)} />
    </div>
  );
}
