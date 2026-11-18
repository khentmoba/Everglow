import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { ShelfAtmosphericBackdrop, ShelfIconButton } from '../../shared/widgets/shelf/Shelf';
import {
  BOOK_CATEGORIES,
  BookColors,
  buildReadCandidates,
  isBookRead,
  searchResultToBookItem,
  type BookCategory,
  type BookItem,
  type BookSearchResult,
} from './bookTypes';
import {
  addToOurBooks,
  fetchBookDetails,
  fetchBooksBySubject,
  fetchBookText,
  fetchPopularBooks,
  fetchRecentBooks,
  saveToReadList,
  toggleBookFavorite,
  watchBookFavorites,
  watchReadList,
} from './booksService';
import { BookCover, BookCoverCard } from './BookCover';

export function BookDetailPage() {
  const { currentUser, isCoupleUser } = useAuth();
  const { width } = useViewport();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { result?: BookSearchResult; saved?: BookItem } | null) ?? null;

  const [result, setResult] = useState<BookSearchResult | null>(state?.result ?? null);
  const [similar, setSimilar] = useState<BookSearchResult[]>([]);
  const userName = currentUser ?? '';
  const readlist = useSource(() => watchReadList(userName), [userName], []);
  const favorites = useSource(() => watchBookFavorites(userName), [userName], []);

  useEffect(() => {
    if (!state?.result) return;
    let alive = true;
    fetchBookDetails(state.result).then((enriched) => {
      if (alive) setResult(enriched);
    });
    const subj = state.result.subjects[0] || 'fiction';
    fetchBooksBySubject(subj, 12).then((list) => {
      if (alive) setSimilar(list.filter((b) => b.workKey !== state.result?.workKey).slice(0, 10));
    });
    return () => {
      alive = false;
    };
  }, [state?.result]);

  if (!result) {
    return (
      <div style={{ height: '100%', background: BookColors.black, color: BookColors.white, display: 'grid', placeItems: 'center' }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontFamily: Fonts.display, fontSize: 22 }}>Pick a book from the shelf first</div>
          <button type="button" className="bare-button" onClick={() => navigate('/books')} style={{ marginTop: 14, padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>
            Back to Books
          </button>
        </div>
      </div>
    );
  }

  const item = state?.saved ?? searchResultToBookItem(result);
  const inReadlist = readlist.find((b) => b.workKey === item.workKey);
  const isLoved = favorites.some((b) => b.workKey === item.workKey);
  const hasReadable = buildReadCandidates(item).length > 0 || Boolean(item.iaId) || result.gutenbergId > 0;
  const metaLine = [result.filetype || result.year, result.language || result.sourceLabel].filter(Boolean).join(' · ');
  const downloads = Object.entries(result.downloadUrls ?? {});
  const detailRows: [string, string][] = [
    ['Category', result.categories[0] || result.subjects.slice(0, 2).join(' · ')],
    ['Type', 'Book'],
    ['Language', result.language],
    ['File', (result.filetype || (hasReadable ? 'EPUB' : '')).toUpperCase()],
    ['Source', result.sourceLabel],
    ['Year', result.year],
    ['Gutenberg ID', result.gutenbergId > 0 ? String(result.gutenbergId) : ''],
  ].filter(([, v]) => Boolean(v)) as [string, string][];

  const copyShare = () => {
    const url = result.gutenbergId > 0
      ? `https://www.gutenberg.org/ebooks/${result.gutenbergId}`
      : result.iaId
        ? `https://archive.org/details/${result.iaId}`
        : `https://openlibrary.org${item.workKey}`;
    void navigator.clipboard?.writeText(`${url}\n${item.title}`);
  };

  return (
    <div style={{ position: 'relative', height: '100%', overflowY: 'auto', background: BookColors.black, color: BookColors.white, paddingBottom: 80 }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: BookColors.amber, alignment: [0, -0.3], size: 0.9, opacity: 0.16 },
          { color: BookColors.deepRose, alignment: [0, 0.2], size: 0.9, opacity: 0.06 },
        ]}
      />
      <div style={{ position: 'relative', padding: '14px 20px 0' }}>
        <ShelfIconButton icon="arrow_back_ios_new" label="Back" size={40} onClick={() => navigate(-1)} />

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginTop: 10 }}>
          <BookCover width={168} imageUrl={result.coverUrl} title={result.title} author={result.author} radius={10} />
          <h1 style={{ fontFamily: Fonts.display, fontSize: 28, fontWeight: 900, lineHeight: 1.1, margin: '22px 0 0' }}>{result.title}</h1>
          {result.author && (
            <button
              type="button"
              className="bare-button"
              onClick={() => navigate('/books', { state: { query: result.author } })}
              style={{ marginTop: 8, fontSize: 14, color: withAlpha(BookColors.rose, 0.9), textDecoration: 'underline', textDecorationColor: withAlpha(BookColors.rose, 0.35) }}
            >
              {result.author}
            </button>
          )}
          {metaLine && <div style={{ fontSize: 12, color: BookColors.muted, marginTop: 8 }}>{metaLine}</div>}
          {result.ratingCount ? (
            <div style={{ fontSize: 12, fontWeight: 700, color: BookColors.amber, marginTop: 8 }}>{result.ratingCount} readers</div>
          ) : null}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 22 }}>
          {hasReadable && (
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => navigate('/books/reader', { state: { book: item } })}
                style={{
                  flex: 3,
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                  padding: '13px 16px',
                  borderRadius: 14,
                  background: BookColors.white,
                  color: BookColors.black,
                  fontWeight: 700,
                  fontSize: 15,
                }}
              >
                <Icon name="auto_stories" size={19} color={BookColors.black} /> Read
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={() => navigate('/books/listen', { state: { book: item, listen: true } })}
                style={{
                  flex: 2,
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                  padding: '13px 16px',
                  borderRadius: 14,
                  background: 'rgba(255,255,255,0.03)',
                  border: `1px solid ${withAlpha(BookColors.rose, 0.25)}`,
                  color: BookColors.white,
                  fontWeight: 700,
                  fontSize: 14.5,
                }}
              >
                <Icon name="headphones" size={18} color={BookColors.white} /> Listen
              </button>
            </div>
          )}
          {downloads.length > 0 && (
            <button
              type="button"
              className="bare-button"
              onClick={() => window.open(downloads[0][1], '_blank', 'noopener')}
              style={{
                width: '100%',
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
                padding: '12px 16px',
                borderRadius: 14,
                background: hasReadable ? 'rgba(255,255,255,0.03)' : BookColors.deepRose,
                border: `1px solid ${withAlpha(BookColors.rose, hasReadable ? 0.25 : 0.6)}`,
                color: BookColors.white,
                fontWeight: 700,
                fontSize: 14,
              }}
            >
              <Icon name="download" size={18} color={BookColors.white} /> Download {downloads[0][0].toUpperCase()}
            </button>
          )}
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-evenly', alignItems: 'center', marginTop: 22 }}>
          {isCoupleUser && (
            <>
              <DetailActionCircle
                icon={inReadlist ? 'bookmark' : 'bookmark_outline'}
                label={isBookRead(inReadlist?.status ?? '') ? 'Read' : inReadlist ? 'Saved' : 'Save'}
                active={Boolean(inReadlist)}
                onClick={() => void saveToReadList(item, inReadlist?.status === 'to-read' ? 'read-self' : 'to-read', userName)}
              />
              <DetailActionCircle
                icon={isLoved ? 'favorite' : 'favorite_border'}
                label={isLoved ? 'Loved' : 'Love'}
                active={isLoved}
                onClick={() => void toggleBookFavorite(item, userName, !isLoved)}
              />
              <DetailActionCircle
                icon="volunteer_activism"
                label="Our Books"
                onClick={() => void addToOurBooks(item, userName)}
              />
            </>
          )}
          <DetailActionCircle icon="ios_share" label="Share" onClick={copyShare} />
        </div>

        {result.description && (
          <p style={{ marginTop: 22, fontSize: 14, lineHeight: 1.65, color: withAlpha(BookColors.white, 0.85) }}>
            {result.description}
          </p>
        )}

        {(detailRows.length > 0 || result.subjects.length > 0) && (
          <div
            style={{
              marginTop: 22,
              padding: '14px 16px',
              borderRadius: 16,
              background: withAlpha(BookColors.card, 0.6),
              border: `1px solid ${withAlpha(BookColors.rose, 0.1)}`,
            }}
          >
            <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.6, color: BookColors.muted, marginBottom: 10 }}>DETAILS</div>
            {detailRows.map(([k, v]) => (
              <div key={k} style={{ display: 'flex', alignItems: 'flex-start', padding: '5px 0' }}>
                <span style={{ width: 96, flexShrink: 0, fontSize: 12.5, color: BookColors.muted }}>{k}</span>
                <span style={{ flex: 1, fontSize: 12.5, fontWeight: 700, color: BookColors.white }}>{v}</span>
              </div>
            ))}
            {result.subjects.length > 0 && (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
                {result.subjects.map((s) => (
                  <span key={s} style={{ padding: '4px 10px', borderRadius: 99, background: BookColors.black, border: `1px solid ${withAlpha(BookColors.rose, 0.14)}`, fontSize: 11.5, color: BookColors.muted }}>
                    {s}
                  </span>
                ))}
              </div>
            )}
          </div>
        )}

        {similar.length > 0 && (
          <div style={{ marginTop: 28 }}>
            <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 800, color: BookColors.white, marginBottom: 14 }}>More like this</div>
            <div className="no-scrollbar" style={{ display: 'flex', gap: 14, overflowX: 'auto' }}>
              {similar.map((b) => (
                <BookCoverCard
                  key={b.workKey || b.title}
                  width={width >= 700 ? 132 : 112}
                  result={b}
                  onClick={() => navigate('/books/detail', { state: { result: b } })}
                />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function DetailActionCircle({ icon, label, active, onClick }: { icon: string; label: string; active?: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}
    >
      <div
        style={{
          width: 46,
          height: 46,
          borderRadius: '50%',
          background: active ? withAlpha(BookColors.deepRose, 0.22) : withAlpha(BookColors.card, 0.8),
          border: `1px solid ${active ? BookColors.deepRose : withAlpha(BookColors.rose, 0.2)}`,
          display: 'grid',
          placeItems: 'center',
        }}
      >
        <Icon name={icon} size={20} color={active ? BookColors.deepRose : BookColors.white} />
      </div>
      <span style={{ fontSize: 11.5, color: active ? BookColors.rose : BookColors.muted, fontWeight: 600 }}>{label}</span>
    </button>
  );
}

export function BookReaderPage({ startListening = false }: { startListening?: boolean }) {
  const navigate = useNavigate();
  const location = useLocation();
  const book = (location.state as { book?: BookItem } | null)?.book ?? null;

  const [text, setText] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [themeMode, setThemeMode] = useState<'dark' | 'sepia' | 'light'>('dark');
  const [fontSize, setFontSize] = useState(17);
  const [speaking, setSpeaking] = useState(false);

  useEffect(() => {
    if (!book) return;
    let alive = true;
    const candidates = buildReadCandidates(book);
    if (candidates.length === 0) {
      setLoading(false);
      setError(book.iaId ? null : 'No plain-text source available for this book.');
      return;
    }
    setLoading(true);
    fetchBookText(candidates).then((res) => {
      if (!alive) return;
      if (res.text) {
        setText(res.text);
        if (startListening && 'speechSynthesis' in window) {
          const u = new SpeechSynthesisUtterance(res.text.slice(0, 6000));
          u.onend = () => setSpeaking(false);
          window.speechSynthesis.speak(u);
          setSpeaking(true);
        }
      } else {
        setError(res.error ?? 'Could not load book text.');
      }
      setLoading(false);
    });
    return () => {
      alive = false;
      if ('speechSynthesis' in window) window.speechSynthesis.cancel();
    };
  }, [book, startListening]);

  if (!book) {
    return (
      <div style={{ height: '100%', background: BookColors.black, color: BookColors.white, display: 'grid', placeItems: 'center' }}>
        <button type="button" className="bare-button" onClick={() => navigate('/books')} style={{ padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>
          Back to Books
        </button>
      </div>
    );
  }

  const toggleSpeech = () => {
    if (!('speechSynthesis' in window)) return;
    if (speaking) {
      window.speechSynthesis.cancel();
      setSpeaking(false);
    } else if (text) {
      const u = new SpeechSynthesisUtterance(text.slice(0, 10000));
      u.onend = () => setSpeaking(false);
      window.speechSynthesis.speak(u);
      setSpeaking(true);
    }
  };

  const bg = themeMode === 'dark' ? '#0D0B12' : themeMode === 'sepia' ? '#F4ECD8' : '#FAFAFA';
  const fg = themeMode === 'dark' ? '#EAE4EE' : '#1E1B18';

  return (
    <div style={{ height: '100%', background: bg, color: fg, display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '10px 16px', borderBottom: `1px solid ${withAlpha(fg, 0.12)}`, display: 'flex', alignItems: 'center', gap: 10 }}>
        <button type="button" className="bare-button" onClick={() => navigate(-1)} style={{ padding: 6 }}>
          <Icon name="arrow_back" size={20} color={fg} />
        </button>
        <div style={{ flex: 1, fontFamily: Fonts.display, fontWeight: 700, fontSize: 18, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {book.title}
        </div>
        <button type="button" className="bare-button" onClick={toggleSpeech} style={{ padding: 6 }} title={speaking ? 'Pause' : 'Listen'}>
          <Icon name={speaking ? 'stop' : 'headphones'} size={20} color={speaking ? BookColors.deepRose : fg} />
        </button>
        <button type="button" className="bare-button" onClick={() => setFontSize((f) => Math.max(13, f - 2))} style={{ padding: '4px 8px', fontSize: 13 }}>A-</button>
        <button type="button" className="bare-button" onClick={() => setFontSize((f) => Math.min(26, f + 2))} style={{ padding: '4px 8px', fontSize: 13 }}>A+</button>
        <button
          type="button"
          className="bare-button"
          onClick={() => setThemeMode((t) => (t === 'dark' ? 'sepia' : t === 'sepia' ? 'light' : 'dark'))}
          style={{ padding: '4px 10px', borderRadius: 10, border: `1px solid ${withAlpha(fg, 0.2)}`, fontSize: 12 }}
        >
          {themeMode}
        </button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '24px 20px' }}>
        {loading ? (
          <div style={{ padding: 64, textAlign: 'center', fontFamily: Fonts.display, fontSize: 18 }}>Opening the pages…</div>
        ) : text ? (
          <pre style={{ maxWidth: 680, margin: '0 auto', whiteSpace: 'pre-wrap', fontFamily: Fonts.display, fontSize, lineHeight: 1.75 }}>
            {text.slice(0, 120000)}
          </pre>
        ) : book.iaId ? (
          <iframe
            src={`https://archive.org/embed/${book.iaId}`}
            title={book.title}
            allowFullScreen
            style={{ width: '100%', height: '82vh', border: 'none', borderRadius: 12 }}
          />
        ) : (
          <div style={{ padding: 48, textAlign: 'center' }}>{error || 'No readable text found.'}</div>
        )}
      </div>
    </div>
  );
}

export function BookListPage() {
  const { width } = useViewport();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { kind?: 'popular' | 'recent' | 'category'; title?: string; category?: BookCategory; initialResults?: BookSearchResult[] } | null) ?? {};

  const [results, setResults] = useState<BookSearchResult[]>(state.initialResults ?? []);
  const [loading, setLoading] = useState(!state.initialResults?.length);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    const load = async () => {
      const res = state.category
        ? await fetchBooksBySubject(state.category.query, 30)
        : state.kind === 'recent'
          ? await fetchRecentBooks(30)
          : await fetchPopularBooks(30);
      if (alive) {
        setResults(res);
        setLoading(false);
      }
    };
    void load();
    return () => {
      alive = false;
    };
  }, [state.kind, state.category]);

  const title = state.category?.name ?? state.title ?? (state.kind === 'recent' ? 'Recently Added' : 'Most Popular');
  const eyebrow =
    state.category != null
      ? 'BROWSE BY CATEGORY'
      : state.kind === 'recent'
        ? 'FRESH IN THE CATALOG'
        : 'TRENDING THIS WEEK';
  const cols = width >= 1024 ? 7 : width >= 600 ? 5 : 3;

  return (
    <div style={{ position: 'relative', height: '100%', background: BookColors.black, color: BookColors.white, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: AppColors.warmAmber, alignment: [-0.7, -0.85], size: 0.85, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.85, 0.95], size: 0.8, opacity: 0.10 },
        ]}
      />
      <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '14px 20px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <ShelfIconButton icon="arrow_back_ios_new" label="Back" tooltip="Back" onClick={() => navigate(-1)} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <h1 style={{ fontFamily: Fonts.display, fontSize: 26, fontWeight: 700, margin: 0, color: BookColors.white, lineHeight: 1.1 }}>{title}</h1>
            <div style={{ fontFamily: Fonts.body, fontWeight: 700, fontSize: 9, color: BookColors.muted, letterSpacing: 2.0, marginTop: 2 }}>
              {eyebrow}
            </div>
          </div>
          {results.length > 0 && (
            <span
              style={{
                padding: '6px 12px',
                borderRadius: 20,
                background: withAlpha(BookColors.deepRose, 0.15),
                border: `1px solid ${withAlpha(BookColors.deepRose, 0.3)}`,
                fontFamily: Fonts.body,
                color: BookColors.deepRose,
                fontWeight: 800,
                fontSize: 14,
              }}
            >
              {results.length}
            </span>
          )}
        </div>

        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 20px 40px' }}>
          {loading && results.length === 0 ? (
            <div style={{ padding: 48, textAlign: 'center', color: BookColors.muted }}>Loading…</div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: '18px 14px' }}>
              {results.map((r) => (
                <BookCoverCard
                  key={r.workKey || r.title}
                  width={Math.floor((width - 40 - (cols - 1) * 14) / cols)}
                  result={r}
                  onClick={() => navigate('/books/detail', { state: { result: r } })}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export function BookCategoriesPage() {
  const { width } = useViewport();
  const navigate = useNavigate();
  const cols = width >= 1024 ? 4 : width >= 600 ? 3 : 2;

  return (
    <div style={{ position: 'relative', height: '100%', background: BookColors.black, color: BookColors.white, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: AppColors.warmAmber, alignment: [-0.7, -0.85], size: 0.85, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.85, 0.95], size: 0.8, opacity: 0.10 },
        ]}
      />
      <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '14px 20px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <ShelfIconButton icon="arrow_back_ios_new" label="Back" tooltip="Back" onClick={() => navigate(-1)} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <h1 style={{ fontFamily: Fonts.display, fontSize: 26, fontWeight: 700, margin: 0, color: BookColors.white, lineHeight: lineHeight(26) }}>
              Categories
            </h1>
            <div style={{ fontFamily: Fonts.body, fontWeight: 700, fontSize: 9, color: BookColors.muted, letterSpacing: 2.0, marginTop: 2 }}>
              PICK A SHELF
            </div>
          </div>
        </div>
        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 20px 40px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 12 }}>
            {BOOK_CATEGORIES.map((cat) => (
              <button
                key={cat.query}
                type="button"
                className="bare-button"
                onClick={() => navigate('/books/category', { state: { category: cat } })}
                style={{
                  aspectRatio: '1.15',
                  borderRadius: 20,
                  background: withAlpha(BookColors.card, 0.6),
                  border: `1px solid ${withAlpha(cat.color, 0.25)}`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  padding: '0 8px',
                }}
              >
                <div
                  style={{
                    width: 48,
                    height: 48,
                    borderRadius: '50%',
                    background: withAlpha(cat.color, 0.15),
                    border: `1px solid ${withAlpha(cat.color, 0.4)}`,
                    display: 'grid',
                    placeItems: 'center',
                  }}
                >
                  <Icon name={cat.icon} size={22} color={cat.color} />
                </div>
                <div
                  style={{
                    marginTop: 10,
                    fontFamily: Fonts.body,
                    fontWeight: 600,
                    fontSize: 13,
                    color: BookColors.white,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    maxWidth: '100%',
                  }}
                >
                  {cat.name}
                </div>
                <div style={{ marginTop: 2, fontFamily: Fonts.body, fontSize: 10, color: BookColors.muted }}>
                  Browse
                </div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
