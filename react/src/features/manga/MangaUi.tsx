import { useEffect, useState, type CSSProperties, type ReactNode } from 'react';
import { Align, boxShadow, linear } from '../../core/theme/paint';
import { Icon } from '../../shared/widgets/Icon';
import { MediaSectionMenuButton } from '../cinema/NetflixUi';
import {
  chapterDisplayTitle,
  fetchKatanaSuggestions,
  type KatanaGenre,
  type KatanaManga,
} from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';

export type KatanaNavKey = 'home' | 'latest' | 'directory' | 'newManga' | 'genres' | 'reading' | 'downloads' | 'bookmarks';

export function KatanaCard({
  children,
  style,
  padding = 0,
}: {
  children: ReactNode;
  style?: CSSProperties;
  padding?: number | string;
}) {
  return (
    <div
      style={{
        background: KatanaColors.surface,
        borderRadius: 12,
        border: `1px solid ${KatanaColors.border}`,
        boxShadow: boxShadow([{ color: 'rgba(0,0,0,0.40)', blur: 18, offset: [0, 6] }]),
        padding,
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
}: {
  title: string;
  badge?: string;
  trailing?: ReactNode;
}) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div
        style={{
          width: 4,
          height: 20,
          borderRadius: 4,
          background: linear([KatanaColors.accent, KatanaColors.accentSoft], {
            begin: Align.topCenter,
            end: Align.bottomCenter,
          }),
          flexShrink: 0,
        }}
      />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 8 }}>
        <span
          style={{
            ...KatanaType.section,
            fontSize: 18,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {title}
        </span>
        {badge && (
          <span
            style={{
              padding: '2px 8px',
              borderRadius: 99,
              background: 'rgba(255, 46, 126, 0.14)',
              border: '1px solid rgba(255, 46, 126, 0.40)',
              color: KatanaColors.accentSoft,
              fontSize: 10,
              fontWeight: 700,
              letterSpacing: 0.8,
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
}: {
  label: string;
  icon?: string;
  onClick?: () => void;
  filled?: boolean;
  color?: string;
}) {
  const isPink = color === KatanaColors.accent && filled;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '9px 16px',
        borderRadius: 99,
        background: isPink
          ? linear([KatanaColors.accent, KatanaColors.accentDark], { begin: Align.topLeft, end: Align.bottomRight })
          : filled
            ? color
            : 'rgba(255, 46, 126, 0.08)',
        border: `1px solid ${filled ? color : 'rgba(255, 46, 126, 0.55)'}`,
      }}
    >
      {icon && <Icon name={icon} size={15} color={filled ? '#FFFFFF' : color} />}
      <span style={{ ...KatanaType.title, fontSize: 13, color: filled ? '#FFFFFF' : color }}>{label}</span>
    </button>
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
  const [genresOpen, setGenresOpen] = useState(false);

  const desktop = width >= 900;
  const narrow = width < 500;

  useEffect(() => {
    const q = queryText.trim();
    if (q.length < 3) {
      setSuggestions([]);
      setSearching(false);
      setSearched(false);
      return;
    }
    setSearching(true);
    const t = window.setTimeout(async () => {
      const res = await fetchKatanaSuggestions(q, searchBy);
      setSuggestions(res);
      setSearching(false);
      setSearched(true);
    }, 450);
    return () => window.clearTimeout(t);
  }, [queryText, searchBy]);

  const logo = (
    <button
      type="button"
      className="bare-button"
      onClick={() => onSelectNav('home')}
      style={{ display: 'inline-flex', alignItems: 'center', gap: 9, flexShrink: 0 }}
    >
      <div
        style={{
          width: narrow ? 30 : 34,
          height: narrow ? 30 : 34,
          borderRadius: 10,
          background: linear([KatanaColors.accent, KatanaColors.accentDark], { begin: Align.topLeft, end: Align.bottomRight }),
          border: '1px solid rgba(255, 133, 179, 0.5)',
          display: 'grid',
          placeItems: 'center',
        }}
      >
        <Icon name="auto_awesome" size={narrow ? 17 : 19} color="#FFFFFF" />
      </div>
      <span style={{ fontSize: narrow ? 19 : 22, fontWeight: 700, lineHeight: 1 }}>
        <span style={{ color: KatanaColors.text }}>Manga</span>
        <span style={{ color: KatanaColors.accent }}>Celestia</span>
      </span>
    </button>
  );

  const searchField = (
    <div
      style={{
        height: desktop ? 40 : 44,
        width: '100%',
        maxWidth: 620,
        borderRadius: 99,
        background: KatanaColors.background,
        border: `1px solid ${queryText ? KatanaColors.borderStrong : KatanaColors.border}`,
        display: 'flex',
        alignItems: 'center',
        padding: '0 4px 0 14px',
        gap: 8,
      }}
    >
      <Icon name="search" size={18} color={queryText ? KatanaColors.accent : KatanaColors.textLight} />
      <input
        value={queryText}
        onChange={(e) => setQueryText(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === 'Enter' && queryText.trim().length >= 3) {
            onSubmitSearch(queryText.trim(), searchBy);
            setSuggestions([]);
            setSearched(false);
          }
        }}
        placeholder="Search manga, manhwa, manhua..."
        style={{
          flex: 1,
          minWidth: 0,
          background: 'transparent',
          border: 'none',
          outline: 'none',
          color: KatanaColors.text,
          fontSize: 13.5,
        }}
      />
      {queryText && (
        <button type="button" className="bare-button" onClick={() => setQueryText('')} style={{ padding: 4 }}>
          <Icon name="close" size={16} color={KatanaColors.textLight} />
        </button>
      )}
      <button
        type="button"
        className="bare-button"
        onClick={() => setSearchBy((s) => (s === 'm_name' ? 'author' : 'm_name'))}
        style={{
          padding: '6px 10px',
          borderRadius: 99,
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${KatanaColors.borderStrong}`,
          color: KatanaColors.accentSoft,
          fontSize: 12,
          fontWeight: 600,
          flexShrink: 0,
        }}
      >
        {searchBy === 'm_name' ? (narrow ? 'Name' : 'Manga Name') : 'Author'} ▾
      </button>
      <button
        type="button"
        className="bare-button"
        onClick={() => {
          if (queryText.trim().length >= 3) {
            onSubmitSearch(queryText.trim(), searchBy);
            setSuggestions([]);
            setSearched(false);
          }
        }}
        style={{ padding: '6px 10px 6px 4px', display: 'grid', placeItems: 'center', flexShrink: 0 }}
      >
        <Icon name="arrow_forward" size={17} color={KatanaColors.textMuted} />
      </button>
    </div>
  );

  const bookmarksBtn = (
    <button
      type="button"
      className="bare-button"
      onClick={() => onSelectNav('bookmarks')}
      style={{ display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0 }}
    >
      <Icon name="bookmark" size={18} color={KatanaColors.accent} />
      <span style={KatanaType.accent}>Bookmarks</span>
    </button>
  );

  const navItems: { key: KatanaNavKey; label: string; icon: string }[] = [
    { key: 'home', label: 'Home', icon: 'home' },
    { key: 'latest', label: 'Latest update', icon: 'bolt' },
    { key: 'directory', label: 'Manga Directory', icon: 'grid_view' },
    { key: 'newManga', label: 'New Manga', icon: 'auto_awesome' },
    { key: 'genres', label: 'Genres', icon: 'local_offer' },
    ...(showBack ? [{ key: 'reading' as KatanaNavKey, label: 'Currently Reading', icon: 'auto_stories' }] : []),
    { key: 'downloads', label: 'Downloads', icon: 'download_done' },
  ];

  return (
    <header style={{ background: KatanaColors.headerDark, borderBottom: `1px solid ${KatanaColors.borderStrong}`, flexShrink: 0 }}>
      {desktop ? (
        <div style={{ display: 'flex', alignItems: 'center', padding: '10px 16px', gap: 8 }}>
          {showBack && (
            <button type="button" className="bare-button" onClick={onBack} style={{ padding: 6 }} title="Back to Everglow">
              <Icon name="arrow_back_ios_new" size={18} color={KatanaColors.accentSoft} />
            </button>
          )}
          {logo}
          {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
          <div style={{ flex: 1, display: 'flex', justifyContent: 'center', padding: '0 16px' }}>{searchField}</div>
          <div style={{ width: 210, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 8 }}>
            {showBack && bookmarksBtn}
            <div
              style={{
                padding: '6px 10px',
                borderRadius: 6,
                background: KatanaColors.surfaceAlt,
                border: `1px solid ${KatanaColors.border}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <Icon name="person" size={16} color={KatanaColors.textMuted} />
              <span style={{ ...KatanaType.title, fontSize: 12.5 }}>{userName || 'Guest'}</span>
            </div>
          </div>
        </div>
      ) : (
        <div style={{ padding: '10px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            {showBack && (
              <button type="button" className="bare-button" onClick={onBack} style={{ padding: 6, marginRight: 4 }}>
                <Icon name="arrow_back_ios_new" size={18} color={KatanaColors.accentSoft} />
              </button>
            )}
            {logo}
            <div style={{ flex: 1 }} />
            {!showBack && <MediaSectionMenuButton currentRoute="/manga" />}
            {showBack && bookmarksBtn}
          </div>
          <div style={{ height: 10 }} />
          {searchField}
        </div>
      )}

      {queryText.trim().length >= 3 && (searching || searched) && (
        <div style={{ padding: '0 16px 10px' }}>
          <KatanaCard style={{ maxWidth: 620, margin: '0 auto', overflow: 'hidden' }}>
            {searching ? (
              <div style={{ padding: 16, ...KatanaType.small }}>Searching…</div>
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
                      onSelectManga(it.slug);
                    }}
                    style={{
                      width: '100%',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 10,
                      padding: '8px 12px',
                      textAlign: 'left',
                    }}
                  >
                    {it.coverUrl && (
                      <img src={it.coverUrl} alt={it.title} style={{ width: 38, height: 50, borderRadius: 4, objectFit: 'cover' }} />
                    )}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ ...KatanaType.title, fontSize: 13 }}>{it.title}</div>
                      {it.latestChapter && (
                        <div style={KatanaType.small}>Latest chapter: {chapterDisplayTitle(it.latestChapter)}</div>
                      )}
                    </div>
                  </button>
                ))}
              </div>
            )}
          </KatanaCard>
        </div>
      )}

      <div
        className="no-scrollbar"
        style={{
          background: KatanaColors.surface,
          borderTop: `0.8px solid ${KatanaColors.border}`,
          padding: '4px 12px',
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          overflowX: 'auto',
          whiteSpace: 'nowrap',
          position: 'relative',
        }}
      >
        {navItems.map((it) => {
          const isOn = active === it.key;
          return (
            <button
              key={it.key}
              type="button"
              className="bare-button"
              onClick={() => {
                if (it.key === 'genres') setGenresOpen((o) => !o);
                else {
                  setGenresOpen(false);
                  onSelectNav(it.key);
                }
              }}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                padding: '7px 12px',
                borderRadius: 99,
                flexShrink: 0,
                background: isOn ? 'rgba(255, 46, 126, 0.16)' : 'transparent',
                border: `1px solid ${isOn ? 'rgba(255, 46, 126, 0.45)' : 'transparent'}`,
              }}
            >
              <Icon name={it.icon} size={15} color={isOn ? KatanaColors.accent : KatanaColors.textLight} />
              <span style={{ ...KatanaType.small, color: isOn ? KatanaColors.text : KatanaColors.textMuted, fontWeight: isOn ? 700 : 500 }}>
                {it.label}
              </span>
            </button>
          );
        })}
        {!desktop && showBack && (
          <button
            type="button"
            className="bare-button"
            onClick={() => onSelectNav('bookmarks')}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              padding: '7px 12px',
              borderRadius: 99,
              flexShrink: 0,
              background: active === 'bookmarks' ? 'rgba(255, 46, 126, 0.16)' : 'transparent',
            }}
          >
            <Icon name="bookmark" size={15} color={KatanaColors.accent} />
            <span style={{ ...KatanaType.small, color: KatanaColors.textMuted }}>Bookmarks</span>
          </button>
        )}
      </div>

      {genresOpen && (
        <div
          style={{
            background: KatanaColors.surfaceAlt,
            borderTop: `1px solid ${KatanaColors.border}`,
            padding: '10px 16px',
            display: 'flex',
            flexWrap: 'wrap',
            gap: 8,
          }}
        >
          {(genres.length
            ? genres
            : [
                { slug: 'action', name: 'Action', count: 0, description: '' },
                { slug: 'romance', name: 'Romance', count: 0, description: '' },
                { slug: 'fantasy', name: 'Fantasy', count: 0, description: '' },
                { slug: 'comedy', name: 'Comedy', count: 0, description: '' },
                { slug: 'drama', name: 'Drama', count: 0, description: '' },
                { slug: 'manhwa', name: 'Manhwa', count: 0, description: '' },
                { slug: 'manhua', name: 'Manhua', count: 0, description: '' },
                { slug: 'isekai', name: 'Isekai', count: 0, description: '' },
              ]
          ).map((g) => (
            <button
              key={g.slug}
              type="button"
              className="bare-button"
              onClick={() => {
                setGenresOpen(false);
                onSelectGenre(g);
              }}
              style={{
                padding: '5px 10px',
                borderRadius: 6,
                background: KatanaColors.surface,
                border: `1px solid ${KatanaColors.border}`,
                color: KatanaColors.text,
                fontSize: 12,
              }}
            >
              {g.name}
            </button>
          ))}
        </div>
      )}
    </header>
  );
}

export function KatanaItemCard({
  manga,
  compact,
  onSelectManga,
  onSelectGenre,
}: {
  manga: KatanaManga;
  compact: boolean;
  onSelectManga: (slug: string) => void;
  onSelectGenre?: (g: KatanaGenre) => void;
}) {
  const coverW = compact ? 80 : 106;
  const coverH = compact ? 114 : 152;
  const genresShown = compact ? manga.genres.slice(0, 3) : manga.genres;

  return (
    <KatanaCard padding={11} style={{ borderWidth: 2 }}>
      <div onClick={() => onSelectManga(manga.slug)} style={{ display: 'flex', gap: 12, cursor: 'pointer', alignItems: 'flex-start' }}>
        <div
          style={{
            width: coverW,
            height: coverH,
            borderRadius: 8,
            overflow: 'hidden',
            background: KatanaColors.surfaceAlt,
            position: 'relative',
            flexShrink: 0,
          }}
        >
          {manga.coverUrl && (
            <img src={manga.coverUrl} alt={manga.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          )}
          <span
            style={{
              position: 'absolute',
              left: 6,
              top: 6,
              padding: '2px 7px',
              borderRadius: 6,
              background: manga.status === 'completed' ? 'rgba(34,197,94,0.88)' : 'rgba(255, 46, 126, 0.90)',
              color: '#FFF',
              fontSize: 10,
              fontWeight: 700,
              textTransform: 'capitalize',
            }}
          >
            {manga.status}
          </span>
        </div>

        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="clamp-2" style={{ ...KatanaType.title, fontSize: 15, lineHeight: 1.3 }}>
            {manga.latestChapter
              ? `${manga.title} - Update ${chapterDisplayTitle(manga.latestChapter)}`
              : manga.title}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 14, marginTop: 6 }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <Icon name="schedule" size={13} color={KatanaColors.textLight} />
              <span style={KatanaType.small}>{manga.updateText || 'recently'}</span>
            </span>
            {manga.latestChapter && (
              <span style={{ ...KatanaType.link, fontSize: 12.5 }}>
                » {chapterDisplayTitle(manga.latestChapter)}
              </span>
            )}
          </div>
          {genresShown.length > 0 && (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5, marginTop: 7 }}>
              {genresShown.map((g) => (
                <button
                  key={g.slug}
                  type="button"
                  className="bare-button"
                  onClick={(e) => {
                    e.stopPropagation();
                    onSelectGenre?.(g);
                  }}
                  style={{
                    padding: '2px 7px',
                    borderRadius: 4,
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${KatanaColors.border}`,
                    color: KatanaColors.textMuted,
                    fontSize: 11,
                  }}
                >
                  {g.name}
                </button>
              ))}
            </div>
          )}
          {!compact && manga.summary && (
            <div className="clamp-2" style={{ ...KatanaType.small, color: KatanaColors.textMuted, fontSize: 12.5, marginTop: 8 }}>
              {manga.summary}
            </div>
          )}
          {manga.recentChapters.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 5, marginTop: 8 }}>
              {manga.recentChapters.slice(0, compact ? 2 : 3).map((ch, idx) => (
                <div
                  key={ch.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    padding: '6px 10px',
                    borderRadius: 8,
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${idx === 0 ? KatanaColors.borderStrong : KatanaColors.border}`,
                  }}
                >
                  <Icon
                    name={idx === 0 ? 'bolt' : 'menu_book'}
                    size={13}
                    color={idx === 0 ? KatanaColors.accent : KatanaColors.accentSoft}
                  />
                  <span
                    style={{
                      ...KatanaType.title,
                      fontSize: 12.5,
                      flex: 1,
                      minWidth: 0,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {chapterDisplayTitle(ch)}
                  </span>
                </div>
              ))}
            </div>
          ) : manga.latestChapter ? (
            <div style={{ ...KatanaType.accent, marginTop: 6, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              Latest: {chapterDisplayTitle(manga.latestChapter)}
            </div>
          ) : null}
        </div>
      </div>
    </KatanaCard>
  );
}

export function KatanaCompactCard({
  manga,
  width,
  onSelect,
}: {
  manga: KatanaManga;
  width: number;
  onSelect: () => void;
}) {
  return (
    <div onClick={onSelect} style={{ width, flexShrink: 0, cursor: 'pointer' }}>
      <div
        style={{
          width,
          height: width * 1.45,
          borderRadius: 8,
          overflow: 'hidden',
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${KatanaColors.border}`,
        }}
      >
        {manga.coverUrl && <img src={manga.coverUrl} alt={manga.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
      </div>
      <div className="clamp-2" style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 600, marginTop: 6 }}>
        {manga.title}
      </div>
      {manga.latestChapter && (
        <div style={{ ...KatanaType.small, color: KatanaColors.accentSoft, fontSize: 11, marginTop: 2 }}>
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
